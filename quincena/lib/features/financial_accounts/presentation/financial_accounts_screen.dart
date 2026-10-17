import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../data/financial_accounts_api_service.dart';
import '../models/financial_account.dart';
import 'widgets/account_card.dart';
import 'widgets/account_form_sheet.dart';

/// Pantalla principal para la Administración de Cuentas Financieras (RF-01 / DERCAS 1.2)
class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({
    super.key,
    required this.accountsService,
    this.onBack,
  });

  final FinancialAccountsApiService accountsService;
  final VoidCallback? onBack;

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<FinancialAccount> _allAccounts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAccounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accounts = await widget.accountsService.getAccounts();
      if (mounted) {
        setState(() {
          _allAccounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<FinancialAccount> get _activeAccounts =>
      _allAccounts.where((a) => !a.isArchived).toList();

  List<FinancialAccount> get _archivedAccounts =>
      _allAccounts.where((a) => a.isArchived).toList();

  double get _totalBalance =>
      _activeAccounts.fold(0.0, (sum, acc) => sum + acc.currentBalance);

  String get _primaryCurrency =>
      _activeAccounts.isNotEmpty ? _activeAccounts.first.currency : 'GTQ';

  FinancialAccount? get _defaultAccount =>
      _activeAccounts.where((a) => a.isDefault).firstOrNull;

  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountFormSheet(
        onSave: ({
          required name,
          required accountType,
          required currency,
          required colorHex,
          required icon,
          required isDefault,
          required initialBalance,
        }) async {
          await widget.accountsService.createAccount(
            name: name,
            accountType: accountType,
            currency: currency,
            colorHex: colorHex,
            icon: icon,
            isDefault: isDefault,
            initialBalance: initialBalance,
          );
          _loadAccounts();
        },
      ),
    );
  }

  void _openEditSheet(FinancialAccount account) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountFormSheet(
        accountToEdit: account,
        onSave: ({
          required name,
          required accountType,
          required currency,
          required colorHex,
          required icon,
          required isDefault,
          required initialBalance,
        }) async {
          await widget.accountsService.updateAccount(
            account.id,
            name: name,
            accountType: accountType,
            currency: currency,
            colorHex: colorHex,
            icon: icon,
            isDefault: isDefault,
          );
          _loadAccounts();
        },
      ),
    );
  }

  Future<void> _handleSetDefault(FinancialAccount account) async {
    try {
      await widget.accountsService.setDefaultAccount(account.id);
      _loadAccounts();
      if (mounted) {
        AppToast.showSuccess(
          context,
          '${account.name} es ahora tu cuenta predeterminada',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e);
      }
    }
  }

  Future<void> _handleArchive(FinancialAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderCard,
        ),
        title: Text('¿Archivar cuenta?', style: AppTypography.headlineSm),
        content: Text(
          'La cuenta "${account.name}" se ocultará de los selectores activos de presupuestos y registros.\n\n'
          'Tus transacciones y balances históricos asociados se conservarán intactos (CA-01.3).',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          SizedBox(
            width: 120,
            child: AppButton(
              text: 'Archivar',
              variant: AppButtonVariant.primary,
              height: 42,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.accountsService.archiveAccount(account.id);
        _loadAccounts();
        if (mounted) {
          AppToast.showInfo(context, 'Cuenta "${account.name}" archivada');
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, e);
        }
      }
    }
  }

  Future<void> _handleUnarchive(FinancialAccount account) async {
    try {
      await widget.accountsService.updateAccount(account.id, isArchived: false);
      _loadAccounts();
      if (mounted) {
        AppToast.showSuccess(context, 'Cuenta "${account.name}" reactivada');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppAppBar(
        title: 'Cuentas Financieras',
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textMain, size: 20),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMain),
            onPressed: _loadAccounts,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccessible),
            )
          : RefreshIndicator(
              color: AppColors.primaryAccessible,
              onRefresh: _loadAccounts,
              child: ListView(
                padding: AppSpacing.paddingScreen,
                children: [
                  const SizedBox(height: AppSpacing.spaceSm),
                  // 1. Tarjeta Hero de Balance Total Consolidado en Warm Cream (#FCF5C7)
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingHeroCard,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHero,
                      borderRadius: AppRadius.borderHero,
                      border: Border.all(
                        color: const Color(0x141C242B),
                        width: 1,
                      ),
                      boxShadow: AppShadows.hero,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BALANCE CONSOLIDADO EN CUENTAS',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_primaryCurrency ${_totalBalance.toStringAsFixed(2)}',
                          style: AppTypography.currencyHeroMobile,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0x1F1C242B)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_activeAccounts.length} cuenta${_activeAccounts.length == 1 ? '' : 's'} activa${_activeAccounts.length == 1 ? '' : 's'}',
                              style: AppTypography.captionBadge.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_defaultAccount != null)
                              Text(
                                'Principal: ${_defaultAccount!.name}',
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.primaryAccessible,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceLg),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      decoration: BoxDecoration(
                        color: AppColors.expenseBg.withValues(alpha: 0.3),
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.expenseBg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.expenseText),
                          const SizedBox(width: AppSpacing.spaceSm),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: AppColors.expenseText, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadAccounts,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),
                  ],

                  // 2. Selector de Tabs: Activas y Archivadas
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryAccessible,
                      labelColor: AppColors.textMain,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTypography.captionBadge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
                        Tab(text: 'Activas (${_activeAccounts.length})'),
                        Tab(text: 'Archivadas (${_archivedAccounts.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),

                  // 3. Contenido según tab seleccionado
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final isArchivedTab = _tabController.index == 1;
                      final currentList =
                          isArchivedTab ? _archivedAccounts : _activeAccounts;

                      if (currentList.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 36,
                            horizontal: AppSpacing.spaceLg,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: AppRadius.borderCard,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                isArchivedTab
                                    ? Icons.archive_outlined
                                    : Icons.account_balance_wallet_outlined,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: AppSpacing.spaceSm),
                              Text(
                                isArchivedTab
                                    ? 'No tienes cuentas archivadas'
                                    : 'No tienes cuentas activas registradas',
                                style: AppTypography.headlineSm,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.spaceXs),
                              Text(
                                isArchivedTab
                                    ? 'Cuando archives una cuenta sin uso, aparecerá aquí.'
                                    : 'Agrega tus cuentas de banco, tarjetas o efectivo para vincularlas a tus quincenas.',
                                style: AppTypography.bodyMd,
                                textAlign: TextAlign.center,
                              ),
                              if (!isArchivedTab) ...[
                                const SizedBox(height: AppSpacing.spaceMd),
                                AppButton(
                                  text: 'Agregar Cuenta',
                                  prefixIcon: const Icon(Icons.add, size: 18),
                                  onPressed: _openCreateSheet,
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: currentList
                            .map((acc) => AccountCard(
                                  key: ValueKey(acc.id),
                                  account: acc,
                                  onEdit: () => _openEditSheet(acc),
                                  onSetDefault: () => _handleSetDefault(acc),
                                  onArchive: () => _handleArchive(acc),
                                  onUnarchive: isArchivedTab
                                      ? () => _handleUnarchive(acc)
                                      : null,
                                ))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 80), // Margen para el FAB
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textMain,
        foregroundColor: AppColors.surfaceBase,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Cuenta',
            style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: _openCreateSheet,
      ),
    );
  }
}
