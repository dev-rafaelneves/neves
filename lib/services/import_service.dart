import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/models.dart';

/// Serviço local para importação de extratos e faturas em formato OFX, CSV ou texto extraído de PDF,
/// com detecção de duplicatas via hash SHA-256 e sugestão inteligente de categoria por histórico/palavras-chave.
class ImportService {
  static String computeImportHash({
    required DateTime date,
    required double amount,
    required String title,
  }) {
    final normalizedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final normalizedTitle = title.trim().toLowerCase();
    final raw = '$normalizedDate|${amount.toStringAsFixed(2)}|$normalizedTitle';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 24);
  }

  /// Faz o parse automático de conteúdo OFX ou CSV/Texto
  static List<ImportedTransactionCandidate> parseStatementContent({
    required String content,
    required String extension,
    required List<CategoryModel> categories,
    required List<TransactionModel> existingTransactions,
    bool forceExpenseForCreditCard = false,
  }) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    List<ImportedTransactionCandidate> rawCandidates;

    if (ext == 'ofx' || content.toUpperCase().contains('<STMTTRN>')) {
      rawCandidates = _parseOfx(
        content,
        forceExpenseForCreditCard: forceExpenseForCreditCard,
      );
    } else {
      rawCandidates = _parseCsvOrLines(
        content,
        forceExpenseForCreditCard: forceExpenseForCreditCard,
      );
    }

    final existingHashes = existingTransactions
        .map((t) =>
            t.importHash ??
            computeImportHash(date: t.date, amount: t.amount, title: t.title))
        .toSet();

    for (final candidate in rawCandidates) {
      candidate.isDuplicate = existingHashes.contains(candidate.importHash);
      if (candidate.isDuplicate) {
        candidate.selected = false;
      }
      candidate.suggestedCategoryId = suggestCategory(
        title: candidate.title,
        type: candidate.type,
        categories: categories,
        existingTransactions: existingTransactions,
      );
    }

    return rawCandidates;
  }

  static List<ImportedTransactionCandidate> _parseOfx(
    String content, {
    required bool forceExpenseForCreditCard,
  }) {
    final results = <ImportedTransactionCandidate>[];
    final blockRegex = RegExp(
      r'<STMTTRN>(.*?)</STMTTRN>',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = blockRegex.allMatches(content);
    if (matches.isNotEmpty) {
      for (final m in matches) {
        final block = m.group(1) ?? '';
        final candidate = _extractOfxBlock(
          block,
          forceExpenseForCreditCard: forceExpenseForCreditCard,
        );
        if (candidate != null) results.add(candidate);
      }
      return results;
    }

    // Fallback para OFX SGML v1 sem tag de fechamento </STMTTRN>
    final parts = content.split(RegExp(r'<STMTTRN>', caseSensitive: false));
    for (int i = 1; i < parts.length; i++) {
      final candidate = _extractOfxBlock(
        parts[i],
        forceExpenseForCreditCard: forceExpenseForCreditCard,
      );
      if (candidate != null) results.add(candidate);
    }
    return results;
  }

  static ImportedTransactionCandidate? _extractOfxBlock(
    String block, {
    required bool forceExpenseForCreditCard,
  }) {
    String? extractTag(String tag) {
      final reg = RegExp('<$tag>([^<\r\n]+)', caseSensitive: false);
      return reg.firstMatch(block)?.group(1)?.trim();
    }

    final rawAmt = extractTag('TRNAMT')?.replaceAll(',', '.');
    if (rawAmt == null) return null;
    final parsedAmt = double.tryParse(rawAmt);
    if (parsedAmt == null || parsedAmt == 0) return null;

    final rawDate = extractTag('DTPOSTED') ?? '';
    DateTime date = DateTime.now();
    if (rawDate.length >= 8) {
      final y = int.tryParse(rawDate.substring(0, 4));
      final mo = int.tryParse(rawDate.substring(4, 6));
      final d = int.tryParse(rawDate.substring(6, 8));
      if (y != null && mo != null && d != null) {
        date = DateTime(y, mo, d);
      }
    }

    final memo = extractTag('MEMO') ?? extractTag('NAME') ?? 'Lançamento OFX';
    final isExpense = forceExpenseForCreditCard ? true : parsedAmt < 0;
    final absAmount = parsedAmt.abs();
    final hash = computeImportHash(date: date, amount: absAmount, title: memo);

    return ImportedTransactionCandidate(
      title: memo,
      amount: absAmount,
      date: date,
      type: isExpense ? TransactionType.expense : TransactionType.income,
      importHash: hash,
    );
  }

  static List<ImportedTransactionCandidate> _parseCsvOrLines(
    String content, {
    required bool forceExpenseForCreditCard,
  }) {
    final results = <ImportedTransactionCandidate>[];
    final lines = const LineSplitter().convert(content);

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignora cabeçalhos comuns de CSV (data, valor, descrição, title, amount...)
      final lower = line.toLowerCase();
      if (lower.startsWith('data') ||
          lower.startsWith('date') ||
          lower.startsWith('"data"')) {
        continue;
      }

      final sep = line.contains(';') ? ';' : ',';
      final cols = line
          .split(sep)
          .map((c) => c.trim().replaceAll('"', ''))
          .where((c) => c.isNotEmpty)
          .toList();

      if (cols.length < 2) continue;

      DateTime? foundDate;
      double? foundAmount;
      final textParts = <String>[];

      for (final col in cols) {
        if (foundDate == null) {
          final dt = _tryParseDate(col);
          if (dt != null) {
            foundDate = dt;
            continue;
          }
        }
        if (foundAmount == null) {
          final amt = _tryParseCurrency(col);
          if (amt != null && amt != 0) {
            foundAmount = amt;
            continue;
          }
        }
        textParts.add(col);
      }

      if (foundDate != null && foundAmount != null) {
        final title =
            textParts.isNotEmpty ? textParts.join(' - ') : 'Lançamento Importado';
        // No CSV de fatura do Nubank (date,category,title,amount), valores positivos são compras
        final isExpense =
            forceExpenseForCreditCard ? true : (foundAmount < 0);
        final absAmount = foundAmount.abs();
        final hash = computeImportHash(
          date: foundDate,
          amount: absAmount,
          title: title,
        );

        results.add(
          ImportedTransactionCandidate(
            title: title,
            amount: absAmount,
            date: foundDate,
            type: isExpense ? TransactionType.expense : TransactionType.income,
            importHash: hash,
          ),
        );
      }
    }

    return results;
  }

  static DateTime? _tryParseDate(String raw) {
    final clean = raw.trim();
    // YYYY-MM-DD
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(clean);
    if (isoMatch != null) {
      return DateTime.tryParse(clean.substring(0, 10));
    }
    // DD/MM/YYYY
    final brMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(clean);
    if (brMatch != null) {
      final d = int.parse(brMatch.group(1)!);
      final m = int.parse(brMatch.group(2)!);
      final y = int.parse(brMatch.group(3)!);
      return DateTime(y, m, d);
    }
    return null;
  }

  static double? _tryParseCurrency(String raw) {
    var clean = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (!RegExp(r'^-?[\d.,]+$').hasMatch(clean)) return null;

    if (clean.contains(',') && clean.contains('.')) {
      // Ex: 1.250,50 -> 1250.50
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean);
  }

  /// Sugere automaticamente a categoria com base no histórico do usuário e palavras-chave brasileiras
  static String? suggestCategory({
    required String title,
    required TransactionType type,
    required List<CategoryModel> categories,
    required List<TransactionModel> existingTransactions,
  }) {
    final lower = title.toLowerCase();

    // 1. Verifica histórico de lançamentos anteriores com título similar
    for (final tx in existingTransactions) {
      if (tx.categoryId != null &&
          tx.type == type &&
          (tx.title.toLowerCase() == lower ||
              lower.contains(tx.title.toLowerCase()))) {
        return tx.categoryId;
      }
    }

    final validCats = categories.where((c) => c.type == type).toList();
    if (validCats.isEmpty) return null;

    String? findByKeyword(String nameFragment) {
      for (final c in validCats) {
        if (c.name.toLowerCase().contains(nameFragment)) return c.id;
      }
      return null;
    }

    if (type == TransactionType.income) {
      if (lower.contains('salário') ||
          lower.contains('salario') ||
          lower.contains('pagamento') ||
          lower.contains('adiantamento')) {
        return findByKeyword('salário') ?? validCats.first.id;
      }
      if (lower.contains('dividendo') ||
          lower.contains('rendimento') ||
          lower.contains('fii') ||
          lower.contains('cdb')) {
        return findByKeyword('rendimento') ?? validCats.first.id;
      }
      return validCats.first.id;
    }

    // Heurística de despesas brasileiras
    if (lower.contains('uber') ||
        lower.contains('99') ||
        lower.contains('posto') ||
        lower.contains('combust') ||
        lower.contains('estacionamento') ||
        lower.contains('sem parar')) {
      return findByKeyword('transporte');
    }
    if (lower.contains('ifood') ||
        lower.contains('restaurante') ||
        lower.contains('padaria') ||
        lower.contains('lanch') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('cafe')) {
      return findByKeyword('restaurante') ?? findByKeyword('alimenta');
    }
    if (lower.contains('mercado') ||
        lower.contains('supermercado') ||
        lower.contains('atacad') ||
        lower.contains('carrefour') ||
        lower.contains('assai') ||
        lower.contains('pao de acucar')) {
      return findByKeyword('mercado') ?? findByKeyword('alimenta');
    }
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('prime') ||
        lower.contains('icloud') ||
        lower.contains('google') ||
        lower.contains('youtube') ||
        lower.contains('chatgpt')) {
      return findByKeyword('assinatura');
    }
    if (lower.contains('farmacia') ||
        lower.contains('droga') ||
        lower.contains('raia') ||
        lower.contains('pacheco') ||
        lower.contains('hospital') ||
        lower.contains('unimed') ||
        lower.contains('medico')) {
      return findByKeyword('saúde') ?? findByKeyword('saude');
    }
    if (lower.contains('aluguel') ||
        lower.contains('condominio') ||
        lower.contains('energia') ||
        lower.contains('enel') ||
        lower.contains('sabesp') ||
        lower.contains('vivo') ||
        lower.contains('claro') ||
        lower.contains('internet')) {
      return findByKeyword('moradia');
    }

    return validCats.first.id;
  }
}
