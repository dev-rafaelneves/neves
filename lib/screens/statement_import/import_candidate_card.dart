import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ImportCandidateCard extends StatelessWidget {
  final ImportedTransactionCandidate candidate;
  final ImportTargetMode targetMode;
  final List<Account> accounts;
  final List<CategoryModel> categories;
  final List<GoalModel> goals;
  final String? selectedGoalId;
  final String? selectedCounterpartAccountId;
  final ValueChanged<bool> onToggleSelected;
  final VoidCallback onToggleType;
  final VoidCallback onToggleIgnored;
  final VoidCallback onChanged;

  const ImportCandidateCard({
    super.key,
    required this.candidate,
    required this.targetMode,
    required this.accounts,
    required this.categories,
    required this.goals,
    required this.selectedGoalId,
    required this.selectedCounterpartAccountId,
    required this.onToggleSelected,
    required this.onToggleType,
    required this.onToggleIgnored,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = candidate;

    late final Color badgeColor;
    late final String badgeText;

    if (targetMode == ImportTargetMode.cofrinho) {
      switch (c.cofrinhoOp) {
        case CofrinhoOperationKind.deposit:
          badgeColor = AppColors.primary;
          badgeText = 'Aporte (+ Caixinha) ⇄';
          break;
        case CofrinhoOperationKind.withdraw:
          badgeColor = AppColors.amber;
          badgeText = 'Resgate (- Caixinha) ⇄';
          break;
        case CofrinhoOperationKind.yieldGain:
          badgeColor = AppColors.emerald;
          badgeText = 'Rendimento (+ Caixinha) ⇄';
          break;
      }
    } else if (targetMode == ImportTargetMode.transfer) {
      badgeColor =
          c.isOutgoingTransfer ? AppColors.rose : AppColors.emerald;
      badgeText = c.isOutgoingTransfer
          ? 'Saída ➔ Outra Conta ⇄'
          : 'Entrada ⬅ Outra Conta ⇄';
    } else {
      badgeColor = c.type == TransactionType.income
          ? AppColors.emerald
          : AppColors.rose;
      badgeText = c.type == TransactionType.income ? 'Receita ⇄' : 'Despesa ⇄';
    }

    return Opacity(
      opacity: c.ignored ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: c.selected,
                    onChanged: (v) => onToggleSelected(v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(c.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleType,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(c.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onToggleIgnored,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        c.ignored ? AppColors.warning(context) : null,
                  ),
                  icon: Icon(
                    c.ignored
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(
                    c.ignored
                        ? 'Ignorada (não conta em nada)'
                        : 'Ignorar (não é minha)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (c.isDuplicate)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Text(
                    'Possível duplicata já existente no seu extrato (desmarcado automaticamente)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: _buildSelector(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelector(BuildContext context) {
    final c = candidate;
    if (targetMode == ImportTargetMode.cofrinho && goals.isNotEmpty) {
      return DropdownButton<String>(
        value: goals.any((g) => g.id == c.targetGoalId)
            ? c.targetGoalId
            : (selectedGoalId ?? goals.first.id),
        isExpanded: true,
        isDense: true,
        items: goals
            .map(
              (g) => DropdownMenuItem(
                value: g.id,
                child: Text(
                  'Caixinha: ${g.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          c.targetGoalId = v;
          onChanged();
        },
      );
    }

    if (targetMode == ImportTargetMode.transfer && accounts.isNotEmpty) {
      return DropdownButton<String>(
        value: accounts.any((a) => a.id == c.counterpartAccountId)
            ? c.counterpartAccountId
            : (selectedCounterpartAccountId ?? accounts.first.id),
        isExpanded: true,
        isDense: true,
        items: accounts
            .map(
              (a) => DropdownMenuItem(
                value: a.id,
                child: Text(
                  c.isOutgoingTransfer
                      ? 'Para Conta: ${a.name}'
                      : 'Vindo da Conta: ${a.name}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          c.counterpartAccountId = v;
          onChanged();
        },
      );
    }

    return DropdownButton<String>(
      value: c.suggestedCategoryId,
      isExpanded: true,
      isDense: true,
      items: categories
          .where((cat) => cat.type == c.type)
          .map(
            (cat) => DropdownMenuItem(
              value: cat.id,
              child: Text(
                cat.name,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        c.suggestedCategoryId = v;
        onChanged();
      },
    );
  }
}
