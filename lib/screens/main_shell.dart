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

    final Widget activeTabBody;
    switch (tabIdx) {
      case 1:
        activeTabBody = TransactionsTab(
          key: const ValueKey<int>(1),
          appState: appState,
        );
        break;
      case 2:
        activeTabBody = CardsTab(
          key: const ValueKey<int>(2),
          appState: appState,
        );
        break;
      case 3:
        activeTabBody = CategoriesTab(
          key: const ValueKey<int>(3),
          appState: appState,
        );
        break;
      case 4:
        activeTabBody = SettingsTab(
          key: const ValueKey<int>(4),
          appState: appState,
        );
        break;
      case 0:
      default:
        activeTabBody = SummaryTab(
          key: const ValueKey<int>(0),
          appState: appState,
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho em 2 linhas elástico (à prova de overflow em qualquer TextScaler)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha 1: Ícone + Marca
                  Row(
                    children: [
                      const NevesAppIcon(size: 28),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Neves Finanças',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Linha 2: Seletor de Mês à esquerda | Ações táteis (44x44dp) à direita
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: MonthSelectorBar(appState: appState),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderActionButton(
                            tooltip: 'Importar Extrato / Fatura',
                            icon: Icons.upload_file_rounded,
                            onTap: () => UnifiedImportScreen.open(
                              context,
                              appState: appState,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderActionButton(
                            tooltip: appState.discreetMode
                                ? 'Mostrar valores'
                                : 'Ocultar valores',
                            icon: appState.discreetMode
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            isActive: appState.discreetMode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              appState.toggleDiscreetMode();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Conteúdo da aba ativa com transição suave
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: activeTabBody,
              ),
            ),
          ],
        ),
      ),
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

class _HeaderActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive ? AppColors.primary : AppColors.border(context),
              width: 0.8,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Icon(
                icon,
                size: 20,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
