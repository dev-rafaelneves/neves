import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_lock_gate.dart';
import '../../widgets/data_backup_manager.dart';
import '../../widgets/gemini_config_card.dart';

class SettingsTab extends StatefulWidget {
  final AppState appState;

  const SettingsTab({super.key, required this.appState});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const _uuid = Uuid();

  Future<void> _showNewCategoryDialog() async {
    final nameCtrl = TextEditingController();
    TransactionType type = TransactionType.expense;
    Pillar503020 pillar = Pillar503020.essential;
    int colorVal = 0xFF059669;
    final colors = [
      0xFF059669,
      0xFF10B981,
      0xFFF97316,
      0xFFF43F5E,
      0xFF0D9488,
      0xFF06B6D4,
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Nova Categoria (50/30/20)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const HigSectionHeader(title: 'Configuração da Categoria'),
                  HigGroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(colorVal).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.category_rounded,
                                color: Color(colorVal),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Nome (ex: Pet Shop, Terapia, Freelance...)',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.swap_vert_rounded,
                        iconColor: AppColors.indigoPrimary,
                        label: 'Natureza',
                        trailing: CupertinoSlidingSegmentedControl<
                            TransactionType>(
                          groupValue: type,
                          children: const {
                            TransactionType.expense: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Despesa',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TransactionType.income: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Receita',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          },
                          onValueChanged: (v) {
                            if (v != null) setModalState(() => type = v);
                          },
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.pie_chart_outline_rounded,
                        iconColor: AppColors.emerald,
                        label: 'Pilar 50/30/20',
                        trailing: DropdownButton<Pillar503020>(
                          value: pillar,
                          underline: const SizedBox.shrink(),
                          items: Pillar503020.values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.label,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.indigoPrimary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => pillar = v);
                          },
                        ),
                      ),
                      const Divider(indent: 62, height: 1),
                      HigFormRow(
                        icon: Icons.palette_outlined,
                        iconColor: Color(colorVal),
                        label: 'Cor do Ícone',
                        trailing: Wrap(
                          spacing: 8,
                          children: colors.map((c) {
                            final selected = colorVal == c;
                            return GestureDetector(
                              onTap: () => setModalState(() => colorVal = c),
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor: Color(c),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        await widget.appState.saveCategory(
                          CategoryModel(
                            id: _uuid.v4(),
                            name: name,
                            type: type,
                            pillar: pillar,
                            colorValue: colorVal,
                            iconName: 'shopping_bag',
                          ),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigoPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text(
                        'Criar Categoria',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
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
    final state = widget.appState;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: isDark
              ? AppColors.darkBackground.withValues(alpha: 0.9)
              : AppColors.lightBackground.withValues(alpha: 0.9),
          centerTitle: false,
          titleSpacing: 20,
          title: Text(
            'Ajustes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.6,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  state.toggleTheme();
                },
                tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
                icon: Icon(
                  isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: isDark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Regime de Contabilização do Orçamento (Competência vs Data da Compra)
                    Material(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Regime do Orçamento & Cartões',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Escolha como as compras e parcelas no cartão de crédito impactam os gráficos e o teto de gastos de cada mês:',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<
                                  BudgetRegime>(
                                groupValue: state.budgetRegime,
                                children: const {
                                  BudgetRegime.competence: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Competência da Fatura',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  BudgetRegime.purchaseDate: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Data da Compra',
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
                                    state.setBudgetRegime(v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Categorias 50/30/20
                    Material(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: ListTile(
                        onTap: _showNewCategoryDialog,
                        leading: const Icon(
                          Icons.category_rounded,
                          color: AppColors.indigoPrimary,
                        ),
                        title: const Text(
                          'Criar Nova Categoria (50/30/20)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                          ),
                        ),
                        subtitle: Text(
                          '${state.categories.length} categorias ativas no sistema',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Privacidade e Segurança (espelhado do BioStats)
                    Material(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Privacidade e Segurança',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            value: state.discreetMode,
                            onChanged: (_) {
                              HapticFeedback.selectionClick();
                              state.toggleDiscreetMode();
                            },
                            activeTrackColor: AppColors.indigoPrimary,
                            secondary: const Icon(
                              Icons.visibility_off_outlined,
                              color: AppColors.indigoPrimary,
                              size: 20,
                            ),
                            title: const Text(
                              'Modo Discreto ("Olhinho")',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: const Text(
                              'Oculta saldos e valores monetários em público',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(indent: 16, height: 1),
                          ListTile(
                            onTap: () => AppLockGate.showConfigurePinDialog(
                              context,
                              state,
                            ),
                            leading: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.indigoPrimary,
                              size: 20,
                            ),
                            title: const Text(
                              'Bloqueio por PIN (4 Dígitos)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              state.hasPinLock
                                  ? 'Ativado • Protege o app ao abrir e no multitarefas'
                                  : 'Desativado • Toque para configurar uma senha',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                          const Divider(indent: 16, height: 1),
                          SwitchListTile.adaptive(
                            value: state.hasPinLock && state.useBiometrics,
                            onChanged: state.hasPinLock
                                ? (_) {
                                    HapticFeedback.selectionClick();
                                    state.toggleBiometrics();
                                  }
                                : null,
                            activeTrackColor: AppColors.indigoPrimary,
                            secondary: const Icon(
                              Icons.fingerprint_rounded,
                              color: AppColors.indigoPrimary,
                              size: 20,
                            ),
                            title: const Text(
                              'Desbloqueio por Biometria',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: const Text(
                              'Impressão digital ou FaceID ao abrir o app',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(indent: 16, height: 1),
                          SwitchListTile.adaptive(
                            value: state.blockScreenshots,
                            onChanged: (_) {
                              HapticFeedback.selectionClick();
                              state.toggleBlockScreenshots();
                            },
                            activeTrackColor: AppColors.indigoPrimary,
                            secondary: const Icon(
                              Icons.security_rounded,
                              color: AppColors.indigoPrimary,
                              size: 20,
                            ),
                            title: const Text(
                              'Ocultar em recentes e bloquear prints',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: const Text(
                              'Proteção FLAG_SECURE contra capturas de tela',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4. Lembretes de Vencimento
                    Material(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: SwitchListTile.adaptive(
                        value: state.dailyBillsReminderEnabled,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          state.updateDailyBillsReminder(enabled: v);
                        },
                        activeTrackColor: AppColors.indigoPrimary,
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.indigoPrimary,
                          size: 20,
                        ),
                        title: const Text(
                          'Lembrete Diário de Vencimentos & Faturas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Avisa sobre contas pendentes e limites em 80% / 100%',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 5. Google Gemini IA (BYOK)
                    GeminiConfigCard(appState: state),
                    const SizedBox(height: 18),

                    // 6. Backup & Restauração JSON
                    DataBackupManager(appState: state),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
