import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neves_app_icon.dart';

class SettingsTab extends StatelessWidget {
  final AppState appState;

  const SettingsTab({super.key, required this.appState});

  Future<void> _exportBackup(BuildContext context) async {
    HapticFeedback.lightImpact();
    final jsonStr = appState.exportBackupJson();
    final dateTag =
        DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
    final fileName = 'neves_backup_$dateTag.json';

    try {
      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              utf8.encode(jsonStr),
              name: fileName,
              mimeType: 'application/json',
            ),
          ],
          subject: 'Backup Neves Finanças',
        );
        return;
      }

      // Usa Directory.systemTemp nativo do Dart VM (não depende do canal path_provider)
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: 'Backup Neves Finanças',
      );
    } catch (_) {
      // Fallback garantido: copia o JSON para a Área de Transferência se o compartilhamento falhar
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup copiado para a Área de Transferência (JSON)!',
          ),
        ),
      );
    }
  }

  Future<void> _copyBackupToClipboard(BuildContext context) async {
    HapticFeedback.lightImpact();
    final jsonStr = appState.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup JSON copiado para a Área de Transferência!'),
      ),
    );
  }

  Future<void> _importBackup(BuildContext context) async {
    HapticFeedback.lightImpact();
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface(ctx).withValues(alpha: 0.94),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: AppColors.border(ctx),
                  width: AppSpacing.hairlineBorder,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(ctx)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const Text(
                    'Restaurar Backup',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha a origem do seu backup JSON para restaurar lançamentos, cartões e categorias',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.iosBlue,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(ctx).pop('file');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.folder_fill,
                            size: 17,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Selecionar Arquivo (.JSON)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.secondarySurface(ctx),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(ctx).pop('clipboard');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.doc_on_clipboard_fill,
                            size: 17,
                            color: AppColors.iosBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Colar JSON da Área de Transferência',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (mode == null || !context.mounted) return;

    try {
      String? content;
      if (mode == 'file') {
        const typeGroup = XTypeGroup(
          label: 'JSON',
          extensions: ['json', 'txt'],
        );
        final file = await openFile(acceptedTypeGroups: [typeGroup]);
        if (file == null) return;
        content = await file.readAsString();
      } else if (mode == 'clipboard') {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        content = data?.text;
        if (content == null || content.trim().isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A Área de Transferência está vazia.'),
            ),
          );
          return;
        }
      }

      if (content == null) return;
      await appState.importBackupJson(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo ou texto de backup inválido: $e')),
      );
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    HapticFeedback.lightImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Zerar todos os dados?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Todos os lançamentos serão apagados e os cartões e categorias voltarão para o padrão inicial. Esta ação não pode ser desfeita.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Sim, apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.resetAllData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados reiniciados com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      children: [
        // 1. Seção de Aparência (Light / OLED Dark Mode)
        _AppearanceSection(
          themeMode: appState.themeMode,
          onChanged: (mode) {
            HapticFeedback.lightImpact();
            appState.setThemeMode(mode);
          },
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 2. Resumo Local-First com Números Tabulares
        _DatabaseStatsCard(
          transactionsCount: appState.allTransactions.length,
          cardsCount: appState.cards.length,
          categoriesCount: appState.categories.length,
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 3. Seção de Dados & Backup (Inset Grouped)
        _BackupAndDataSection(
          onExportTap: () => _exportBackup(context),
          onCopyClipboardTap: () => _copyBackupToClipboard(context),
          onRestoreTap: () => _importBackup(context),
          onResetTap: () => _confirmReset(context),
        ),
        const SizedBox(height: 32),

        // 4. Rodapé Minimalista
        const _AboutFooter(),
      ],
    );
  }
}

/// 1. Bloco Agrupado de Aparência com `CupertinoSlidingSegmentedControl`
class _AppearanceSection extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  const _AppearanceSection({
    required this.themeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HigSectionHeader(title: 'Aparência'),
        HigGroupedCard(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const HigIconSquircle(
                  icon: CupertinoIcons.moon_stars_fill,
                  color: AppColors.iosIndigo,
                  size: 36,
                  iconSize: 18,
                  radius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema do Aplicativo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Suporte a Light Mode (#F2F2F7) e Dark Mode OLED (#000000)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CupertinoSlidingSegmentedControl<ThemeMode>(
              groupValue: themeMode,
              onValueChanged: (mode) {
                if (mode != null) onChanged(mode);
              },
              children: const {
                ThemeMode.system: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Sistema',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ThemeMode.light: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Claro',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ThemeMode.dark: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Escuro',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// 2. Card de Estatísticas do Cofre Local (SQLite) com `tabularFigures`
class _DatabaseStatsCard extends StatelessWidget {
  final int transactionsCount;
  final int cardsCount;
  final int categoriesCount;

  const _DatabaseStatsCard({
    required this.transactionsCount,
    required this.cardsCount,
    required this.categoriesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HigSectionHeader(title: 'Armazenamento Offline'),
        HigGroupedCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatMetricItem(
                    label: 'Lançamentos',
                    count: transactionsCount,
                    icon: CupertinoIcons.doc_text_fill,
                    color: AppColors.iosBlue,
                  ),
                ),
                Container(
                  width: AppSpacing.hairlineBorder,
                  height: 36,
                  color: AppColors.border(context),
                ),
                Expanded(
                  child: _StatMetricItem(
                    label: 'Cartões',
                    count: cardsCount,
                    icon: CupertinoIcons.creditcard_fill,
                    color: AppColors.iosIndigo,
                  ),
                ),
                Container(
                  width: AppSpacing.hairlineBorder,
                  height: 36,
                  color: AppColors.border(context),
                ),
                Expanded(
                  child: _StatMetricItem(
                    label: 'Categorias',
                    count: categoriesCount,
                    icon: CupertinoIcons.square_grid_2x2_fill,
                    color: AppColors.iosGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StatMetricItem extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatMetricItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HigIconSquircle(
          icon: icon,
          color: color,
          size: 30,
          iconSize: 15,
          radius: 8,
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary(context),
            fontFeatures: AppTypography.tabular,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

/// 3. Seção de Dados & Backup Estilo `CupertinoListSection.insetGrouped`
class _BackupAndDataSection extends StatelessWidget {
  final VoidCallback onExportTap;
  final VoidCallback onCopyClipboardTap;
  final VoidCallback onRestoreTap;
  final VoidCallback onResetTap;

  const _BackupAndDataSection({
    required this.onExportTap,
    required this.onCopyClipboardTap,
    required this.onRestoreTap,
    required this.onResetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HigSectionHeader(title: 'Dados & Backup'),
        HigGroupedCard(
          children: [
            _SettingsActionRow(
              icon: CupertinoIcons.share,
              iconColor: AppColors.iosGreen,
              title: 'Exportar Backup (JSON)',
              subtitle: 'Compartilhar arquivo .json ou salvar no aparelho',
              onTap: onExportTap,
              trailing: Tooltip(
                message: 'Copiar JSON',
                child: GestureDetector(
                  onTap: onCopyClipboardTap,
                  behavior: HitTestBehavior.opaque,
                  child: const HigIconSquircle(
                    icon: CupertinoIcons.doc_on_doc,
                    color: AppColors.iosBlue,
                    size: 34,
                    iconSize: 16,
                    radius: 9,
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: AppSpacing.hairlineBorder,
              indent: 62,
              color: AppColors.border(context),
            ),
            _SettingsActionRow(
              icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
              iconColor: AppColors.iosBlue,
              title: 'Restaurar Backup (JSON)',
              subtitle:
                  'Importar de arquivo .json ou colar da área de transferência',
              onTap: onRestoreTap,
            ),
            Divider(
              height: 1,
              thickness: AppSpacing.hairlineBorder,
              indent: 62,
              color: AppColors.border(context),
            ),
            _SettingsActionRow(
              icon: CupertinoIcons.trash_fill,
              iconColor: AppColors.iosRed,
              title: 'Apagar Todos os Dados',
              titleColor: AppColors.danger(context),
              subtitle: 'Voltar o aplicativo para o estado inicial limpo',
              onTap: onResetTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            HigIconSquircle(
              icon: icon,
              color: iconColor,
              size: 36,
              iconSize: 18,
              radius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: titleColor ?? AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color:
                      AppColors.textSecondary(context).withValues(alpha: 0.6),
                ),
          ],
        ),
      ),
    );
  }
}

/// 4. Rodapé Minimalista com Versão Tabular
class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const NevesAppIcon(size: 48),
          const SizedBox(height: 8),
          Text(
            'Neves Finanças • MVP v2.1',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              fontFeatures: AppTypography.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Controle mensal enxuto e 100% offline',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
