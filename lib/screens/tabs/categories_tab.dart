import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class CategoriesTab extends StatelessWidget {
  final AppState appState;

  const CategoriesTab({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final expCats = appState.categoriesByType(TransactionType.expense);
    final incCats = appState.categoriesByType(TransactionType.income);
    final ym = appState.selectedYearMonth;
    final discreet = appState.discreetMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        // 1. Seção de Categorias de Despesa (Inset Grouped)
        _CategoryGroupSection(
          title: 'Categorias de Despesa',
          actionLabel: 'Nova Categoria',
          actionColor: AppColors.iosBlue,
          categories: expCats,
          yearMonth: ym,
          discreet: discreet,
          appState: appState,
          onAddTap: () {
            HapticFeedback.lightImpact();
            showCategoryModal(
              context,
              appState,
              initialType: TransactionType.expense,
            );
          },
          onEditCategory: (cat) {
            HapticFeedback.lightImpact();
            showCategoryModal(
              context,
              appState,
              existing: cat,
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 2. Seção de Categorias de Receita (Inset Grouped)
        _CategoryGroupSection(
          title: 'Categorias de Receita',
          actionLabel: 'Adicionar',
          actionColor: AppColors.iosGreen,
          categories: incCats,
          yearMonth: ym,
          discreet: discreet,
          appState: appState,
          onAddTap: () {
            HapticFeedback.lightImpact();
            showCategoryModal(
              context,
              appState,
              initialType: TransactionType.income,
            );
          },
          onEditCategory: (cat) {
            HapticFeedback.lightImpact();
            showCategoryModal(
              context,
              appState,
              existing: cat,
            );
          },
        ),
      ],
    );
  }

  static Future<void> showCategoryModal(
    BuildContext context,
    AppState appState, {
    CategoryItem? existing,
    TransactionType? initialType,
  }) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditorSheet(
        appState: appState,
        existing: existing,
        initialType: initialType,
      ),
    );
  }
}

/// 1. Bloco Agrupado de Categorias (Estilo `CupertinoListSection.insetGrouped`)
class _CategoryGroupSection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final Color actionColor;
  final List<CategoryItem> categories;
  final String yearMonth;
  final bool discreet;
  final AppState appState;
  final VoidCallback onAddTap;
  final ValueChanged<CategoryItem> onEditCategory;

  const _CategoryGroupSection({
    required this.title,
    required this.actionLabel,
    required this.actionColor,
    required this.categories,
    required this.yearMonth,
    required this.discreet,
    required this.appState,
    required this.onAddTap,
    required this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HigSectionHeader(
          title: title,
          trailing: GestureDetector(
            onTap: onAddTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.add,
                    size: 14,
                    color: actionColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        HigGroupedCard(
          children: [
            for (int i = 0; i < categories.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: AppSpacing.hairlineBorder,
                  indent: 62,
                  color: AppColors.border(context),
                ),
              _CategoryListRow(
                cat: categories[i],
                monthlyAmount: appState.categoryMonthlyAmount(
                  categories[i].id,
                  yearMonth,
                ),
                discreet: discreet,
                onTap: () => onEditCategory(categories[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 2. Linha de Categoria Individual com Squircles 12% e Números Tabulares
class _CategoryListRow extends StatelessWidget {
  final CategoryItem cat;
  final double monthlyAmount;
  final bool discreet;
  final VoidCallback onTap;

  const _CategoryListRow({
    required this.cat,
    required this.monthlyAmount,
    required this.discreet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = cat.hasBudget;
    final ratio = hasBudget
        ? (monthlyAmount / cat.monthlyBudget).clamp(0.0, 1.0)
        : 0.0;
    final pctUsed = hasBudget && cat.monthlyBudget > 0
        ? ((monthlyAmount / cat.monthlyBudget) * 100).round()
        : 0;
    final isOver = hasBudget && monthlyAmount > cat.monthlyBudget + 0.005;
    final isWarn = hasBudget && !isOver && ratio >= 0.80;
    final barColor = isOver
        ? AppColors.danger(context)
        : (isWarn ? AppColors.warning(context) : AppColors.success(context));

    final amountColor = monthlyAmount > 0
        ? (cat.type == TransactionType.income
            ? AppColors.success(context)
            : (isOver
                ? AppColors.danger(context)
                : AppColors.textPrimary(context)))
        : AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          children: [
            Row(
              children: [
                HigIconSquircle(
                  icon: cat.icon,
                  color: cat.color,
                  size: 38,
                  iconSize: 19,
                  radius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBudget
                            ? 'Teto mensal: ${AppFormatters.currency(cat.monthlyBudget, discreet: discreet)} ($pctUsed%)'
                            : (cat.type == TransactionType.expense
                                ? 'Sem teto mensal • Toque para editar'
                                : 'Categoria de receita • Toque para editar'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              hasBudget ? FontWeight.w600 : FontWeight.w500,
                          color: hasBudget && (isOver || isWarn)
                              ? barColor
                              : AppColors.textSecondary(context),
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.currency(monthlyAmount, discreet: discreet),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: amountColor,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'no mês',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textSecondary(context).withValues(alpha: 0.6),
                ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 8),
              HigAnimatedProgressBar(
                value: ratio,
                color: barColor,
                minHeight: 5,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 3. Modal Translúcido de Criação / Edição de Categoria (Frosted Glass)
class _CategoryEditorSheet extends StatefulWidget {
  final AppState appState;
  final CategoryItem? existing;
  final TransactionType? initialType;

  const _CategoryEditorSheet({
    required this.appState,
    this.existing,
    this.initialType,
  });

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _budgetCtrl;
  late TransactionType _type;
  late String _iconKey;
  late int _colorVal;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _budgetCtrl = TextEditingController(
      text: (ex != null && ex.hasBudget)
          ? CentavosCurrencyFormatter.formatDouble(ex.monthlyBudget)
          : '',
    );
    _type = ex?.type ?? widget.initialType ?? TransactionType.expense;
    _iconKey = ex?.iconKey ?? 'category';
    _colorVal = ex?.colorValue ?? AppColors.presetPalette.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Digite o nome da categoria.');
      return;
    }
    final budgetVal = _type == TransactionType.expense
        ? CentavosCurrencyFormatter.parseValue(_budgetCtrl.text)
        : 0.0;
    await widget.appState.saveCategory(
      id: widget.existing?.id,
      name: name,
      iconKey: _iconKey,
      colorValue: _colorVal,
      type: _type,
      monthlyBudget: budgetVal,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) return;
    HapticFeedback.lightImpact();
    await widget.appState.deleteCategory(ex.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ex = widget.existing;
    final canDelete = ex != null &&
        widget.appState.categoriesByType(ex.type).length > 1;
    final selectedColor = Color(_colorVal);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + inset),
          decoration: BoxDecoration(
            color: AppColors.surface(context).withValues(alpha: 0.94),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppColors.border(context),
                width: AppSpacing.hairlineBorder,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(context)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ex == null ? 'Nova Categoria' : 'Editar Categoria',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (canDelete)
                        Tooltip(
                          message: 'Excluir Categoria',
                          child: GestureDetector(
                            onTap: _delete,
                            behavior: HitTestBehavior.opaque,
                            child: const HigIconSquircle(
                              icon: CupertinoIcons.trash,
                              color: AppColors.iosRed,
                              size: 34,
                              iconSize: 17,
                              radius: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<TransactionType>(
                    groupValue: _type,
                    onValueChanged: (v) {
                      if (v != null) {
                        HapticFeedback.lightImpact();
                        setState(() => _type = v);
                      }
                    },
                    children: const {
                      TransactionType.expense: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Despesa',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TransactionType.income: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Receita',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _errorText != null
                            ? AppColors.iosRed
                            : AppColors.border(context),
                        width: AppSpacing.hairlineBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: ex == null,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nome da Categoria',
                        errorText: _errorText,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_type == TransactionType.expense) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.border(context),
                          width: AppSpacing.hairlineBorder,
                        ),
                      ),
                      child: TextField(
                        controller: _budgetCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          const CentavosCurrencyFormatter(),
                        ],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppTypography.tabular,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Teto Mensal Opcional (R\$)',
                          hintText: '0,00 (sem limite)',
                          prefixText: 'R\$ ',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'ÍCONE',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppIconsCatalog.icons.entries.map((entry) {
                      final selected = _iconKey == entry.key;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _iconKey = entry.key);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? selectedColor.withValues(alpha: 0.14)
                                : AppColors.secondarySurface(context),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: selected
                                  ? selectedColor
                                  : AppColors.border(context),
                              width: selected ? 1.5 : AppSpacing.hairlineBorder,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            size: 20,
                            color: selected
                                ? selectedColor
                                : AppColors.textSecondary(context),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'COR',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AppColors.presetPalette.map((color) {
                      final val = color.toARGB32();
                      final selected = _colorVal == val;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _colorVal = val);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: AppColors.textPrimary(context),
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.iosBlue,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _save,
                      child: const Text(
                        'Salvar Categoria',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
