import 'dart:convert';
import 'dart:io';
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
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Restaurar Backup',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop('file'),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Selecionar Arquivo (.JSON)'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('clipboard'),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Colar JSON da Área de Transferência'),
              ),
            ],
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
                'Compartilhar arquivo .json ou salvar no aparelho',
                style: TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: 'Copiar JSON',
                onPressed: () => _copyBackupToClipboard(context),
                icon: const Icon(Icons.copy_rounded, size: 19),
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
                'Importar de arquivo .json ou colar da área de transferência',
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
