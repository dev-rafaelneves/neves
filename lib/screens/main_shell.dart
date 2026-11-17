import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/month_selector_bar.dart';
import '../widgets/neves_app_icon.dart';
import 'tabs/cards_settings_tab.dart';
import 'tabs/summary_tab.dart';
import 'tabs/transactions_tab.dart';
import 'transaction_form_sheet.dart';
import 'unified_import_screen.dart';

class MainShell extends StatelessWidget {
  final AppState appState;

  const MainShell({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final tabIdx = appState.activeTabIndex;

    final Widget body;
    switch (tabIdx) {
      case 1:
        body = TransactionsTab(appState: appState);
        break;
      case 2:
        body = CardsSettingsTab(appState: appState);
        break;
      case 0:
      default:
        body = SummaryTab(appState: appState);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 14,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NevesAppIcon(size: 32),
                const SizedBox(width: 8),
                Text(
                  'Neves',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            MonthSelectorBar(appState: appState),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Importar Extrato / Fatura',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => UnifiedImportScreen.open(
                    context,
                    appState: appState,
                  ),
                  icon: Icon(
                    Icons.upload_file_rounded,
                    size: 21,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                IconButton(
                  tooltip: appState.discreetMode
                      ? 'Mostrar valores'
                      : 'Ocultar valores',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    appState.toggleDiscreetMode();
                  },
                  icon: Icon(
                    appState.discreetMode
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 21,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo Lançamento',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => TransactionFormSheet.show(
          context,
          appState: appState,
        ),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border(
            top: BorderSide(
              color: AppColors.border(context),
              width: 0.8,
            ),
          ),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: tabIdx,
          indicatorColor: AppColors.primary.withValues(alpha: 0.14),
          onDestinationSelected: (idx) {
            HapticFeedback.selectionClick();
            appState.setActiveTab(idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(
                Icons.pie_chart_rounded,
                color: AppColors.primary,
              ),
              label: 'Resumo',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              label: 'Extrato',
            ),
            NavigationDestination(
              icon: Icon(Icons.credit_card_outlined),
              selectedIcon: Icon(
                Icons.credit_card_rounded,
                color: AppColors.primary,
              ),
              label: 'Cartões & Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
