import '../../../core/network/api_client.dart';
import '../../budget/data/models/category.dart';

/// Servicio de API para gestión de categorías maestras (RF-CAT-01)
class CategoriesApiService {
  const CategoriesApiService(this._apiClient);

  final ApiClient _apiClient;

  /// Obtiene la lista de categorías del usuario
  Future<List<Category>> getCategories({bool includeArchived = false}) async {
    final endpoint =
        includeArchived ? '/categories?include_archived=true' : '/categories';
    final response = await _apiClient.get(endpoint);

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
    }
    return [];
  }

  /// Crea una nueva categoría
  Future<Category> createCategory({
    required String name,
    String? icon,
    String? colorHex,
    String? defaultAccountId,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      if (icon != null && icon.isNotEmpty) 'icon': icon,
      if (colorHex != null && colorHex.isNotEmpty) 'color_hex': colorHex,
      if (defaultAccountId != null && defaultAccountId.isNotEmpty)
        'default_account_id': defaultAccountId,
    };

    final response = await _apiClient.post(
      '/categories',
      body: data,
    );

    return Category.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza una categoría existente
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? icon,
    String? colorHex,
    String? defaultAccountId,
    bool? isArchived,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      'icon': ?icon,
      'color_hex': ?colorHex,
      'default_account_id': ?defaultAccountId,
      'is_archived': ?isArchived,
    };

    final response = await _apiClient.patch(
      '/categories/$id',
      body: data,
    );

    return Category.fromJson(response as Map<String, dynamic>);
  }

  /// Archiva una categoría (soft-delete, CA-C1.3)
  Future<Category> archiveCategory(String id) async {
    final response = await _apiClient.delete(
      '/categories/$id',
    );

    return Category.fromJson(response as Map<String, dynamic>);
  }
}
