import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class MonthSelectorBar extends StatelessWidget {
  final AppState appState;

  const MonthSelectorBar({super.key, required this.appState});

  String _formatYearMonth(String ym) {
    final parts = ym.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final dt = DateTime(y, m, 1);
    final raw = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(dt);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Future<void> _showMonthPicker(BuildContext context) async {
    HapticFeedback.selectionClick();
    final parts = appState.selectedYearMonth.split('-');
    int pickerYear = int.parse(parts[0]);
    final selectedYear = int.parse(parts[0]);
    final selectedMonth = int.parse(parts[1]);
    final now = DateTime.now();
    final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Ano anterior',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => pickerYear--);
                          },
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '$pickerYear',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Próximo ano',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => pickerYear++);
                          },
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.1,
                      ),
                      itemBuilder: (context, idx) {
                        final month = idx + 1;
                        final labelRaw = DateFormat('MMM', 'pt_BR')
                            .format(DateTime(pickerYear, month, 1));
                        final label = labelRaw[0].toUpperCase() +
                            labelRaw.substring(1).replaceAll('.', '');
                        final isSelected =
                            pickerYear == selectedYear && month == selectedMonth;
                        final isToday =
                            pickerYear == now.year && month == now.month;

                        return Material(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBackground
                                  : const Color(0xFFF1F5F9)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isToday && !isSelected
                                ? const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.2,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final ym =
                                  '$pickerYear-${month.toString().padLeft(2, '0')}';
                              appState.setSelectedYearMonth(ym);
                              Navigator.of(ctx).pop();
                            },
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (appState.selectedYearMonth != currentYm) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            appState.setSelectedYearMonth(currentYm);
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.today_rounded, size: 18),
                          label: const Text(
                            'Ir para o mês atual',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedMonth = _formatYearMonth(appState.selectedYearMonth);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Mês anterior',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticFeedback.selectionClick();
                appState.changeMonth(-1);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: const Center(
                  child: Icon(Icons.chevron_left_rounded, size: 22),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Mês selecionado: $formattedMonth. Toque para escolher',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showMonthPicker(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: Text(
                      formattedMonth,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Próximo mês',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticFeedback.selectionClick();
                appState.changeMonth(1);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: const Center(
                  child: Icon(Icons.chevron_right_rounded, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
