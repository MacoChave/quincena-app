import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../budget/data/models/category.dart';
import '../../../budget/presentation/widgets/icon_helper.dart';
import '../../../financial_accounts/models/financial_account.dart';

/// Screen C2: Crear / Editar Categoría (Modal Bottom Sheet)
///
/// Implementa las directrices de Stitch:
/// - Drag handle y cabecera con subtítulo.
/// - Live preview tile reactivo (icono, color y nombre).
/// - Input de texto para nombre de categoría con botón limpiar.
/// - Selector visual de iconos financieros en carrusel/fila horizontal.
/// - Selector de paleta de colores pasteles oficiales (#79ADDC, #FFC09F, #FFEE93, #FCF5C7, #ADF7B6).
/// - Selector de cuenta destino predeterminada (opcional, CA-C1.1).
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({
    super.key,
    this.category,
    required this.accounts,
    required this.onSave,
  });

  final Category? category;
  final List<FinancialAccount> accounts;
  final Future<Category> Function({
    required String name,
    required String icon,
    required String colorHex,
    String? defaultAccountId,
  }) onSave;

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColorHex;
  String? _selectedAccountId;
  bool _isSaving = false;
  String? _error;

  static const List<Map<String, String>> _availableIcons = [
    {'name': 'shopping_cart', 'label': 'Supermercado'},
    {'name': 'home', 'label': 'Hogar / Renta'},
    {'name': 'directions_car', 'label': 'Transporte'},
    {'name': 'restaurant', 'label': 'Comida'},
    {'name': 'medical_services', 'label': 'Salud'},
    {'name': 'fitness_center', 'label': 'Gimnasio'},
    {'name': 'school', 'label': 'Estudio'},
    {'name': 'flight_takeoff', 'label': 'Viajes'},
    {'name': 'pets', 'label': 'Mascotas'},
    {'name': 'local_cafe', 'label': 'Ocio & Café'},
    {'name': 'bolt', 'label': 'Servicios'},
    {'name': 'savings', 'label': 'Ahorro'},
    {'name': 'payments', 'label': 'Efectivo'},
    {'name': 'credit_card', 'label': 'Tarjetas'},
  ];

  static const List<Map<String, String>> _colorSwatches = [
    {'hex': '#79ADDC', 'name': 'Azul cielo'},
    {'hex': '#FFC09F', 'name': 'Coral pastel'},
    {'hex': '#FFEE93', 'name': 'Amarillo suave'},
    {'hex': '#FCF5C7', 'name': 'Crema'},
    {'hex': '#ADF7B6', 'name': 'Verde menta'},
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedIcon = cat?.icon ?? 'shopping_cart';
    _selectedColorHex = cat?.colorHex ?? '#79ADDC';
    _selectedAccountId = cat?.defaultAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.primary;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre de categoría es obligatorio');
      return;
    }

    if (name.length > 60) {
      setState(() => _error = 'El nombre no puede exceder 60 caracteres');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final savedCat = await widget.onSave(
        name: name,
        icon: _selectedIcon,
        colorHex: _selectedColorHex,
        defaultAccountId: _selectedAccountId,
      );
      if (mounted) {
        Navigator.of(context).pop(savedCat);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentBgColor = _parseColor(_selectedColorHex);
    final displayName = _nameController.text.trim().isEmpty
        ? 'Sin nombre'
        : _nameController.text.trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Cabecera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: currentBgColor.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      resolveCategoryIcon(_selectedIcon),
                      size: 20,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          'Personaliza el icono, color y cuenta vinculada',
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),

            // Contenido scrolleable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Preview Tile (Stitch Screen C2)
                    Text(
                      'VISTA PREVIA INSTANTÁNEA',
                      style: AppTypography.labelSm.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderSubtle.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: currentBgColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: currentBgColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              resolveCategoryIcon(_selectedIcon),
                              size: 26,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTypography.headlineSm.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.incomeText,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedAccountId != null
                                            ? (widget.accounts
                                                    .where(
                                                      (a) =>
                                                          a.id ==
                                                          _selectedAccountId,
                                                    )
                                                    .firstOrNull
                                                    ?.name ??
                                                'Cuenta vinculada')
                                            : 'Sin cuenta predeterminada',
                                        style: AppTypography.captionBadge
                                            .copyWith(
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHero,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isEditing ? 'Edición' : 'Nueva',
                              style: AppTypography.captionBadge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input de Nombre
                    Text(
                      'Nombre de Categoría',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      maxLength: 60,
                      style: AppTypography.bodyLg,
                      decoration: InputDecoration(
                        hintText: 'Ej. Supermercado, Gimnasio, Renta',
                        hintStyle: AppTypography.bodyMd.copyWith(
                          color: AppColors.textMuted,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surfaceBase,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSubtle,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: _nameController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, size: 20),
                                color: AppColors.textMuted,
                                onPressed: () {
                                  _nameController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Selector de Icono
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Selecciona un icono representativo',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_availableIcons.length} opciones',
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableIcons.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = _availableIcons[index];
                          final iconKey = item['name']!;
                          final isSelected = _selectedIcon == iconKey;

                          return Tooltip(
                            message: item['label']!,
                            child: InkWell(
                              onTap: () {
                                setState(() => _selectedIcon = iconKey);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.textMain
                                      : AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.textMain
                                        : AppColors.borderSubtle,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.textMain
                                                .withValues(alpha: 0.2),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  resolveCategoryIcon(iconKey),
                                  size: 22,
                                  color: isSelected
                                      ? AppColors.surfaceBase
                                      : AppColors.textMain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Selector de Color
                    Text(
                      'Color distintivo',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _colorSwatches.map((swatch) {
                          final hex = swatch['hex']!;
                          final color = _parseColor(hex);
                          final isSelected =
                              _selectedColorHex.toUpperCase() ==
                                  hex.toUpperCase();

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedColorHex = hex);
                            },
                            child: Tooltip(
                              message: swatch['name']!,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.textMain,
                                          width: 2.5,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: isSelected ? 8 : 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: AppColors.textMain,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cuenta Destino Predeterminada (Opcional, CA-C1.1)
                    Text(
                      'Cuenta Destino por Defecto (Opcional)',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se autoseleccionará automáticamente al crear partidas con esta categoría.',
                      style: AppTypography.captionBadge.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          hint: const Text('Ninguna / Sin cuenta por defecto'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Ninguna / Sin cuenta por defecto'),
                            ),
                            ...widget.accounts.map((acc) {
                              return DropdownMenuItem<String?>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: acc.parsedColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        acc.name,
                                        style: AppTypography.bodyMd,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      acc.accountType.label,
                                      style: AppTypography.captionBadge.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAccountId = val);
                          },
                        ),
                      ),
                    ),

                    // Mensaje de Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expenseBg.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppColors.expenseText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.expenseText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    AppButton(
                      text: isEditing
                          ? 'Guardar Cambios'
                          : 'Crear Categoría',
                      isLoading: _isSaving,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
