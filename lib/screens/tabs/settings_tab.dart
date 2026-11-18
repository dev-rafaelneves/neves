import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neves_app_icon.dart';

class SettingsTab extends StatelessWidget {
  final AppState appState;

  const SettingsTab({super.key, required this.appState});

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final jsonStr = appState.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final dateTag =
          DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
      final file = File('${dir.path}/neves_backup_$dateTag.json');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Backup Neves Finanças',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar backup: $e')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final content = await file.readAsString();
      await appState.importBackupJson(content);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo de backup inválido: $e')),
      );
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zerar todos os dados?'),
        content: const Text(
          'Todos os lançamentos serão apagados e os cartões e categorias voltarão para o padrão inicial. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.of(ctx).pop(true),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const HigSectionHeader(title: 'Aparência'),
        HigGroupedCard(
          padding: const EdgeInsets.all(14),
          children: [
            CupertinoSlidingSegmentedControl<ThemeMode>(
              groupValue: appState.themeMode,
              onValueChanged: (mode) {
                if (mode != null) {
                  HapticFeedback.selectionClick();
                  appState.setThemeMode(mode);
                }
              },
              children: const {
                ThemeMode.system: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sistema'),
                ),
                ThemeMode.light: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Claro'),
                ),
                ThemeMode.dark: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Escuro'),
                ),
              },
            ),
          ],
        ),
        const SizedBox(height: 22),

        const HigSectionHeader(title: 'Dados & Backup'),
        HigGroupedCard(
          children: [
            ListTile(
              onTap: () => _exportBackup(context),
              leading: const Icon(
                Icons.ios_share_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Exportar Backup (JSON)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Salve seus dados para trocar de aparelho',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              onTap: () => _importBackup(context),
              leading: const Icon(
                Icons.restore_page_rounded,
                color: AppColors.blue,
              ),
              title: const Text(
                'Restaurar Backup (JSON)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Importar arquivo salvo anteriormente',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              onTap: () => _confirmReset(context),
              leading: Icon(
                Icons.delete_forever_rounded,
                color: AppColors.danger(context),
              ),
              title: Text(
                'Apagar Todos os Dados',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger(context),
                ),
              ),
              subtitle: const Text(
                'Voltar o aplicativo para o estado inicial limpo',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        Center(
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
                ),
              ),
              Text(
                'Controle mensal enxuto e 100% offline',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
