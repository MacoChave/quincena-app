import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme.dart';
import '../../budget/data/models/category.dart';
import '../../budget/presentation/widgets/icon_helper.dart';
import '../../financial_accounts/data/financial_accounts_api_service.dart';
import '../../financial_accounts/models/financial_account.dart';
import '../data/categories_api_service.dart';
import 'widgets/category_form_sheet.dart';

/// Screen C1: Mantenimiento de Categorías
///
/// Implementa las especificaciones de Stitch:
/// - Cabecera con título contextual y botón destacado "+ Nueva".
/// - Barra de búsqueda y contador dinámico de categorías activas ("X activas").
/// - Chips de filtro rápido: Todas, Fijas, Variables, Ahorro.
/// - Tarjetas de categoría con avatar de color e icono, cuenta vinculada, y acciones.
/// - Edición (Screen C2) y archivado lógico (CA-C1.3).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.apiClient,
  });

  final ApiClient apiClient;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoriesApiService _categoriesService;
  late final FinancialAccountsApiService _accountsService;

  List<Category> _categories = [];
  List<FinancialAccount> _accounts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, fijas, variables, ahorro

  @override
  void initState() {
    super.initState();
    _categoriesService = CategoriesApiService(widget.apiClient);
    _accountsService = FinancialAccountsApiService(widget.apiClient);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _categoriesService.getCategories(),
        _accountsService.getAccounts(),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _accounts = results[1] as List<FinancialAccount>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  List<Category> get _filteredCategories {
    return _categories.where((cat) {
      // 1. Filtro por texto
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = cat.name.toLowerCase().contains(query);
        final accMatch = cat.defaultAccount?.name.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !accMatch) return false;
      }

      // 2. Filtro rápido por tipo semántico
      if (_selectedFilter == 'fijas') {
        final n = cat.name.toLowerCase();
        return n.contains('renta') || n.contains('vivienda') || n.contains('servicio') || n.contains('luz') || n.contains('agua') || n.contains('gas');
      } else if (_selectedFilter == 'ahorro') {
        final n = cat.name.toLowerCase();
        return n.contains('ahorro') || n.contains('inversión') || n.contains('inversion');
      } else if (_selectedFilter == 'variables') {
        final n = cat.name.toLowerCase();
        final isFija = n.contains('renta') || n.contains('vivienda') || n.contains('servicio') || n.contains('luz') || n.contains('agua') || n.contains('gas');
        final isAhorro = n.contains('ahorro') || n.contains('inversión') || n.contains('inversion');
        return !isFija && !isAhorro;
      }

      return true;
    }).toList();
  }

  Future<void> _openCreateCategory() async {
    final newCat = await showModalBottomSheet<Category?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryFormSheet(
        accounts: _accounts,
        onSave: ({
          required String name,
          required String icon,
          required String colorHex,
          String? defaultAccountId,
        }) async {
          final created = await _categoriesService.createCategory(
            name: name,
            icon: icon,
            colorHex: colorHex,
            defaultAccountId: defaultAccountId,
          );
          return created;
        },
      ),
    );

    if (newCat != null && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría "${newCat.name}" creada con éxito'),
          backgroundColor: AppColors.incomeText,
        ),
      );
    }
  }

  Future<void> _openEditCategory(Category cat) async {
    final updated = await showModalBottomSheet<Category?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryFormSheet(
        category: cat,
        accounts: _accounts,
        onSave: ({
          required String name,
          required String icon,
          required String colorHex,
          String? defaultAccountId,
        }) async {
          return await _categoriesService.updateCategory(
            id: cat.id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            defaultAccountId: defaultAccountId,
          );
        },
      ),
    );

    if (updated != null && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría "${updated.name}" actualizada con éxito'),
          backgroundColor: AppColors.incomeText,
        ),
      );
    }
  }

  Future<void> _confirmArchiveCategory(Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Archivar Categoría?'),
        content: Text(
          'La categoría "${cat.name}" dejará de aparecer en nuevos selectores de gastos y plantillas. Las transacciones e historial previo se conservarán íntegros (CA-C1.3).',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _categoriesService.archiveCategory(cat.id);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría "${cat.name}" archivada.'),
          backgroundColor: AppColors.textMain,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al archivar: $e'),
          backgroundColor: AppColors.expenseText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: const AppAppBar(
        title: 'Mantenimiento de Categorías',
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.expenseText),
                          const SizedBox(height: 12),
                          Text('Error al cargar categorías', style: AppTypography.headlineSm),
                          const SizedBox(height: 6),
                          Text(_error!, style: AppTypography.bodySm, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          AppButton(text: 'Reintentar', onPressed: _loadData),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // Encabezado contextual con botón "+ Nueva"
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Categorías', style: AppTypography.headlineMd),
                                const SizedBox(height: 4),
                                Text(
                                  'Gestiona las etiquetas y cuentas asignadas para tus gastos',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: _openCreateCategory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Buscador y contador de activas
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: TextField(
                                style: AppTypography.bodyMd,
                                decoration: InputDecoration(
                                  hintText: 'Buscar categoría...',
                                  hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_categories.length} activas',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Chips de Filtro Rápido
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Todas', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Fijas', 'fijas'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Variables', 'variables'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Ahorro', 'ahorro'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Lista de Categorías
                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.category_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No se encontraron categorías para "$_searchQuery"'
                                    : 'No hay categorías en este filtro',
                                style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...filtered.map((cat) => _buildCategoryTile(cat)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textMain : AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.textMain : AppColors.borderSubtle,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.textMain.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: isSelected ? Colors.white : AppColors.textMain,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Category cat) {
    final defaultAcc = cat.defaultAccount ??
        _accounts.where((a) => a.id == cat.defaultAccountId).firstOrNull;

    final n = cat.name.toLowerCase();
    final isFijo = n.contains('renta') || n.contains('vivienda') || n.contains('servicio') || n.contains('luz');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(28, 36, 43, 0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.parsedColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              resolveCategoryIcon(cat.icon),
              size: 22,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(width: 14),

          // Datos de Categoría
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cat.name,
                        style: AppTypography.headlineSm.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFijo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Fijo',
                          style: AppTypography.captionBadge.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryAccessible,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      defaultAcc?.accountType.iconData ?? Icons.credit_card_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        defaultAcc?.name ?? 'Sin cuenta vinculada',
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

          // Acciones: Editar y Opciones
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.textMuted,
            tooltip: 'Editar Categoría',
            onPressed: () => _openEditCategory(cat),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'archive') {
                _confirmArchiveCategory(cat);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined, size: 18, color: AppColors.expenseText),
                    const SizedBox(width: 10),
                    Text(
                      'Archivar categoría',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.expenseText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
