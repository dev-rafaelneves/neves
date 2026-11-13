import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/month_selector_bar.dart';
import '../statement_import_screen.dart';
import 'dashboard/dashboard_accounts_section.dart';
import 'dashboard/dashboard_cards_section.dart';
import 'dashboard/dashboard_modals.dart';
import 'dashboard/dashboard_overview_section.dart';

class DashboardTab extends StatefulWidget {
  final AppState appState;

  /// Chamado ao pedir o extrato filtrado de um cartão (aba Cartões).
  final ValueChanged<CreditCardModel>? onOpenCardStatement;

  /// Chamado ao tocar em uma categoria no gráfico/lista para filtrar Lançamentos.
  final ValueChanged<CategoryModel>? onOpenCategoryStatement;

  const DashboardTab({
    super.key,
    required this.appState,
    this.onOpenCardStatement,
    this.onOpenCategoryStatement,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  int _selectedSegment = 0; // 0: Visão Geral, 1: Contas, 2: Cartões
  bool _showAllCategories = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = widget.appState;
    final now = DateTime.now();
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(now);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 74,
          backgroundColor: isDark
              ? AppColors.darkBackground.withValues(alpha: 0.92)
              : AppColors.lightBackground.withValues(alpha: 0.92),
          centerTitle: false,
          titleSpacing: 20,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatementImportScreen(appState: state),
                    ),
                  );
                },
                tooltip: 'Importar Extrato OFX/CSV/PDF',
                icon: const Icon(Icons.upload_file_rounded, size: 22),
              ),
              IconButton(
                key: const ValueKey('btn_discreet_mode'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  state.toggleDiscreetMode();
                },
                tooltip: state.discreetMode
                    ? 'Mostrar Valores'
                    : 'Modo Discreto (Ocultar Valores)',
                icon: Icon(
                  state.discreetMode
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 22,
                  color: state.discreetMode
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 840;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 960 : 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Seletor de Mês + Regime Badge
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MonthSelectorBar(appState: state),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  state.budgetRegime == BudgetRegime.competence
                                      ? 'Por Fatura'
                                      : 'Por Data da Compra',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Segmented Control estilo iOS HIG
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<int>(
                                groupValue: _selectedSegment,
                                children: const {
                                  0: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Visão Geral',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  1: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Contas',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  2: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Cartões',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                },
                                onValueChanged: (v) {
                                  if (v != null) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedSegment = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey(_selectedSegment),
                            child: _buildSegmentBody(context, isWide),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBody(BuildContext context, bool isWide) {
    final state = widget.appState;
    switch (_selectedSegment) {
      case 0:
        return DashboardOverviewSection(
          appState: state,
          isWide: isWide,
          showAllCategories: _showAllCategories,
          onToggleShowAllCategories: () =>
              setState(() => _showAllCategories = !_showAllCategories),
          onOpenCategoryStatement: widget.onOpenCategoryStatement,
        );
      case 1:
        return DashboardAccountsSection(
          appState: state,
          isWide: isWide,
          onCreateAccount: () => showAccountModal(
            context: context,
            appState: state,
            onSaved: () {
              if (mounted) setState(() {});
            },
          ),
          onEditAccount: (acc) => showAccountModal(
            context: context,
            appState: state,
            existing: acc,
            onSaved: () {
              if (mounted) setState(() {});
            },
          ),
        );
      default:
        return DashboardCardsSection(
          appState: state,
          isWide: isWide,
          onCreateCard: () => showCardModal(
            context: context,
            appState: state,
            onSaved: () {
              if (mounted) setState(() {});
            },
          ),
          onEditCard: (card) => showCardModal(
            context: context,
            appState: state,
            existing: card,
            onSaved: () {
              if (mounted) setState(() {});
            },
          ),
          onPayInvoice: (card) => showPayInvoiceDialog(
            context: context,
            appState: state,
            card: card,
          ),
          onOpenCardStatement: widget.onOpenCardStatement,
        );
    }
  }
}
