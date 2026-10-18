import 'package:quincena/features/budget/data/models/category.dart';
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
  /// Retorna un mapa con claves 'category_id' y 'account_id' para compatibilidad con tests.
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
    final pastMatch = history.firstWhere(
      (tx) {
        final txMerchant = tx.merchantName.trim().toLowerCase();
        return (txMerchant == clean ||
                clean.contains(txMerchant) ||
                txMerchant.contains(clean)) &&
            tx.category != null &&
            !tx.category!.isArchived;
      },
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
        'account_id': pastMatch.sourceAccountId.isNotEmpty
            ? pastMatch.sourceAccountId
            : pastMatch.category!.defaultAccountId,
      };
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
