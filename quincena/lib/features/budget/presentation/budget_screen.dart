import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme.dart';
import '../../auth/data/auth_session_manager.dart';
import '../../categories/data/categories_api_service.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../categories/presentation/widgets/category_form_sheet.dart';
import '../data/models/models.dart';
import '../data/services/budget_api_service.dart';
import 'notifiers/budget_notifier.dart';
import 'widgets/allocation_form_sheet.dart';
import 'widgets/allocation_item_tile.dart';
import 'widgets/funding_accounts_summary.dart';
import 'widgets/template_item_form_sheet.dart';
import 'widgets/templates_tab_view.dart';
import 'widgets/zero_base_header_card.dart';

/// Pantalla Principal de Distribución Quincenal y Presupuestos Base Cero (RF-03 & RF-04)
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.apiClient,
    this.sessionManager,
    this.budgetNotifier,
  });

  final ApiClient apiClient;
  final AuthSessionManager? sessionManager;
  final BudgetNotifier? budgetNotifier;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late final BudgetApiService _apiService;
  late final BudgetNotifier _notifier;
  late final TabController _tabController;
  late final bool _internalNotifier;

  @override
  void initState() {
    super.initState();
    _apiService = BudgetApiService(widget.apiClient);
    _internalNotifier = widget.budgetNotifier == null;
    _notifier = widget.budgetNotifier ?? BudgetNotifier(apiService: _apiService);
    _tabController = TabController(length: 2, vsync: this);
    if (_internalNotifier) {
      _notifier.loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_internalNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  Future<Category?> _openCreateCategoryModal() async {
    final categoriesService = CategoriesApiService(widget.apiClient);
    final newCat = await showModalBottomSheet<Category?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryFormSheet(
        accounts: _notifier.accounts,
        onSave: ({
          required String name,
          required String icon,
          required String colorHex,
          String? defaultAccountId,
        }) async {
          return await categoriesService.createCategory(
            name: name,
            icon: icon,
            colorHex: colorHex,
            defaultAccountId: defaultAccountId,
          );
        },
      ),
    );

    if (newCat != null) {
      await _notifier.loadData();
    }
    return newCat;
  }

  void _openAllocationSheet([BudgetAllocation? allocation]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AllocationFormSheet(
        allocation: allocation,
        categories: _notifier.categories,
        accounts: _notifier.accounts,
        currentUnallocated: _notifier.summary.unallocated,
        onCreateCategoryRequested: _openCreateCategoryModal,
        onSave: ({
          required String categoryId,
          required double allocatedAmount,
          String? destinationAccountId,
        }) async {
          if (allocation == null) {
            await _notifier.createAllocation(
              categoryId: categoryId,
              allocatedAmount: allocatedAmount,
              destinationAccountId: destinationAccountId,
            );
          } else {
            await _notifier.updateAllocation(
              allocation.id,
              allocatedAmount: allocatedAmount,
              destinationAccountId: destinationAccountId,
              clearDestinationAccount: destinationAccountId == null,
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteAllocation(BudgetAllocation allocation) async {
    final catName = allocation.category?.name ?? 'esta partida';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        title: Text('Eliminar Partida', style: AppTypography.headlineSm),
        content: Text(
          '¿Estás seguro de que deseas eliminar la partida de "$catName"?\n'
          'El monto de ${formatMoney(allocation.allocatedAmount)} volverá al saldo Por Asignar.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notifier.deleteAllocation(allocation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partida "$catName" eliminada.'),
            backgroundColor: AppColors.textMain,
          ),
        );
      }
    }
  }

  void _openTemplateSheet([BudgetTemplate? template]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => TemplateItemFormSheet(
        template: template,
        period: _notifier.selectedTemplatePeriod,
        existingTemplates: _notifier.currentTemplates,
        categories: _notifier.categories,
        accounts: _notifier.accounts,
        estimatedIncome: _notifier.activeCycle?.totalIncome ?? 0.0,
        onCreateCategoryRequested: _openCreateCategoryModal,
        onSave: ({
          required QuincenaPeriod period,
          required String categoryId,
          required double defaultAmount,
          String? destinationAccountId,
        }) async {
          if (template == null) {
            await _notifier.createTemplateItem(
              period: period,
              categoryId: categoryId,
              defaultAmount: defaultAmount,
              destinationAccountId: destinationAccountId,
            );
          } else {
            await _notifier.updateTemplateItem(
              template.id,
              defaultAmount: defaultAmount,
              destinationAccountId: destinationAccountId,
              clearDestinationAccount: destinationAccountId == null,
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteTemplate(BudgetTemplate template) async {
    final catName = template.category?.name ?? 'esta partida';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        title: Text('Eliminar de Plantilla', style: AppTypography.headlineSm),
        content: Text(
          '¿Deseas quitar la partida de "$catName" de la plantilla de ${template.period.label}?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notifier.deleteTemplateItem(template.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partida "$catName" removida de la plantilla.'),
            backgroundColor: AppColors.textMain,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppAppBar(
        title: 'Presupuestos Quincenales',
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined, color: AppColors.textMain),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoriesScreen(apiClient: widget.apiClient),
                ),
              );
              _notifier.loadData();
            },
            tooltip: 'Mantenimiento de Categorías',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMain),
            onPressed: _notifier.loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) {
          if (_notifier.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccessible),
            );
          }

          return Column(
            children: [
              // TabBar superior personalizado
              Container(
                color: AppColors.surfaceBase,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.textMain,
                  labelStyle: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                  unselectedLabelColor: AppColors.textSecondary,
                  unselectedLabelStyle: AppTypography.labelMd,
                  tabs: const [
                    Tab(text: 'Distribución Quincenal'),
                    Tab(text: 'Plantillas Maestras'),
                  ],
                ),
              ),

              // Contenido de las pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña 1: Distribución Quincenal y Base Cero (RF-03)
                    _buildDistributionTab(),

                    // Pestaña 2: Plantillas Maestras 1ra y 2da Quincena (RF-04)
                    _buildTemplatesTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textMain,
        elevation: 2,
        onPressed: () {
          if (_tabController.index == 0) {
            _openAllocationSheet();
          } else {
            _openTemplateSheet();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Nueva Partida' : 'Nueva Plantilla',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildDistributionTab() {
    final cycle = _notifier.activeCycle;
    final allocations = _notifier.allocations;
    final summary = _notifier.summary;
    final fundingSummaries = _notifier.fundingSummaries;

    return RefreshIndicator(
      color: AppColors.primaryAccessible,
      onRefresh: _notifier.loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // CASO: No hay ciclo activo
          if (cycle == null) ...[
            AppCard(
              backgroundColor: AppColors.surfaceHero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primaryAccessible, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sin Quincena Activa', style: AppTypography.labelLg),
                            Text(
                              'Inicia una quincena desde el Inicio para distribuir tu presupuesto.',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Tarjeta Hero: Presupuesto Base Cero (RF-03)
            ZeroBaseHeaderCard(
              summary: summary,
              cycle: cycle,
            ),
            const SizedBox(height: 20),

            // Resumen de Cuentas de Fondeo (RF-03 / R1)
            if (allocations.isNotEmpty) ...[
              FundingAccountsSummarySection(summaries: fundingSummaries),
              const SizedBox(height: 20),
            ],

            // Encabezado de la lista de partidas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pie_chart_outline_rounded,
                        size: 18, color: AppColors.primaryAccessible),
                    const SizedBox(width: 8),
                    Text('Partidas del Presupuesto', style: AppTypography.headlineSm),
                  ],
                ),
                Text(
                  '${allocations.length} ${allocations.length == 1 ? "bolsa" : "bolsas"}',
                  style: AppTypography.captionBadge,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista de partidas o estado vacío
            if (allocations.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: AppRadius.borderCard,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Aún no tienes partidas asignadas',
                          style: AppTypography.headlineSm),
                      const SizedBox(height: 6),
                      Text(
                        'Asigna bolsas por categoría y cuenta destino para lograr tu Base Cero, '
                        'o aplica una plantilla predefinida en la segunda pestaña.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: '+ Asignar Primera Partida',
                        isFullWidth: false,
                        onPressed: () => _openAllocationSheet(),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allocations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final alloc = allocations[index];
                  return AllocationItemTile(
                    allocation: alloc,
                    onEdit: () => _openAllocationSheet(alloc),
                    onDelete: () => _confirmDeleteAllocation(alloc),
                  );
                },
              ),
            ],
            const SizedBox(height: 80), // Margen para el FAB
          ],
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return RefreshIndicator(
      color: AppColors.primaryAccessible,
      onRefresh: _notifier.loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          TemplatesTabView(
            selectedPeriod: _notifier.selectedTemplatePeriod,
            templates: _notifier.currentTemplates,
            categories: _notifier.categories,
            accounts: _notifier.accounts,
            hasActiveCycle: _notifier.activeCycle != null,
            activeCycleHasAllocations: _notifier.allocations.isNotEmpty,
            isActionLoading: _notifier.isActionLoading,
            onPeriodChanged: (period) => _notifier.switchTemplatePeriod(period),
            onAddTemplateItem: () => _openTemplateSheet(),
            onEditTemplateItem: (t) => _openTemplateSheet(t),
            onDeleteTemplateItem: (t) => _confirmDeleteTemplate(t),
            onApplyTemplate: ({required bool overwrite}) async {
              await _notifier.applyTemplate(overwrite: overwrite);
              // Cambiar a la pestaña de distribución para visualizar las partidas precargadas
              _tabController.animateTo(0);
            },
            onSaveCycleAsTemplate: () => _notifier.saveCycleAsTemplate(),
          ),
          const SizedBox(height: 80), // Margen para el FAB
        ],
      ),
    );
  }
}
