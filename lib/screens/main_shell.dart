import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_lock_gate.dart';
import 'main_shell/bottom_nav_item.dart';
import 'main_shell/dashboard_tab.dart';
import 'main_shell/planning_tab.dart';
import 'main_shell/settings_tab.dart';
import 'main_shell/transactions_tab.dart';
import 'transaction_form_sheet.dart';

class MainShell extends StatefulWidget {
  final AppState appState;

  const MainShell({
    super.key,
    required this.appState,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String? _cardFilterId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppLockGate(
      appState: widget.appState,
      child: Scaffold(
        extendBody: true,
        floatingActionButton: _selectedIndex < 3
            ? FloatingActionButton.extended(
                key: const ValueKey('fab_new_transaction'),
                onPressed: () => TransactionFormSheet.show(
                  context,
                  appState: widget.appState,
                ),
                backgroundColor: AppColors.indigoPrimary,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Lançar',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              )
            : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardTab(
              appState: widget.appState,
              onOpenCardStatement: (card) => setState(() {
                _cardFilterId = card.id;
                _selectedIndex = 1;
              }),
            ),
            TransactionsTab(
              appState: widget.appState,
              cardFilterId: _cardFilterId,
              onClearCardFilter: () => setState(() => _cardFilterId = null),
            ),
            PlanningTab(appState: widget.appState),
            SettingsTab(appState: widget.appState),
          ],
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 83,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        BottomNavItem(
                          icon: Icons.pie_chart_outline_rounded,
                          activeIcon: Icons.pie_chart_rounded,
                          label: 'Resumo',
                          isSelected: _selectedIndex == 0,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = 0);
                          },
                        ),
                        BottomNavItem(
                          icon: Icons.receipt_long_outlined,
                          activeIcon: Icons.receipt_long_rounded,
                          label: 'Extrato',
                          isSelected: _selectedIndex == 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = 1);
                          },
                        ),
                        BottomNavItem(
                          icon: Icons.track_changes_outlined,
                          activeIcon: Icons.track_changes_rounded,
                          label: 'Planejamento',
                          isSelected: _selectedIndex == 2,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = 2);
                          },
                        ),
                        BottomNavItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings_rounded,
                          label: 'Ajustes',
                          isSelected: _selectedIndex == 3,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = 3);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
