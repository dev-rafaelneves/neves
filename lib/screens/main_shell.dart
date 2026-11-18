import 'package:flutter/cupertino.dart';
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
      extendBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior translúcida com vidro fosco (Frosted Glass Apple HIG)
          HigFrostedSurface(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border(context),
                width: AppSpacing.hairlineBorder,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Linha 1: Ícone + Large Title expressivo
                    Row(
                      children: [
                        const NevesAppIcon(size: 26),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Neves Finanças',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Linha 2: Seletor de Mês esticado da esquerda até encostar nos ícones à direita
                    Row(
                      children: [
                        Expanded(
                          child: MonthSelectorBar(appState: appState),
                        ),
                        const SizedBox(width: 8),
                        _HeaderActionButton(
                          tooltip: 'Importar Extrato / Fatura',
                          icon: CupertinoIcons.tray_arrow_down,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            UnifiedImportScreen.open(
                              context,
                              appState: appState,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _HeaderActionButton(
                          tooltip: appState.discreetMode
                              ? 'Mostrar valores'
                              : 'Ocultar valores',
                          icon: appState.discreetMode
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.eye,
                          isActive: appState.discreetMode,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            appState.toggleDiscreetMode();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo da aba ativa com transição suave
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: activeTabBody,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo Lançamento',
        backgroundColor: AppColors.iosBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          TransactionFormSheet.show(
            context,
            appState: appState,
          );
        },
        child: const Icon(CupertinoIcons.add, size: 26),
      ),
      bottomNavigationBar: HigFrostedSurface(
        border: Border(
          top: BorderSide(
            color: AppColors.border(context),
            width: AppSpacing.hairlineBorder,
          ),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: tabIdx,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: AppColors.iosBlue.withValues(alpha: 0.12),
          onDestinationSelected: (idx) {
            HapticFeedback.lightImpact();
            appState.setActiveTab(idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(CupertinoIcons.chart_pie, size: 21),
              selectedIcon: Icon(
                CupertinoIcons.chart_pie_fill,
                size: 21,
                color: AppColors.iosBlue,
              ),
              label: 'Resumo',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.doc_text, size: 21),
              selectedIcon: Icon(
                CupertinoIcons.doc_text_fill,
                size: 21,
                color: AppColors.iosBlue,
              ),
              label: 'Extrato',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.creditcard, size: 21),
              selectedIcon: Icon(
                CupertinoIcons.creditcard_fill,
                size: 21,
                color: AppColors.iosBlue,
              ),
              label: 'Cartões',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.square_grid_2x2, size: 21),
              selectedIcon: Icon(
                CupertinoIcons.square_grid_2x2_fill,
                size: 21,
                color: AppColors.iosBlue,
              ),
              label: 'Categorias',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.slider_horizontal_3, size: 21),
              selectedIcon: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 21,
                color: AppColors.iosBlue,
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
    final activeColor = AppColors.iosBlue;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.12)
                  : AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? activeColor : AppColors.border(context),
                width: AppSpacing.hairlineBorder,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: isActive ? activeColor : AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}
