import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/receipt_scan.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';

/// Resultado estructurado de sugerencia de categoría y cuenta financiera (CA-05.2, RN-CAT-01)
class SuggestionResult {
  const SuggestionResult({
    this.categoryId,
    this.accountId,
    this.matchedCategory,
  });

  final String? categoryId;
  final String? accountId;
  final Category? matchedCategory;

  bool get hasSuggestion => categoryId != null;
}

/// Motor de sugerencia automática de categorías y cuentas de débito para comprobantes OCR
/// basado en historial de compras y heurísticas semánticas de comercio (CA-05.2, RN-CAT-01).
abstract final class SuggestionEngine {
  /// Sugiere la categoría y cuenta financiera para un comercio dado.
  /// Retorna un mapa con claves 'category_id' y 'account_id' para compatibilidad con tests y servicios.
  static Map<String, String?> suggestCategoryAndAccount({
    required String merchantName,
    required List<Transaction> history,
    required List<Category> categories,
  }) {
    final clean = merchantName.trim().toLowerCase();
    if (clean.isEmpty) {
      return {'category_id': null, 'account_id': null};
    }

    final activeCategories = categories.where((c) => !c.isArchived).toList();

    // 1. Coincidencia exacta o parcial en el historial de transacciones del usuario
    for (final tx in history) {
      final txMerchant = tx.merchantName.trim().toLowerCase();
      // Protección contra falsos positivos:
      // - Si txMerchant está vacío o solo contiene espacios, no debe coincidir (en Dart, anyString.contains("") == true).
      // - Coincidencia exacta permitida para cualquier longitud (ej. "OX", "BP").
      // - Coincidencia parcial/subcadena requiere longitud mínima (>= 3 caracteres) en ambas cadenas
      //   para evitar coincidencias accidentales con sílabas cortas como "la", "de", "el".
      final isExactMatch = txMerchant.isNotEmpty && txMerchant == clean;
      final isSubstringMatch = txMerchant.length >= 3 &&
          clean.length >= 3 &&
          (clean.contains(txMerchant) || txMerchant.contains(clean));

      if ((isExactMatch || isSubstringMatch) && tx.category != null) {
        final catMatch = activeCategories
            .where((c) => c.id == tx.category!.id)
            .firstOrNull;
        if (catMatch != null) {
          final accountId = tx.sourceAccountId.isNotEmpty
              ? tx.sourceAccountId
              : catMatch.defaultAccountId;
          return {
            'category_id': catMatch.id,
            'account_id': accountId,
          };
        }
      }
    }

    // 2. Heurística semántica por palabras clave comunes en comercios de Centroamérica
    String? matchedCatId;
    final normalized = _normalizeText(clean);

    if (normalized.contains('super') ||
        normalized.contains('walmart') ||
        normalized.contains('paiz') ||
        normalized.contains('despensa') ||
        normalized.contains('la torre') ||
        normalized.contains('market') ||
        normalized.contains('abarroteria')) {
      matchedCatId = activeCategories
          .where((c) =>
              _normalizeText(c.name).contains('super') ||
              _normalizeText(c.name).contains('mercado'))
          .firstOrNull
          ?.id;
    } else if (normalized.contains('cafe') ||
        normalized.contains('starbucks') ||
        normalized.contains('restaurante') ||
        normalized.contains('comida') ||
        normalized.contains('baker') ||
        normalized.contains('panaderia') ||
        normalized.contains('bar') ||
        normalized.contains('deli')) {
      matchedCatId = activeCategories
          .where((c) =>
              _normalizeText(c.name).contains('ocio') ||
              _normalizeText(c.name).contains('cafe') ||
              _normalizeText(c.name).contains('comida') ||
              _normalizeText(c.name).contains('salidas'))
          .firstOrNull
          ?.id;
    } else if (normalized.contains('gas') ||
        normalized.contains('gasolinera') ||
        normalized.contains('puma') ||
        normalized.contains('shell') ||
        normalized.contains('texaco') ||
        normalized.contains('uber') ||
        normalized.contains('combustible') ||
        normalized.contains('taller')) {
      matchedCatId = activeCategories
          .where((c) => _normalizeText(c.name).contains('transporte'))
          .firstOrNull
          ?.id;
    } else if (normalized.contains('farmacia') ||
        normalized.contains('galeno') ||
        normalized.contains('salud') ||
        normalized.contains('hospital') ||
        normalized.contains('medico')) {
      matchedCatId = activeCategories
          .where((c) => _normalizeText(c.name).contains('salud'))
          .firstOrNull
          ?.id;
    }

    // 3. Herencia de la cuenta predeterminada configurada en la categoría (RN-CAT-01)
    String? defaultAccountId;
    if (matchedCatId != null) {
      final category =
          activeCategories.where((c) => c.id == matchedCatId).firstOrNull;
      defaultAccountId = category?.defaultAccountId;
    }

    return {
      'category_id': matchedCatId,
      'account_id': defaultAccountId,
    };
  }

  /// Sugiere la categoría según historial o palabras clave del comercio.
  static String? suggestCategory({
    required String? merchantName,
    required List<Category> categories,
    List<Transaction> history = const [],
  }) {
    final activeCategories = categories.where((c) => !c.isArchived).toList();
    if (activeCategories.isEmpty) return null;
    if (merchantName == null || merchantName.trim().isEmpty) {
      return activeCategories.first.id;
    }

    final suggestion = suggestCategoryAndAccount(
      merchantName: merchantName,
      history: history,
      categories: activeCategories,
    );

    if (suggestion['category_id'] != null) {
      return suggestion['category_id'];
    }

    // Coincidencia directa por nombre de categoría con protección de longitud mínima
    final cleanMerchant = merchantName.trim().toLowerCase();
    for (final cat in activeCategories) {
      final catNorm = cat.name.trim().toLowerCase();
      final isExact = catNorm.isNotEmpty && cleanMerchant == catNorm;
      final isSubstring = catNorm.length >= 3 &&
          cleanMerchant.length >= 3 &&
          (cleanMerchant.contains(catNorm) || catNorm.contains(cleanMerchant));
      if (isExact || isSubstring) {
        return cat.id;
      }
    }

    return activeCategories.first.id;
  }

  /// Sugiere la cuenta de fondeo (CA-05.2, RN-CAT-01).
  static String? suggestAccount({
    required ReceiptScan scan,
    required String? categoryId,
    required List<Category> categories,
    required List<FinancialAccount> accounts,
  }) {
    if (accounts.isEmpty) return null;

    // 1. Si el escaneo ya extrajo o tiene sugerida una cuenta válida
    if (scan.suggestedAccountId != null &&
        scan.suggestedAccountId!.isNotEmpty) {
      final exists = accounts.any((a) => a.id == scan.suggestedAccountId);
      if (exists) return scan.suggestedAccountId;
    }

    // 2. Si la categoría seleccionada tiene configurada default_account_id (RN-CAT-01)
    if (categoryId != null) {
      final cat = categories.where((c) => c.id == categoryId).firstOrNull;
      if (cat != null &&
          cat.defaultAccountId != null &&
          cat.defaultAccountId!.isNotEmpty) {
        final exists = accounts.any((a) => a.id == cat.defaultAccountId);
        if (exists) return cat.defaultAccountId;
      }
    }

    // 3. Cuenta predeterminada del usuario (isDefault == true)
    final defaultAcc = accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => accounts.first,
    );
    return defaultAcc.id;
  }

  /// Normaliza texto removiendo acentos, signos de puntuación y espacios extras
  static String _normalizeText(String input) {
    var text = input.toLowerCase().trim();
    text = text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
    return text.replaceAll(RegExp(r'[#*.,\-_/&]'), ' ');
  }
}

/// Alias para interoperabilidad
typedef OcrSuggestionEngine = SuggestionEngine;
