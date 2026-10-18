import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

/// Transaction Types supported by Quincena REST API
enum TransactionType {
  expense('expense', 'Gasto'),
  incomeAdjustment('income_adjustment', 'Ajuste de Ingreso'),
  transfer('transfer', 'Transferencia');

  const TransactionType(this.value, this.label);
  final String value;
  final String label;

  static TransactionType fromValue(String? val) {
    return TransactionType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Entry Methods for Transactions
enum EntryMethod {
  manual('manual', 'Manual'),
  ocr('ocr', 'OCR Escaneado');

  const EntryMethod(this.value, this.label);
  final String value;
  final String label;

  static EntryMethod fromValue(String? val) {
    return EntryMethod.values.firstWhere(
      (e) => e.value == val,
      orElse: () => EntryMethod.manual,
    );
  }
}

/// Status of OCR Processing
enum OcrStatus {
  pending('pending', 'Pendiente'),
  processing('processing', 'Procesando'),
  completed('completed', 'Completado'),
  verified('verified', 'Verificado'),
  failed('failed', 'Fallido');

  const OcrStatus(this.value, this.label);
  final String value;
  final String label;

  static OcrStatus fromValue(String? val) {
    return OcrStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => OcrStatus.pending,
    );
  }
}

/// Transaction Model representing an expense or income entry
class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.cycleId,
    this.allocationId,
    this.receiptScanId,
    required this.sourceAccountId,
    required this.amount,
    required this.merchantName,
    required this.transactionDate,
    this.transactionType = TransactionType.expense,
    this.entryMethod = EntryMethod.manual,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.sourceAccount,
  });

  final String id;
  final String userId;
  final String cycleId;
  final String? allocationId;
  final String? receiptScanId;
  final String sourceAccountId;
  final double amount;
  final String merchantName;
  final DateTime transactionDate;
  final TransactionType transactionType;
  final EntryMethod entryMethod;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Category? category;
  final FinancialAccount? sourceAccount;

  bool get isOcr => entryMethod == EntryMethod.ocr;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    Category? cat;
    if (json['budget_allocations'] is Map<String, dynamic>) {
      final alloc = json['budget_allocations'] as Map<String, dynamic>;
      if (alloc['categories'] is Map<String, dynamic>) {
        cat = Category.fromJson(alloc['categories'] as Map<String, dynamic>);
      }
    } else if (json['category'] is Map<String, dynamic>) {
      cat = Category.fromJson(json['category'] as Map<String, dynamic>);
    }

    FinancialAccount? acc;
    if (json['source_account'] is Map<String, dynamic>) {
      acc = FinancialAccount.fromJson(
        json['source_account'] as Map<String, dynamic>,
      );
    }

    final dateStr = json['transaction_date'] as String? ?? '';
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    return Transaction(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      cycleId: json['cycle_id'] as String? ?? '',
      allocationId: json['allocation_id'] as String?,
      receiptScanId: json['receipt_scan_id'] as String?,
      sourceAccountId: json['source_account_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: json['merchant_name'] as String? ?? '',
      transactionDate: parsedDate,
      transactionType: TransactionType.fromValue(json['transaction_type'] as String?),
      entryMethod: EntryMethod.fromValue(json['entry_method'] as String?),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      category: cat,
      sourceAccount: acc,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'cycle_id': cycleId,
      if (allocationId != null) 'allocation_id': allocationId,
      if (receiptScanId != null) 'receipt_scan_id': receiptScanId,
      'source_account_id': sourceAccountId,
      'amount': amount,
      'merchant_name': merchantName,
      'transaction_date': transactionDate.toIso8601String().split('T')[0],
      'transaction_type': transactionType.value,
      'entry_method': entryMethod.value,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    String? cycleId,
    String? allocationId,
    String? receiptScanId,
    String? sourceAccountId,
    double? amount,
    String? merchantName,
    DateTime? transactionDate,
    TransactionType? transactionType,
    EntryMethod? entryMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Category? category,
    FinancialAccount? sourceAccount,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cycleId: cycleId ?? this.cycleId,
      allocationId: allocationId ?? this.allocationId,
      receiptScanId: receiptScanId ?? this.receiptScanId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      entryMethod: entryMethod ?? this.entryMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      sourceAccount: sourceAccount ?? this.sourceAccount,
    );
  }
}

/// Receipt Scan record representing uploaded ticket and extracted metadata
class ReceiptScan {
  const ReceiptScan({
    required this.id,
    required this.userId,
    required this.storagePath,
    this.ocrStatus = OcrStatus.pending,
    this.extractedMerchant,
    this.extractedAmount,
    this.extractedDate,
    this.taxIdOrAuthNumber,
    this.confidenceScore = 1.0,
    this.suggestedCategoryId,
    this.suggestedAccountId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String storagePath;
  final OcrStatus ocrStatus;
  final String? extractedMerchant;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? taxIdOrAuthNumber;
  final double confidenceScore;
  final String? suggestedCategoryId;
  final String? suggestedAccountId;
  final DateTime? createdAt;

  bool get isLowConfidence => confidenceScore < 0.70;
  bool get isFailed => ocrStatus == OcrStatus.failed;
  bool get isVerified => ocrStatus == OcrStatus.verified;

  factory ReceiptScan.fromJson(Map<String, dynamic> json) {
    return ReceiptScan(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      ocrStatus: OcrStatus.fromValue(json['ocr_status'] as String?),
      extractedMerchant: json['extracted_merchant'] as String?,
      extractedAmount: (json['extracted_amount'] as num?)?.toDouble(),
      extractedDate: json['extracted_date'] != null
          ? DateTime.tryParse(json['extracted_date'] as String)
          : null,
      taxIdOrAuthNumber: json['tax_id_or_auth_number'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      suggestedCategoryId: json['suggested_category_id'] as String?,
      suggestedAccountId: json['suggested_account_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'storage_path': storagePath,
      'ocr_status': ocrStatus.value,
      if (extractedMerchant != null) 'extracted_merchant': extractedMerchant,
      if (extractedAmount != null) 'extracted_amount': extractedAmount,
      if (extractedDate != null)
        'extracted_date': extractedDate!.toIso8601String().split('T')[0],
      if (taxIdOrAuthNumber != null) 'tax_id_or_auth_number': taxIdOrAuthNumber,
      'confidence_score': confidenceScore,
      if (suggestedCategoryId != null)
        'suggested_category_id': suggestedCategoryId,
      if (suggestedAccountId != null)
        'suggested_account_id': suggestedAccountId,
    };
  }

  ReceiptScan copyWith({
    String? id,
    String? userId,
    String? storagePath,
    OcrStatus? ocrStatus,
    String? extractedMerchant,
    double? extractedAmount,
    DateTime? extractedDate,
    String? taxIdOrAuthNumber,
    double? confidenceScore,
    String? suggestedCategoryId,
    String? suggestedAccountId,
    DateTime? createdAt,
  }) {
    return ReceiptScan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      extractedMerchant: extractedMerchant ?? this.extractedMerchant,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      extractedDate: extractedDate ?? this.extractedDate,
      taxIdOrAuthNumber: taxIdOrAuthNumber ?? this.taxIdOrAuthNumber,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedAccountId: suggestedAccountId ?? this.suggestedAccountId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// DTO for creating a transaction
class CreateTransactionDto {
  const CreateTransactionDto({
    required this.cycleId,
    required this.sourceAccountId,
    required this.amount,
    required this.merchantName,
    required this.transactionDate,
    this.allocationId,
    this.receiptScanId,
    this.transactionType = TransactionType.expense,
    this.entryMethod = EntryMethod.manual,
    this.notes,
  });

  final String cycleId;
  final String sourceAccountId;
  final double amount;
  final String merchantName;
  final String transactionDate;
  final String? allocationId;
  final String? receiptScanId;
  final TransactionType transactionType;
  final EntryMethod entryMethod;
  final String? notes;

  String? validate() {
    if (cycleId.trim().isEmpty) return 'cycle_id es obligatorio';
    if (sourceAccountId.trim().isEmpty) return 'source_account_id es obligatorio';
    if (merchantName.trim().isEmpty) return 'El comercio o nota es obligatorio';
    if (merchantName.trim().length > 120) return 'El comercio no puede exceder 120 caracteres';
    if (amount <= 0.0) return 'El monto debe ser mayor a 0.00';
    if (DateTime.tryParse(transactionDate) == null) return 'Fecha de transacción inválida';
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'cycle_id': cycleId,
      'source_account_id': sourceAccountId,
      'amount': amount,
      'merchant_name': merchantName.trim(),
      'transaction_date': transactionDate,
      if (allocationId != null) 'allocation_id': allocationId,
      if (receiptScanId != null) 'receipt_scan_id': receiptScanId,
      'transaction_type': transactionType.value,
      'entry_method': entryMethod.value,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

/// DTO for confirming an OCR scan
class ConfirmReceiptScanDto {
  const ConfirmReceiptScanDto({
    required this.cycleId,
    required this.sourceAccountId,
    required this.amount,
    required this.merchantName,
    required this.transactionDate,
    this.allocationId,
    this.notes,
  });

  final String cycleId;
  final String sourceAccountId;
  final double amount;
  final String merchantName;
  final String transactionDate;
  final String? allocationId;
  final String? notes;

  String? validate() {
    if (cycleId.trim().isEmpty) return 'cycle_id es requerido para confirmar';
    if (sourceAccountId.trim().isEmpty) return 'source_account_id es requerido para confirmar';
    if (merchantName.trim().isEmpty) return 'merchant_name es requerido para confirmar';
    if (amount <= 0.0) return 'El monto debe ser mayor a 0.00';
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'cycle_id': cycleId,
      'source_account_id': sourceAccountId,
      'amount': amount,
      'merchant_name': merchantName.trim(),
      'transaction_date': transactionDate,
      if (allocationId != null) 'allocation_id': allocationId,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }
}

/// Grouped Date Section for feed presentation
class GroupedDateSection {
  const GroupedDateSection({
    required this.date,
    required this.headerTitle,
    required this.dayTotal,
    required this.transactions,
  });

  final DateTime date;
  final String headerTitle;
  final double dayTotal;
  final List<Transaction> transactions;

  static List<GroupedDateSection> groupTransactions(
    List<Transaction> list, {
    DateTime? referenceDate,
  }) {
    if (list.isEmpty) return [];

    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Sort descending by transactionDate then createdAt
    final sorted = List<Transaction>.from(list)..sort((a, b) {
      final comp = b.transactionDate.compareTo(a.transactionDate);
      if (comp != 0) return comp;
      return (b.createdAt ?? b.transactionDate).compareTo(a.createdAt ?? a.transactionDate);
    });

    final Map<String, List<Transaction>> map = {};
    for (final tx in sorted) {
      final d = tx.transactionDate;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(tx);
    }

    final List<GroupedDateSection> sections = [];
    final monthNames = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    for (final entry in map.entries) {
      final txList = entry.value;
      final d = txList.first.transactionDate;
      final dateOnly = DateTime(d.year, d.month, d.day);

      String title;
      if (dateOnly.isAtSameMomentAs(today)) {
        title = 'Hoy - ${d.day} ${monthNames[d.month]}';
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        title = 'Ayer - ${d.day} ${monthNames[d.month]}';
      } else {
        title = '${d.day} ${monthNames[d.month]} ${d.year}';
      }

      final total = txList.fold<double>(0.0, (sum, t) => sum + t.amount);
      sections.add(GroupedDateSection(
        date: dateOnly,
        headerTitle: title,
        dayTotal: total,
        transactions: txList,
      ));
    }

    return sections;
  }
}

/// Filter criteria for Transactions Feed
class FeedFilter {
  const FeedFilter({
    this.searchQuery,
    this.selectedCategoryId,
    this.selectedAccountId,
    this.ocrOnly = false,
  });

  final String? searchQuery;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final bool ocrOnly;

  FeedFilter copyWith({
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedAccountId,
    bool? ocrOnly,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearAccount = false,
  }) {
    return FeedFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedAccountId:
          clearAccount ? null : (selectedAccountId ?? this.selectedAccountId),
      ocrOnly: ocrOnly ?? this.ocrOnly,
    );
  }

  static List<Transaction> apply(List<Transaction> list, FeedFilter filter) {
    return list.where((tx) {
      // OCR only filter
      if (filter.ocrOnly && tx.entryMethod != EntryMethod.ocr) {
        return false;
      }

      // Category filter
      if (filter.selectedCategoryId != null &&
          filter.selectedCategoryId!.isNotEmpty &&
          filter.selectedCategoryId != 'all') {
        if (tx.category?.id != filter.selectedCategoryId &&
            tx.allocationId != filter.selectedCategoryId) {
          return false;
        }
      }

      // Account filter
      if (filter.selectedAccountId != null &&
          filter.selectedAccountId!.isNotEmpty &&
          filter.selectedAccountId != 'all') {
        if (tx.sourceAccountId != filter.selectedAccountId) {
          return false;
        }
      }

      // Search query filter (merchant, notes)
      if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
        final q = filter.searchQuery!.trim().toLowerCase();
        final merchantMatch = tx.merchantName.toLowerCase().contains(q);
        final notesMatch = tx.notes?.toLowerCase().contains(q) ?? false;
        if (!merchantMatch && !notesMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

/// Duplicate Detector enforcing RN-03 (same merchant, same amount, date ±24h)
class DuplicateDetector {
  static List<Transaction> findDuplicates({
    required List<Transaction> existing,
    required String merchantName,
    required double amount,
    required DateTime transactionDate,
    String? currentTransactionId,
  }) {
    final cleanMerchant = merchantName.trim().toLowerCase();
    final lowerBound = transactionDate.subtract(const Duration(hours: 24));
    final upperBound = transactionDate.add(const Duration(hours: 24));

    return existing.where((tx) {
      if (currentTransactionId != null && tx.id == currentTransactionId) {
        return false;
      }
      final sameMerchant = tx.merchantName.trim().toLowerCase() == cleanMerchant;
      final sameAmount = (tx.amount - amount).abs() < 0.001;
      final inWindow = !tx.transactionDate.isBefore(lowerBound) &&
          !tx.transactionDate.isAfter(upperBound);
      return sameMerchant && sameAmount && inWindow;
    }).toList();
  }
}

/// Category & Account Auto-Suggestion engine (CA-05.2, RN-CAT-01)
class SuggestionEngine {
  static Map<String, String?> suggestCategoryAndAccount({
    required String merchantName,
    required List<Transaction> history,
    required List<Category> categories,
  }) {
    final clean = merchantName.trim().toLowerCase();

    // 1. Check history for exact merchant match
    final pastMatch = history.firstWhere(
      (tx) => tx.merchantName.trim().toLowerCase() == clean && tx.category != null,
      orElse: () => Transaction(
        id: '',
        userId: '',
        cycleId: '',
        sourceAccountId: '',
        amount: 0,
        merchantName: '',
        transactionDate: DateTime.now(),
      ),
    );

    if (pastMatch.id.isNotEmpty && pastMatch.category != null) {
      return {
        'category_id': pastMatch.category!.id,
        'account_id': pastMatch.sourceAccountId,
      };
    }

    // 2. Keyword heuristic mapping
    String? matchedCatId;
    if (clean.contains('super') || clean.contains('walmart') || clean.contains('paiz') || clean.contains('despensa')) {
      matchedCatId = categories.where((c) => c.name.toLowerCase().contains('super')).firstOrNull?.id;
    } else if (clean.contains('cafe') || clean.contains('café') || clean.contains('starbucks') || clean.contains('restaurante')) {
      matchedCatId = categories.where((c) => c.name.toLowerCase().contains('ocio') || c.name.toLowerCase().contains('comida')).firstOrNull?.id;
    } else if (clean.contains('gas') || clean.contains('uber') || clean.contains('gasolinera')) {
      matchedCatId = categories.where((c) => c.name.toLowerCase().contains('transporte')).firstOrNull?.id;
    }

    // Default account inheritance (RN-CAT-01)
    String? defaultAccountId;
    if (matchedCatId != null) {
      final cat = categories.where((c) => c.id == matchedCatId).firstOrNull;
      defaultAccountId = cat?.defaultAccountId;
    }

    return {
      'category_id': matchedCatId,
      'account_id': defaultAccountId,
    };
  }
}

/// In-memory HTTP Client simulating quincena-api endpoints and database invariants
class MockStatefulTransactionsHttpClient extends http.BaseClient {
  MockStatefulTransactionsHttpClient({
    required this.cycleId,
    this.isCycleClosed = false,
    List<Map<String, dynamic>>? initialTransactions,
    List<Map<String, dynamic>>? initialScans,
    List<Map<String, dynamic>>? initialAllocations,
  }) {
    transactionsDb = List.from(initialTransactions ?? []);
    scansDb = List.from(initialScans ?? []);
    allocationsDb = List.from(initialAllocations ?? []);
  }

  final String cycleId;
  bool isCycleClosed;
  late List<Map<String, dynamic>> transactionsDb;
  late List<Map<String, dynamic>> scansDb;
  late List<Map<String, dynamic>> allocationsDb;

  int duplicateWarningHits = 0;
  int forceBypassHits = 0;
  int bucketUploadHits = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method;
    final path = request.url.path;
    final query = request.url.queryParameters;

    String responseBody = '{}';
    int statusCode = 200;

    String requestBodyString = '';
    if (request is http.Request) {
      requestBodyString = request.body;
    }

    // --- OCR Upload (/receipt-scans/upload) ---
    if (path.contains('/receipt-scans/upload') && method == 'POST') {
      bucketUploadHits++;
      // Verify storage bucket 'receipts' invariant
      final scanId = 'scan-${DateTime.now().microsecondsSinceEpoch}';
      final storagePath = 'user-test/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newScan = {
        'id': scanId,
        'user_id': 'user-test',
        'storage_path': storagePath,
        'ocr_status': 'pending',
        'extracted_merchant': 'Supermercado La Torre',
        'extracted_amount': 185.50,
        'extracted_date': '2026-10-18',
        'tax_id_or_auth_number': 'AUTH-99881',
        'confidence_score': 0.95,
      };
      scansDb.add(newScan);
      responseBody = jsonEncode({
        'scan': newScan,
        'message': 'Comprobante subido exitosamente al bucket receipts.',
      });
      statusCode = 201;
    }
    // --- OCR Confirm (/receipt-scans/:id/confirm) ---
    else if (path.contains('/receipt-scans/') && path.endsWith('/confirm') && method == 'POST') {
      final scanId = path.split('/')[2];
      final body = jsonDecode(requestBodyString) as Map<String, dynamic>;

      final scan = scansDb.firstWhere(
        (s) => s['id'] == scanId,
        orElse: () => <String, dynamic>{},
      );

      if (scan.isEmpty) {
        statusCode = 404;
        responseBody = jsonEncode({'message': 'Comprobante no encontrado'});
      } else if (scan['ocr_status'] == 'failed') {
        statusCode = 400;
        responseBody = jsonEncode({'message': 'El comprobante OCR falló. Ingrese datos manualmente.'});
      } else {
        final merchant = body['merchant_name'] ?? scan['extracted_merchant'];
        final amount = (body['amount'] as num?)?.toDouble() ?? (scan['extracted_amount'] as num?)?.toDouble();
        final cycle = body['cycle_id'] as String?;
        final accountId = body['source_account_id'] as String?;

        if (merchant == null || amount == null || cycle == null || accountId == null) {
          statusCode = 400;
          responseBody = jsonEncode({'message': 'Campos requeridos faltantes para confirmar'});
        } else {
          final txId = 'tx-from-scan-${DateTime.now().microsecondsSinceEpoch}';
          final newTx = {
            'id': txId,
            'user_id': 'user-test',
            'cycle_id': cycle,
            'allocation_id': body['allocation_id'],
            'receipt_scan_id': scanId,
            'source_account_id': accountId,
            'amount': amount,
            'merchant_name': merchant,
            'transaction_date': body['transaction_date'] ?? '2026-10-18',
            'transaction_type': 'expense',
            'entry_method': 'ocr',
            'notes': body['notes'],
            'created_at': DateTime.now().toIso8601String(),
          };
          transactionsDb.add(newTx);
          scan['ocr_status'] = 'verified';

          // Update allocation spent amount
          _deductAllocation(body['allocation_id'] as String?, amount);

          responseBody = jsonEncode({
            'transaction': newTx,
            'scan_id': scanId,
            'message': 'Gasto registrado exitosamente desde comprobante OCR.',
          });
          statusCode = 201;
        }
      }
    }
    // --- Transactions List (/transactions?cycleId=) ---
    else if (path.endsWith('/transactions') && method == 'GET') {
      final reqCycle = query['cycleId'] ?? cycleId;
      final filtered = transactionsDb.where((t) => t['cycle_id'] == reqCycle).toList();
      responseBody = jsonEncode(filtered);
    }
    // --- Create Transaction (/transactions?force=) ---
    else if (path.endsWith('/transactions') && method == 'POST') {
      final force = query['force'] == 'true';
      final body = jsonDecode(requestBodyString) as Map<String, dynamic>;

      // RN-01: Check closed cycle
      if (isCycleClosed) {
        statusCode = 400;
        responseBody = jsonEncode({
          'message': 'No se pueden registrar gastos en un ciclo cerrado (RN-01)',
        });
      } else {
        final amount = (body['amount'] as num).toDouble();
        final merchant = (body['merchant_name'] as String).trim();
        final txDate = DateTime.parse(body['transaction_date'] as String);

        // RN-03: Duplicate check if not forced
        if (!force) {
          final duplicates = DuplicateDetector.findDuplicates(
            existing: transactionsDb.map((m) => Transaction.fromJson(m)).toList(),
            merchantName: merchant,
            amount: amount,
            transactionDate: txDate,
          );

          if (duplicates.isNotEmpty) {
            duplicateWarningHits++;
            statusCode = 409;
            responseBody = jsonEncode({
              'message': 'Parece que este gasto ya fue registrado. ¿Deseas continuar? (RN-03)',
              'duplicate_warning': true,
              'existing_transactions': duplicates.map((d) => d.toJson()).toList(),
            });
            return http.StreamedResponse(
              Stream.value(utf8.encode(responseBody)),
              statusCode,
              headers: {'content-type': 'application/json'},
            );
          }
        } else {
          forceBypassHits++;
        }

        final txId = 'tx-${DateTime.now().microsecondsSinceEpoch}';
        final newTx = {
          'id': txId,
          'user_id': 'user-test',
          'cycle_id': body['cycle_id'] ?? cycleId,
          'allocation_id': body['allocation_id'],
          'receipt_scan_id': body['receipt_scan_id'],
          'source_account_id': body['source_account_id'],
          'amount': amount,
          'merchant_name': merchant,
          'transaction_date': body['transaction_date'],
          'transaction_type': body['transaction_type'] ?? 'expense',
          'entry_method': body['entry_method'] ?? 'manual',
          'notes': body['notes'],
          'created_at': DateTime.now().toIso8601String(),
        };
        transactionsDb.add(newTx);
        _deductAllocation(body['allocation_id'] as String?, amount);

        responseBody = jsonEncode(newTx);
        statusCode = 201;
      }
    }
    // --- Delete Transaction (/transactions/:id) ---
    else if (path.contains('/transactions/') && method == 'DELETE') {
      final id = path.split('/').last;
      final index = transactionsDb.indexWhere((t) => t['id'] == id);
      if (index >= 0) {
        final removed = transactionsDb.removeAt(index);
        final amount = (removed['amount'] as num).toDouble();
        _restoreAllocation(removed['allocation_id'] as String?, amount);
        responseBody = jsonEncode({'message': 'Transacción eliminada exitosamente'});
      } else {
        statusCode = 404;
        responseBody = jsonEncode({'message': 'Transacción no encontrada'});
      }
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  void _deductAllocation(String? allocId, double amount) {
    if (allocId == null) return;
    final alloc = allocationsDb.firstWhere(
      (a) => a['id'] == allocId,
      orElse: () => <String, dynamic>{},
    );
    if (alloc.isNotEmpty) {
      final currentSpent = (alloc['spent_amount'] as num?)?.toDouble() ?? 0.0;
      alloc['spent_amount'] = currentSpent + amount;
    }
  }

  void _restoreAllocation(String? allocId, double amount) {
    if (allocId == null) return;
    final alloc = allocationsDb.firstWhere(
      (a) => a['id'] == allocId,
      orElse: () => <String, dynamic>{},
    );
    if (alloc.isNotEmpty) {
      final currentSpent = (alloc['spent_amount'] as num?)?.toDouble() ?? 0.0;
      alloc['spent_amount'] = (currentSpent - amount).clamp(0.0, double.infinity);
    }
  }
}

/// Widget Test Double for Transaction Card (Stitch bd720de35f2b45fe856fff91b08e99f2)
class TransactionCardWidget extends StatelessWidget {
  const TransactionCardWidget({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final catColor = transaction.category?.parsedColor ?? AppColors.primary;
    final formattedAmount = '-\$${transaction.amount.toStringAsFixed(2)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            // Category avatar (44x44, 12px radius)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 22,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(width: 12),
            // Merchant, notes and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchantName,
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Method pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: transaction.isOcr
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          transaction.entryMethod.label,
                          style: AppTypography.captionBadge.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: transaction.isOcr ? AppColors.primaryAccessible : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (transaction.sourceAccount != null)
                        Expanded(
                          child: Text(
                            transaction.sourceAccount!.name,
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tabular figures amount
            Text(
              formattedAmount,
              style: AppTypography.numericRow.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.textMuted,
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget Test Double for Feed Analytics Bento Tile (Warm Cream #FCF5C7)
class FeedAnalyticsBentoWidget extends StatelessWidget {
  const FeedAnalyticsBentoWidget({
    super.key,
    required this.spentTotal,
    required this.allocatedTotal,
    required this.dailyAveragePace,
    required this.ocrCount,
  });

  final double spentTotal;
  final double allocatedTotal;
  final double dailyAveragePace;
  final int ocrCount;

  @override
  Widget build(BuildContext context) {
    final progress = allocatedTotal > 0 ? (spentTotal / allocatedTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHero, // Warm cream #FCF5C7
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ritmo de Gasto Quincenal',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              AppBadge(
                text: progress > 0.9 ? 'Alerta' : 'En meta',
                variant: progress > 0.9 ? AppBadgeVariant.expense : AppBadgeVariant.income,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${spentTotal.toStringAsFixed(2)}',
            style: AppTypography.currencyHeroMobile.copyWith(
              fontSize: 28,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          AppProgressBar(progress: progress),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ritmo diario: \$${dailyAveragePace.toStringAsFixed(2)} / día',
                style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
              ),
              Text(
                '$ocrCount OCR capturados',
                style: AppTypography.captionBadge.copyWith(
                  color: AppColors.primaryAccessible,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
