import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import 'app_state.dart';

class BackupResult {
  final bool success;
  final String? filePath;
  final String? message;

  const BackupResult({
    required this.success,
    this.filePath,
    this.message,
  });
}

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const String _keyLastAutoBackup = 'neves_last_auto_backup_timestamp';

  static bool get isTestEnvironment {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<BackupResult> generateLocalBackup(AppState appState) async {
    if (isTestEnvironment) {
      return const BackupResult(
        success: true,
        filePath: '/mock/neves_backup.json',
        message: 'Backup simulado em ambiente de teste.',
      );
    }

    try {
      final backupData = appState.exportBackupJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);

      final docsDir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory('${docsDir.path}/backups');
      if (!backupFolder.existsSync()) {
        backupFolder.createSync(recursive: true);
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${backupFolder.path}/neves_backup_$dateStr.json');
      await file.writeAsString(jsonStr, flush: true);

      return BackupResult(
        success: true,
        filePath: file.path,
        message: 'Backup gerado com sucesso!',
      );
    } catch (e) {
      debugPrint('Erro ao gerar backup local: $e');
      return BackupResult(
        success: false,
        message: 'Falha ao salvar arquivo de backup: $e',
      );
    }
  }

  Future<bool> shareBackup(AppState appState) async {
    if (isTestEnvironment) return true;

    try {
      final res = await generateLocalBackup(appState);
      if (!res.success || res.filePath == null) return false;

      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final xFile = XFile(
        res.filePath!,
        mimeType: 'application/json',
        name: 'neves_backup.json',
      );

      final shareResult = await Share.shareXFiles(
        [xFile],
        subject: 'Backup Neves Finanças ($dateStr)',
        text:
            'Arquivo de backup dos seus dados financeiros do Neves gerado em $dateStr.',
      );

      return shareResult.status != ShareResultStatus.unavailable;
    } catch (e) {
      debugPrint('Erro ao compartilhar backup: $e');
      return false;
    }
  }

  Future<bool> checkAndRunWeeklyAutoBackup(AppState appState) async {
    if (isTestEnvironment) return false;

    try {
      final prefs = appState.prefs;
      if (prefs == null) return false;

      final lastBackupMs = prefs.getInt(_keyLastAutoBackup) ?? 0;
      final now = DateTime.now();
      final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);

      if (now.difference(lastBackup).inDays >= 7) {
        final res = await generateLocalBackup(appState);
        if (res.success) {
          await prefs.setInt(_keyLastAutoBackup, now.millisecondsSinceEpoch);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Aviso ao verificar auto backup: $e');
      return false;
    }
  }

  /// Gera um relatório textual legível para conciliação com banco ou outro app financeiro.
  String buildReconciliationReport(
    AppState appState, {
    bool includeAllTransactions = true,
  }) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final ym = appState.selectedYearMonth;
    final buf = StringBuffer();

    buf.writeln('=== RELATÓRIO DE CONCILIAÇÃO FINANCEIRA — NEVES ===');
    buf.writeln(
      'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    buf.writeln('Mês em análise: $ym');
    buf.writeln('Regime de orçamento/cartão: ${appState.budgetRegime.label}');
    buf.writeln();

    buf.writeln('--- 1. RESUMO GERAL ---');
    buf.writeln(
      'Saldo Disponível (Contas líquidas): ${money.format(appState.liquidAccountsBalance)}',
    );
    buf.writeln(
      'Investimentos (Contas): ${money.format(appState.investmentAccountsBalance)}',
    );
    buf.writeln(
      'Caixinhas (Metas): ${money.format(appState.goalsTotalBalance)}',
    );
    buf.writeln(
      'Dívida em aberto (Cartões): ${money.format(appState.totalCreditCardUnpaidDebt)}',
    );
    buf.writeln('Patrimônio Líquido: ${money.format(appState.netWorth)}');
    buf.writeln(
      'Receitas do mês ($ym): ${money.format(appState.totalIncomeForMonth(ym))}',
    );
    buf.writeln(
      'Despesas do mês ($ym): ${money.format(appState.totalExpenseForMonth(ym))}',
    );
    buf.writeln(
      'Saldo Projetado fim do mês ($ym): ${money.format(appState.projectedEndOfMonthBalance(ym))}',
    );
    buf.writeln();

    buf.writeln('--- 2. CONTAS BANCÁRIAS (SALDO INICIAL -> SALDO ATUAL) ---');
    if (appState.accounts.isEmpty) {
      buf.writeln('(Nenhuma conta cadastrada)');
    } else {
      for (final acc in appState.accounts) {
        final paidTxs = appState.transactions.where(
          (t) =>
              !t.isIgnored &&
              t.status == TransactionStatus.paid &&
              (!t.isCreditCard || t.isInvoicePayment) &&
              (t.accountId == acc.id || t.destinationAccountId == acc.id),
        );
        double credits = 0;
        double debits = 0;
        for (final t in paidTxs) {
          if (t.type == TransactionType.income && t.accountId == acc.id) {
            credits += t.amount;
          } else if (t.type == TransactionType.expense &&
              t.accountId == acc.id) {
            debits += t.amount;
          } else if (t.type == TransactionType.transfer) {
            if (t.accountId == acc.id) debits += t.amount;
            if (t.destinationAccountId == acc.id) credits += t.amount;
          }
        }
        final archivedTag = acc.archived ? ' [ARQUIVADA]' : '';
        buf.writeln(
          '- ${acc.name} (${acc.type.label})$archivedTag | Saldo Inicial: ${money.format(acc.initialBalance)} | Entradas Pagas: +${money.format(credits)} | Saídas Pagas: -${money.format(debits)} | Saldo Atual: ${money.format(acc.currentBalance)}',
        );
      }
    }
    buf.writeln();

    buf.writeln('--- 3. CARTÕES DE CRÉDITO ---');
    if (appState.creditCards.isEmpty) {
      buf.writeln('(Nenhum cartão cadastrado)');
    } else {
      for (final card in appState.creditCards) {
        final used = appState.getCardUsedLimit(card.id);
        final invoiceTotal = appState.getInvoiceTotal(card.id, ym);
        final invStatus = appState.getInvoiceStatus(card, ym);
        buf.writeln(
          '- ${card.name} (Fecha dia ${card.closingDay}, Vence dia ${card.dueDay}) | Fatura $ym: ${money.format(invoiceTotal)} (${invStatus.label}) | Em aberto total: ${money.format(used)} | Limite: ${money.format(card.creditLimit)}',
        );
      }
    }
    buf.writeln();

    buf.writeln('--- 4. CAIXINHAS ---');
    if (appState.goals.isEmpty) {
      buf.writeln('(Nenhuma caixinha cadastrada)');
    } else {
      for (final g in appState.goals) {
        buf.writeln(
          '- ${g.name} | Guardado: ${money.format(g.currentAmount)} | Meta: ${money.format(g.targetAmount)}',
        );
      }
    }
    buf.writeln();

    final txs = (includeAllTransactions
            ? List<TransactionModel>.from(appState.transactions)
            : appState.transactionsForMonth(ym, includeIgnored: true))
      ..sort((a, b) => b.date.compareTo(a.date));

    buf.writeln(
      '--- 5. LANÇAMENTOS (${includeAllTransactions ? 'HISTÓRICO COMPLETO: ${txs.length}' : 'MÊS $ym: ${txs.length}'}) ---',
    );
    buf.writeln(
      'Data Compra | Competência | Tipo | Meio/Conta | Destino | Categoria | Status | Ignorado | Valor | Descrição',
    );
    for (final t in txs) {
      final accName = appState.getAccountById(t.accountId)?.name ??
          (t.cardId != null
              ? 'Cartão ${appState.getCardById(t.cardId)?.name ?? t.cardId}'
              : '-');
      final destName = t.destinationAccountId != null
          ? (appState.getAccountById(t.destinationAccountId)?.name ?? '-')
          : '-';
      final catName = appState.getCategoryById(t.categoryId)?.name ?? '-';
      final installmentInfo =
          t.isInstallment ? ' (${t.installmentIndex}/${t.installmentTotal})' : '';
      final invoicePayTag = t.isInvoicePayment ? ' [PAG. FATURA]' : '';
      buf.writeln(
        '${dateFmt.format(t.date)} | ${t.competenceMonth} | ${t.type.label} | $accName | $destName | $catName | ${t.status.label} | ${t.isIgnored ? 'SIM' : 'NÃO'} | ${money.format(t.amount)} | ${t.title}$installmentInfo$invoicePayTag',
      );
    }

    return buf.toString();
  }

  Future<BackupResult> generateReconciliationReportFile(
    AppState appState, {
    bool includeAllTransactions = true,
  }) async {
    if (isTestEnvironment) {
      return const BackupResult(
        success: true,
        filePath: '/mock/relatorio_conciliacao.txt',
        message: 'Relatório simulado em ambiente de teste.',
      );
    }

    try {
      final content = buildReconciliationReport(
        appState,
        includeAllTransactions: includeAllTransactions,
      );
      final docsDir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory('${docsDir.path}/backups');
      if (!backupFolder.existsSync()) {
        backupFolder.createSync(recursive: true);
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file =
          File('${backupFolder.path}/relatorio_conciliacao_$dateStr.txt');
      await file.writeAsString(content, flush: true);

      return BackupResult(
        success: true,
        filePath: file.path,
        message: 'Relatório salvo em Documentos/backups!',
      );
    } catch (e) {
      debugPrint('Erro ao gerar relatório de conciliação: $e');
      return BackupResult(
        success: false,
        message: 'Falha ao salvar relatório: $e',
      );
    }
  }
}
