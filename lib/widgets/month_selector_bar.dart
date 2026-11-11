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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              appState.changeMonth(-1);
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_left_rounded, size: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _formatYearMonth(appState.selectedYearMonth),
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
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticFeedback.selectionClick();
              appState.changeMonth(1);
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
