import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class MonthSelectorBar extends StatelessWidget {
  final AppState appState;

  const MonthSelectorBar({super.key, required this.appState});

  Future<void> _showMonthPicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    final parts = appState.selectedYearMonth.split('-');
    int pickerYear = int.parse(parts[0]);
    final selectedYear = int.parse(parts[0]);
    final selectedMonth = int.parse(parts[1]);
    final now = DateTime.now();
    final currentYm = AppFormatters.yearMonthFromDate(now);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary(context)
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Tooltip(
                                message: 'Ano anterior',
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setModalState(() => pickerYear--);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: const HigIconSquircle(
                                    icon: CupertinoIcons.chevron_left,
                                    color: AppColors.iosBlue,
                                    size: 36,
                                    iconSize: 17,
                                    radius: 10,
                                  ),
                                ),
                              ),
                              Text(
                                '$pickerYear',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: AppColors.textPrimary(context),
                                  fontFeatures: AppTypography.tabular,
                                ),
                              ),
                              Tooltip(
                                message: 'Próximo ano',
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setModalState(() => pickerYear++);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: const HigIconSquircle(
                                    icon: CupertinoIcons.chevron_right,
                                    color: AppColors.iosBlue,
                                    size: 36,
                                    iconSize: 17,
                                    radius: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                              final isSelected = pickerYear == selectedYear &&
                                  month == selectedMonth;
                              final isToday =
                                  pickerYear == now.year && month == now.month;

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  final ym =
                                      '$pickerYear-${month.toString().padLeft(2, '0')}';
                                  appState.setSelectedYearMonth(ym);
                                  Navigator.of(ctx).pop();
                                },
                                behavior: HitTestBehavior.opaque,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.iosBlue
                                        : AppColors.secondarySurface(context),
                                    borderRadius: BorderRadius.circular(11),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: AppColors.iosBlue,
                                            width: 1.2,
                                          )
                                        : Border.all(
                                            color: AppColors.border(context),
                                            width: AppSpacing.hairlineBorder,
                                          ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (appState.selectedYearMonth != currentYm) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                color:
                                    AppColors.iosBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(13),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  appState.setSelectedYearMonth(currentYm);
                                  Navigator.of(ctx).pop();
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.calendar_today,
                                      size: 17,
                                      color: AppColors.iosBlue,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ir para o mês atual',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.iosBlue,
                                      ),
                                    ),
                                  ],
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
    final formattedMonth = AppFormatters.monthLabel(appState.selectedYearMonth);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: AppSpacing.hairlineBorder,
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Mês anterior',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                appState.changeMonth(-1);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  CupertinoIcons.chevron_left,
                  size: 17,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Mês selecionado: $formattedMonth. Toque para escolher',
              child: GestureDetector(
                onTap: () => _showMonthPicker(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        formattedMonth,
                        key: ValueKey<String>(appState.selectedYearMonth),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary(context),
                          fontFeatures: AppTypography.tabular,
                        ),
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
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                appState.changeMonth(1);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 17,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
