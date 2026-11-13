import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

enum _RestoreChoice { merge, overwrite }

class DataBackupManager extends StatefulWidget {
  final AppState appState;

  const DataBackupManager({
    super.key,
    required this.appState,
  });

  @override
  State<DataBackupManager> createState() => _DataBackupManagerState();
}

class _DataBackupManagerState extends State<DataBackupManager> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _messageText;
  bool _isSuccess = true;

  Future<void> _handleExportData() async {
    setState(() {
      _isExporting = true;
      _messageText = null;
    });

    try {
      final backupData = widget.appState.exportBackupJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename = 'backup-neves-$dateStr.json';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Backup Neves Finanças ($dateStr)',
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _messageText = 'Backup exportado com sucesso!';
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messageText = 'Falha ao exportar os dados.';
        _isSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleSaveToDocuments() async {
    setState(() {
      _isExporting = true;
      _messageText = null;
    });
    try {
      final res =
          await BackupService.instance.generateLocalBackup(widget.appState);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _messageText = res.success
            ? 'Backup salvo em Documentos/backups!'
            : (res.message ?? 'Falha ao salvar backup.');
        _isSuccess = res.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messageText = 'Erro ao salvar backup: $e';
        _isSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<_RestoreChoice?> _confirmRestoreModal(
    BuildContext context,
    BackupPreviewInfo preview,
  ) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final dateLabel = preview.timestamp != null
        ? 'Gerado em ${dateFmt.format(preview.timestamp!.toLocal())}\n'
        : '';

    return showCupertinoModalPopup<_RestoreChoice>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Restaurar Backup Financeiro'),
        message: Text(
          '${dateLabel}O arquivo contém ${preview.accountsCount} contas, '
          '${preview.cardsCount} cartões, ${preview.transactionsCount} transações e '
          '${preview.goalsCount} metas.\n\n'
          'Como deseja restaurar estes dados?',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(_RestoreChoice.merge),
            child: const Text('Mesclar com Dados Atuais'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(_RestoreChoice.overwrite),
            child: const Text('Substituir Todos os Dados Atuais'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _handleImportData() async {
    setState(() {
      _isImporting = true;
      _messageText = null;
    });

    try {
      const typeGroup = XTypeGroup(
        label: 'JSON Backup',
        extensions: ['json'],
        mimeTypes: ['application/json', 'text/json', 'text/plain'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final jsonContent = await file.readAsString();
      final parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
      final preview = widget.appState.inspectBackupJson(parsed);

      if (!mounted) return;
      final choice = await _confirmRestoreModal(context, preview);
      if (choice == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      await widget.appState.importBackupJson(
        parsed,
        merge: choice == _RestoreChoice.merge,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _messageText = choice == _RestoreChoice.merge
            ? 'Dados mesclados com sucesso!'
            : 'Dados restaurados com sucesso!';
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messageText = 'Arquivo de backup inválido ou corrompido.';
        _isSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & Restauração (100% Local)',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Exporte seus lançamentos, cartões, metas e orçamentos em JSON ou restaure um backup anterior.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: (_isExporting || _isImporting)
                ? null
                : _handleSaveToDocuments,
            leading: const Icon(
              Icons.folder_zip_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            title: const Text(
              'Salvar Backup em Documentos',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(indent: 16, height: 1),
          ListTile(
            onTap: (_isExporting || _isImporting) ? null : _handleExportData,
            leading: const Icon(
              Icons.ios_share_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            title: const Text(
              'Exportar / Compartilhar Arquivo JSON',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(indent: 16, height: 1),
          ListTile(
            onTap: (_isExporting || _isImporting) ? null : _handleImportData,
            leading: const Icon(
              Icons.restore_page_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            title: const Text(
              'Restaurar Backup (JSON)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          if (_messageText != null) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: (_isSuccess ? AppColors.emerald : AppColors.rose)
                  .withValues(alpha: 0.12),
              child: Text(
                _messageText!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isSuccess ? AppColors.emerald : AppColors.rose,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
