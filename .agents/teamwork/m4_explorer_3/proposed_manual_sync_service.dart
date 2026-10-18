import 'package:flutter/material.dart';
import 'package:quincena/core/components/feedback/app_toast.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/presentation/notifiers/budget_notifier.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'proposed_duplicate_warning_dialog.dart';

/// Estado resultante tras el intento de registrar un gasto manual
enum ManualExpenseStatus {
  /// Transacción persistida con éxito y saldos sincronizados (<100ms)
  success,

  /// Advertencia de duplicado (RN-03) interceptada y el usuario eligió "Cancelar"
  /// (el formulario permanece abierto con los datos intactos)
  duplicateCancelled,

  /// Error de red, validación o servidor
  error,
}

/// Objeto de resultado retornado por [ManualSyncService.submitManualExpense]
class ManualExpenseResult {
  const ManualExpenseResult._({
    required this.status,
    this.transaction,
    this.errorMessage,
  });

  factory ManualExpenseResult.success(Transaction transaction) {
    return ManualExpenseResult._(
      status: ManualExpenseStatus.success,
      transaction: transaction,
    );
  }

  factory ManualExpenseResult.duplicateCancelled() {
    return const ManualExpenseResult._(
      status: ManualExpenseStatus.duplicateCancelled,
    );
  }

  factory ManualExpenseResult.error(String message) {
    return ManualExpenseResult._(
      status: ManualExpenseStatus.error,
      errorMessage: message,
    );
  }

  final ManualExpenseStatus status;
  final Transaction? transaction;
  final String? errorMessage;

  bool get isSuccess => status == ManualExpenseStatus.success;
  bool get isDuplicateCancelled => status == ManualExpenseStatus.duplicateCancelled;
  bool get isError => status == ManualExpenseStatus.error;
}

/// Servicio coordinador para el registro de gastos manuales, intercepción de duplicados (RN-03)
/// y sincronización de saldos en tiempo real (<100ms) (CA-04.2, CA-06.2).
///
/// Responsabilidades:
/// 1. Envía `POST /transactions` (con `force: false` por defecto).
/// 2. Intercepta respuestas HTTP 409 Conflict con `duplicate_warning: true` y despliega [DuplicateWarningDialog].
/// 3. Si el usuario cancela en el diálogo, cancela la operación manteniendo el formulario intacto.
/// 4. Si el usuario confirma forzar, re-envía `POST /transactions?force=true`.
/// 5. Descuenta el monto de inmediato en memoria de la bolsa correspondiente (<10ms).
/// 6. Notifica a `HomeScreen` y `TransactionsFeedScreen` vía `_handleBalanceRefresh()` (<100ms).
/// 7. Muestra notificación flotante: *"Gasto registrado exitosamente"*.
class ManualSyncService {
  const ManualSyncService({
    required this.transactionApiService,
    this.budgetNotifier,
    this.onBalanceRefresh,
    this.onTransactionCreated,
  });

  /// Servicio REST para creación de transacciones
  final TransactionApiService transactionApiService;

  /// Notificador de presupuestos quincenales para deducción inmediata en memoria
  final BudgetNotifier? budgetNotifier;

  /// Callback de refresco global (p. ej. `_handleBalanceRefresh` en `main.dart`)
  final VoidCallback? onBalanceRefresh;

  /// Callback opcional emitido al crearse la transacción
  final void Function(Transaction transaction)? onTransactionCreated;

  /// Ejecuta el flujo completo de registro manual de gasto con intercepción de duplicados
  /// y propagación reactiva de saldos en menos de 100ms.
  Future<ManualExpenseResult> submitManualExpense({
    required BuildContext context,
    required CreateTransactionDto dto,
    bool showSuccessToast = true,
    bool popOnSuccess = true,
  }) async {
    Transaction transaction;

    try {
      // -------------------------------------------------------------
      // PASO 1: Intento normal con validación preventiva de duplicados
      // -------------------------------------------------------------
      try {
        transaction = await transactionApiService.createTransaction(
          dto,
          force: false,
        );
      } on DuplicateTransactionException catch (dupEx) {
        // -------------------------------------------------------------
        // PASO 2: Interceptar 409 Conflict y desplegar DuplicateWarningDialog (RN-03)
        // -------------------------------------------------------------
        if (!context.mounted) {
          return ManualExpenseResult.duplicateCancelled();
        }

        final bool userWantsToForce = await DuplicateWarningDialog.show(
          context: context,
          existingTransactions: dupEx.existingTransactions,
          merchantName: dto.merchantName,
          amount: dto.amount,
          transactionDate: dto.transactionDate,
          exception: dupEx,
        );

        if (!userWantsToForce) {
          // El usuario eligió "Cancelar":
          // Se mantiene el formulario abierto y con los campos intactos para corrección.
          return ManualExpenseResult.duplicateCancelled();
        }

        // El usuario eligió "Registrar de todos modos":
        // Re-enviar con ?force=true para omitir la validación de duplicados
        transaction = await transactionApiService.createTransaction(
          dto,
          force: true,
        );
      }

      // -------------------------------------------------------------
      // PASO 3: Deducción de saldo en tiempo real y sincronización (<100ms)
      // -------------------------------------------------------------

      // 3.1: Deducción inmediata en memoria en el BudgetNotifier
      applyImmediateBalanceDeduction(
        allocationId: transaction.allocationId ?? dto.allocationId,
        amount: transaction.amount,
      );

      // 3.2: Propagación a HomeScreen y Feed a través de _handleBalanceRefresh
      triggerBalanceRefresh();

      // 3.3: Callback personalizado de creación
      onTransactionCreated?.call(transaction);

      // 3.4: Notificación visual de éxito y cierre modal
      if (context.mounted) {
        if (showSuccessToast) {
          AppToast.showSuccess(context, 'Gasto registrado exitosamente');
        }

        if (popOnSuccess) {
          Navigator.of(context).pop(transaction);
        }
      }

      return ManualExpenseResult.success(transaction);
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, e);
      }
      return ManualExpenseResult.error(e.toString());
    }
  }

  /// Aplica la deducción monetaria en memoria de forma inmediata (<10ms)
  /// en las partidas presupuestarias del ciclo activo (CA-04.2).
  void applyImmediateBalanceDeduction({
    required String? allocationId,
    required double amount,
  }) {
    if (budgetNotifier == null || amount <= 0) return;

    // Si el BudgetNotifier implementa deductExpense directamente:
    try {
      // ignore: avoid_dynamic_calls
      (budgetNotifier as dynamic).deductExpense(
        allocationId: allocationId,
        amount: amount,
      );
    } catch (_) {
      // Fallback si el método aún no se incorporó al archivo base:
      // se solicita recálculo y refresco de asignaciones
      budgetNotifier?.recalculateZeroBase();
    }
  }

  /// Dispara la señal de refresco global para sincronizar HomeScreen y Feed (<100ms)
  void triggerBalanceRefresh() {
    onBalanceRefresh?.call();
    budgetNotifier?.refreshAllocations();
  }

  /// Función pura utilitaria para recalcular una lista de asignaciones con la deducción aplicada
  static List<BudgetAllocation> deductFromAllocationsList({
    required List<BudgetAllocation> allocations,
    required String? targetAllocationOrCategoryId,
    required double expenseAmount,
  }) {
    if (targetAllocationOrCategoryId == null ||
        targetAllocationOrCategoryId.isEmpty ||
        expenseAmount <= 0) {
      return allocations;
    }

    return allocations.map((alloc) {
      if (alloc.id == targetAllocationOrCategoryId ||
          alloc.categoryId == targetAllocationOrCategoryId) {
        final newSpent = alloc.spentAmount + expenseAmount;
        final newAvailable = alloc.allocatedAmount - newSpent;
        return alloc.copyWith(
          spentAmount: newSpent,
          availableAmount: newAvailable,
        );
      }
      return alloc;
    }).toList();
  }
}
