import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/month_selector_bar.dart';
import '../widgets/neves_app_icon.dart';
import 'tabs/cards_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/settings_tab.dart';
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
        body = CardsTab(appState: appState);
        break;
      case 3:
        body = CategoriesTab(appState: appState);
        break;
      case 4:
        body = SettingsTab(appState: appState);
        break;
      case 0:
      default:
        body = SummaryTab(appState: appState);
        break;
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(98),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.isDark(context)
                ? AppColors.darkBackground
                : AppColors.lightBackground,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha 1: Ícone + Nome do App
                  Row(
                    children: [
                      const NevesAppIcon(size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Neves Finanças',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Linha 2: Seletor de Mês à esquerda | Importar + Olhinho à direita
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: MonthSelectorBar(appState: appState),
                      ),
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
                ],
              ),
            ),
          ),
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
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: AppColors.primary.withValues(alpha: 0.14),
          onDestinationSelected: (idx) {
            HapticFeedback.selectionClick();
            appState.setActiveTab(idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded, size: 22),
              selectedIcon: Icon(
                Icons.pie_chart_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              label: 'Resumo',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 22),
              selectedIcon: Icon(
                Icons.receipt_long_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              label: 'Extrato',
            ),
            NavigationDestination(
              icon: Icon(Icons.credit_card_outlined, size: 22),
              selectedIcon: Icon(
                Icons.credit_card_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              label: 'Cartões',
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined, size: 22),
              selectedIcon: Icon(
                Icons.category_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              label: 'Categorias',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, size: 22),
              selectedIcon: Icon(
                Icons.settings_rounded,
                size: 22,
                color: AppColors.primary,
              ),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
