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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        HigSectionHeader(
          title: 'Categorias de Despesa',
          trailing: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () => showCategoryModal(
              context,
              appState,
              initialType: TransactionType.expense,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Nova Categoria',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        HigGroupedCard(
          children: [
            for (int i = 0; i < expCats.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _CategoryListRow(
                cat: expCats[i],
                monthlyAmount: appState.categoryMonthlyAmount(expCats[i].id, ym),
                discreet: discreet,
                onTap: () => showCategoryModal(
                  context,
                  appState,
                  existing: expCats[i],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),

        HigSectionHeader(
          title: 'Categorias de Receita',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => showCategoryModal(
              context,
              appState,
              initialType: TransactionType.income,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Adicionar',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        HigGroupedCard(
          children: [
            for (int i = 0; i < incCats.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _CategoryListRow(
                cat: incCats[i],
                monthlyAmount: appState.categoryMonthlyAmount(incCats[i].id, ym),
                discreet: discreet,
                onTap: () => showCategoryModal(
                  context,
                  appState,
                  existing: incCats[i],
                ),
              ),
            ],
          ],
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
    HapticFeedback.selectionClick();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final budgetCtrl = TextEditingController(
      text: (existing != null && existing.hasBudget)
          ? CentavosCurrencyFormatter.formatDouble(existing.monthlyBudget)
          : '',
    );
    TransactionType type =
        existing?.type ?? initialType ?? TransactionType.expense;
    String iconKey = existing?.iconKey ?? 'category';
    int colorVal =
        existing?.colorValue ?? AppColors.presetPalette.first.toARGB32();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existing == null
                                ? 'Nova Categoria'
                                : 'Editar Categoria',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (existing != null &&
                              appState.categoriesByType(existing.type).length >
                                  1)
                            IconButton(
                              onPressed: () async {
                                await appState.deleteCategory(existing.id);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger(context),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CupertinoSlidingSegmentedControl<TransactionType>(
                        groupValue: type,
                        onValueChanged: (v) {
                          if (v != null) setModalState(() => type = v);
                        },
                        children: const {
                          TransactionType.expense: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Despesa'),
                          ),
                          TransactionType.income: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Receita'),
                          ),
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        autofocus: existing == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Categoria',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (type == TransactionType.expense) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: budgetCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            const CentavosCurrencyFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Teto Mensal Opcional (R\$)',
                            hintText: '0,00 (sem limite)',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Ícone',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppIconsCatalog.icons.entries.map((entry) {
                          final selected = iconKey == entry.key;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                setModalState(() => iconKey = entry.key),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Color(colorVal).withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? Color(colorVal)
                                      : AppColors.border(context),
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                size: 20,
                                color: selected
                                    ? Color(colorVal)
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: AppColors.presetPalette.map((color) {
                          final val = color.toARGB32();
                          final selected = colorVal == val;
                          return GestureDetector(
                            onTap: () => setModalState(() => colorVal = val),
                            child: Container(
                              width: 32,
                              height: 32,
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
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final budgetVal = type == TransactionType.expense
                                ? CentavosCurrencyFormatter.parseValue(
                                    budgetCtrl.text,
                                  )
                                : 0.0;
                            await appState.saveCategory(
                              id: existing?.id,
                              name: name,
                              iconKey: iconKey,
                              colorValue: colorVal,
                              type: type,
                              monthlyBudget: budgetVal,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'Salvar Categoria',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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
    final isOver = hasBudget && monthlyAmount > cat.monthlyBudget + 0.005;
    final isWarn = hasBudget && !isOver && ratio >= 0.80;
    final barColor = isOver
        ? AppColors.danger(context)
        : (isWarn ? AppColors.warning(context) : AppColors.success(context));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBudget
                            ? 'Teto mensal: ${AppFormatters.currency(cat.monthlyBudget, discreet: discreet)}'
                            : (cat.type == TransactionType.expense
                                ? 'Sem teto mensal • Toque para editar'
                                : 'Categoria de receita • Toque para editar'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: monthlyAmount > 0
                            ? (cat.type == TransactionType.income
                                ? AppColors.success(context)
                                : (isOver
                                    ? AppColors.danger(context)
                                    : AppColors.textPrimary(context)))
                            : AppColors.textSecondary(context),
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
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary(context),
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
