import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import '../domain/services/suggestion_engine.dart';
import 'widgets/ocr_validation_sheet.dart';
import 'widgets/ocr_viewfinder.dart';

/// Pantalla Principal del Escáner OCR de Comprobantes y Tickets (RF-03 / RF-05).
///
/// Implementa fielmente el diseño de Stitch Screen `06dd441359e2446c8c5931868b87b4d7`:
/// - Barra superior con retroceso y título "Escanear".
/// - Visor `OcrViewfinder` con máscara oscura, recorte de 16px, guías #79ADDC y haz láser.
/// - Captura en vivo vía cámara o galería mediante `image_picker: ^1.1.2`.
/// - Subida multipart al endpoint `POST /receipt-scans/upload` (almacenado en bucket `receipts`).
/// - Apertura automática de `OcrValidationSheet` con pre-confirmación de datos extraídos.
/// - Auto-sugerencia de categoría y cuenta de débito vía `SuggestionEngine` (CA-05.2, RN-CAT-01).
/// - Fallback automático a formulario manual en caso de falla o baja confianza (CA-03.4, CA-05.3).
class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({
    super.key,
    required this.transactionApiService,
    required this.cycleId,
    this.currentAvailableBalance = 0.0,
    this.daysRemainingInCycle = 8,
    this.initialCategories = const [],
    this.initialAccounts = const [],
    this.onFetchCategories,
    this.onFetchAccounts,
    this.onFetchHistory,
    this.onOpenManualForm,
    this.onCreateCategory,
    this.onTransactionCreated,
    this.picker,
  });

  final TransactionApiService transactionApiService;
  final String cycleId;
  final double currentAvailableBalance;
  final int daysRemainingInCycle;
  final List<Category> initialCategories;
  final List<FinancialAccount> initialAccounts;
  final Future<List<Category>> Function()? onFetchCategories;
  final Future<List<FinancialAccount>> Function()? onFetchAccounts;
  final Future<List<Transaction>> Function()? onFetchHistory;
  final VoidCallback? onOpenManualForm;
  final Future<Category?> Function()? onCreateCategory;
  final ValueChanged<Transaction>? onTransactionCreated;
  final ImagePicker? picker;

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  late final ImagePicker _picker;

  bool _isTorchOn = false;
  bool _isProcessing = false;
  String? _statusMessage;
  String? _detectedMerchant;
  double? _confidenceScore;

  List<Category> _categories = [];
  List<FinancialAccount> _accounts = [];
  List<Transaction> _history = [];

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _categories = List.from(widget.initialCategories);
    _accounts = List.from(widget.initialAccounts);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      if (widget.onFetchCategories != null) {
        final cats = await widget.onFetchCategories!();
        if (mounted) setState(() => _categories = cats);
      }
      if (widget.onFetchAccounts != null) {
        final accs = await widget.onFetchAccounts!();
        if (mounted) setState(() => _accounts = accs);
      }
      if (widget.onFetchHistory != null) {
        final hist = await widget.onFetchHistory!();
        if (mounted) setState(() => _history = hist);
      }
    } catch (_) {
      // Metadatos iniciales retienen fallback
    }
  }

  void _handleToggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  Future<void> _handleCaptureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null) {
        await _processReceiptFile(File(photo.path));
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'No se pudo acceder a la cámara. Revisa los permisos o elige una foto de galería.',
        );
      }
    }
  }

  Future<void> _handlePickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _processReceiptFile(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'No se pudo abrir la galería de imágenes.',
        );
      }
    }
  }

  /// Procesa el archivo de comprobante: valida formato/tamaño, sube a Supabase Storage y abre validación
  Future<void> _processReceiptFile(File file) async {
    // 1. Validación preventiva de tamaño y formato (RNF-01)
    final length = await file.length();
    if (length == 0) {
      if (mounted) {
        AppToast.showError(context, 'El archivo seleccionado está vacío.');
      }
      return;
    }

    if (length > 10 * 1024 * 1024) {
      if (mounted) {
        AppToast.showError(
          context,
          'El comprobante excede el tamaño máximo permitido de 10 MB.',
        );
      }
      return;
    }

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      if (mounted) {
        AppToast.showError(
          context,
          'Formato no compatible. Sube una imagen (JPG, PNG) o PDF.',
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Subiendo comprobante a Supabase Storage...';
    });

    try {
      // 2. Subida del comprobante al endpoint REST
      final ReceiptScan scan =
          await widget.transactionApiService.uploadReceiptScan(file);

      setState(() {
        _isProcessing = false;
        _detectedMerchant = scan.extractedMerchant;
        _confidenceScore = scan.confidenceScore;
        _statusMessage = '¡Comprobante extraído con éxito!';
      });

      // 3. Auto-sugerencia de Categoría y Cuenta de Débito (CA-05.2, RN-CAT-01)
      ReceiptScan enrichedScan = scan;
      if (scan.extractedMerchant != null && scan.extractedMerchant!.isNotEmpty) {
        final suggestion = SuggestionEngine.suggestCategoryAndAccount(
          merchantName: scan.extractedMerchant!,
          history: _history,
          categories: _categories,
        );

        if (suggestion['account_id'] != null && scan.suggestedAccountId == null) {
          enrichedScan = scan.copyWith(
            suggestedAccountId: suggestion['account_id'],
          );
        }
      }

      // 4. Despliegue de la Hoja Modal de Pre-Confirmación (CA-03.2, Stitch Screen 06dd441359e2446c8c5931868b87b4d7)
      if (!mounted) return;

      final bool? confirmed = await OcrValidationSheet.show<bool>(
        context: context,
        scan: enrichedScan,
        cycleId: widget.cycleId,
        categories: _categories,
        accounts: _accounts,
        currentAvailableBalance: widget.currentAvailableBalance,
        daysRemainingInCycle: widget.daysRemainingInCycle,
        onCreateCategory: widget.onCreateCategory,
        onConfirm: (dto) async {
          final tx = await widget.transactionApiService.confirmReceiptScan(
            scan.id,
            dto,
          );
          widget.onTransactionCreated?.call(tx);
          if (mounted) {
            AppToast.showSuccess(
              context,
              '¡Gasto de \$${dto.amount?.toStringAsFixed(2)} registrado y descontado!',
            );
          }
        },
        onRescan: () {
          // Permite repetir la captura sin salir de la pantalla
          setState(() {
            _detectedMerchant = null;
            _confidenceScore = null;
            _statusMessage = 'Alinee el comprobante en el recuadro';
          });
        },
        onFallbackManual: () {
          widget.onOpenManualForm?.call();
        },
      );

      if (confirmed == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error al procesar el comprobante.';
        });

        // Fallback automático al formulario manual en caso de fallo (CA-03.4, CA-05.3)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No pudimos procesar el comprobante: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: AppColors.expenseText,
            action: SnackBarAction(
              label: 'Manual',
              textColor: Colors.white,
              onPressed: () {
                widget.onOpenManualForm?.call();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141C23),
      appBar: AppAppBar(
        title: 'Escanear',
        subtitle: 'Captura inteligente de gastos',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: OcrViewfinder(
          isTorchOn: _isTorchOn,
          isProcessing: _isProcessing,
          statusMessage: _statusMessage,
          detectedMerchant: _detectedMerchant,
          confidenceScore: _confidenceScore,
          onToggleTorch: _handleToggleTorch,
          onManualTap: () {
            widget.onOpenManualForm?.call();
          },
          onCapture: _handleCaptureFromCamera,
          onPickGallery: _handlePickFromGallery,
        ),
      ),
    );
  }
}
