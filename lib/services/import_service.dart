import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/models.dart';

/// Serviço local para importação de extratos e faturas em formato OFX, CSV ou texto extraído de PDF,
/// com detecção de duplicatas via hash SHA-256 e sugestão inteligente de categoria por histórico/palavras-chave.
class ImportService {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Prompt pronto para enviar ao Assistente Virtual do Mercado Pago (ou qualquer IA lendo o PDF/extrato)
  /// para gerar um CSV padronizado com identificação automática de Cofrinho, Rendimentos, Transferências, Despesas e Receitas.
  static const String mercadoPagoAssistantPrompt = '''
Preciso que você gere um relatório das minhas movimentações (extrato da conta e/ou fatura) em formato CSV, separado por ponto e vírgula (;), contendo exatamente estas 4 colunas:

Data;Tipo;Descricao;Valor

Regras obrigatórias de formatação para cada coluna:
1. Data: no formato DD/MM/AAAA (ex: 15/11/2026).
2. Tipo: classifique cada movimentação usando EXATAMENTE uma das 6 tags abaixo:
   - DESPESA (compras no cartão/débito, pagamentos de boletos, Pix enviados para terceiros/lojas, tarifas)
   - RECEITA (salário, Pix recebidos de terceiros, vendas, reembolsos/estornos)
   - TRANSFERENCIA (transferências entre contas de minha própria titularidade)
   - GUARDAR_COFRINHO (dinheiro guardado/aplicado no Cofrinho / Reservas)
   - RESGATE_COFRINHO (dinheiro retirado/resgatado do Cofrinho / Reservas de volta para a conta)
   - RENDIMENTO_COFRINHO (rendimentos diários/mensais do Cofrinho ou saldo em conta)
3. Descricao: nome limpo do estabelecimento, pessoa ou operação (sem ponto e vírgula no texto).
4. Valor: número decimal com ponto para centavos e SEM "R\$" (use sinal negativo "-" para saídas/despesas/aplicações no cofrinho e positivo para entradas/receitas/resgates/rendimentos).

Exemplo exato de como você deve responder (entregue apenas o bloco CSV):
Data;Tipo;Descricao;Valor
05/11/2026;RECEITA;Pix Recebido Cliente;2500.00
06/11/2026;GUARDAR_COFRINHO;Dinheiro guardado no Cofrinho;-500.00
10/11/2026;RENDIMENTO_COFRINHO;Rendimentos do Cofrinho CDI;14.85
12/11/2026;RESGATE_COFRINHO;Dinheiro retirado do Cofrinho;200.00
14/11/2026;TRANSFERENCIA;Transferencia para minha conta Nubank;-300.00
15/11/2026;DESPESA;Mercado Livre Compra;-189.90
''';

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
    List<GoalModel> goals = const [],
    List<Account> accounts = const [],
    String? sourceAccountId,
    bool forceExpenseForCreditCard = false,
    bool invertSigns = false,
  }) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    List<ImportedTransactionCandidate> rawCandidates;

    if (ext == 'ofx' || content.toUpperCase().contains('<STMTTRN>')) {
      rawCandidates = _parseOfx(
        content,
        forceExpenseForCreditCard: forceExpenseForCreditCard,
        invertSigns: invertSigns,
      );
    } else {
      rawCandidates = _parseCsvOrLines(
        content,
        forceExpenseForCreditCard: forceExpenseForCreditCard,
        invertSigns: invertSigns,
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
      applyOperationMetadata(
        candidate: candidate,
        categories: categories,
        existingTransactions: existingTransactions,
        goals: goals,
        accounts: accounts,
        sourceAccountId: sourceAccountId,
      );
    }

    return rawCandidates;
  }

  /// Aplica o TransactionType, Categoria, Cofrinho (Goal) e Conta de Destino de acordo com o StatementOperationType
  static void applyOperationMetadata({
    required ImportedTransactionCandidate candidate,
    required List<CategoryModel> categories,
    required List<TransactionModel> existingTransactions,
    List<GoalModel> goals = const [],
    List<Account> accounts = const [],
    String? sourceAccountId,
  }) {
    candidate.type = candidate.operationType.transactionType;

    // Cofrinho padrão (prioriza meta com "cofrinho" ou "reserva" no nome, ou a primeira disponível)
    String? defaultGoalId;
    if (goals.isNotEmpty) {
      final match = goals.where((g) {
        final lower = g.name.toLowerCase();
        return lower.contains('cofrinho') ||
            lower.contains('reserva') ||
            lower.contains('caixinha');
      });
      defaultGoalId = match.isNotEmpty ? match.first.id : goals.first.id;
    }

    // Conta de destino padrão para transferências (outra conta diferente da conta de origem)
    String? defaultDestAccId;
    if (accounts.isNotEmpty) {
      final other = accounts.where((a) => a.id != sourceAccountId);
      defaultDestAccId = other.isNotEmpty ? other.first.id : accounts.first.id;
    }

    switch (candidate.operationType) {
      case StatementOperationType.cofrinhoDeposit:
        candidate.suggestedGoalId ??= defaultGoalId;
        candidate.destinationAccountId = null;
        candidate.suggestedCategoryId = _findCategoryId(
          categories,
          preferredId: 'cat_aportes',
          type: TransactionType.expense,
        );
        break;
      case StatementOperationType.cofrinhoWithdraw:
        candidate.suggestedGoalId ??= defaultGoalId;
        candidate.destinationAccountId = null;
        candidate.suggestedCategoryId = _findCategoryId(
          categories,
          preferredId: 'cat_outras_receitas',
          type: TransactionType.income,
        );
        break;
      case StatementOperationType.cofrinhoYield:
        candidate.suggestedGoalId ??= defaultGoalId;
        candidate.destinationAccountId = null;
        candidate.suggestedCategoryId = _findCategoryId(
          categories,
          preferredId: 'cat_rendimentos',
          type: TransactionType.income,
        );
        break;
      case StatementOperationType.transfer:
        candidate.suggestedGoalId = null;
        candidate.suggestedCategoryId = null;
        candidate.destinationAccountId ??= defaultDestAccId;
        break;
      case StatementOperationType.expense:
      case StatementOperationType.income:
        candidate.suggestedGoalId = null;
        candidate.destinationAccountId = null;
        candidate.suggestedCategoryId = suggestCategory(
          title: candidate.title,
          type: candidate.type,
          categories: categories,
          existingTransactions: existingTransactions,
        );
        break;
    }
  }

  static String? _findCategoryId(
    List<CategoryModel> categories, {
    required String preferredId,
    required TransactionType type,
  }) {
    for (final c in categories) {
      if (c.id == preferredId) return c.id;
    }
    final valid = categories.where((c) => c.type == type);
    return valid.isNotEmpty ? valid.first.id : null;
  }

  /// Detecta automaticamente uma das 6 operações a partir da descrição do extrato (Mercado Pago, Nubank, Inter, etc.)
  static StatementOperationType detectOperationType({
    required String title,
    required bool isExpenseBySign,
  }) {
    final lower = title.toLowerCase();

    // 1. Rendimentos no Cofrinho / Conta remunerada
    if (lower.contains('rendimento') ||
        lower.contains('rendimentos') ||
        lower.contains('juros cofrinho') ||
        lower.contains('remuneração de conta') ||
        lower.contains('remuneracao de conta')) {
      return StatementOperationType.cofrinhoYield;
    }

    // 2. Dinheiro retirado / resgatado do Cofrinho / Caixinha / Reservas
    if (lower.contains('dinheiro retirado') ||
        lower.contains('retirada do cofrinho') ||
        lower.contains('retirado do cofrinho') ||
        lower.contains('resgate do cofrinho') ||
        lower.contains('resgate cofrinho') ||
        lower.contains('resgate de reserva') ||
        lower.contains('resgate reservas') ||
        lower.contains('resgate caixinha') ||
        lower.contains('retirada caixinha') ||
        lower.contains('dinheiro resgatado') ||
        (lower.contains('liberação de dinheiro') &&
            lower.contains('reserva'))) {
      return StatementOperationType.cofrinhoWithdraw;
    }

    // 3. Dinheiro guardado / aplicado no Cofrinho / Caixinha / Reservas
    if (lower.contains('dinheiro guardado') ||
        lower.contains('guardar no cofrinho') ||
        lower.contains('guardado no cofrinho') ||
        lower.contains('aplicação no cofrinho') ||
        lower.contains('aplicacao no cofrinho') ||
        lower.contains('depósito no cofrinho') ||
        lower.contains('deposito no cofrinho') ||
        lower.contains('reserva no cofrinho') ||
        lower.contains('dinheiro reservado') ||
        lower.contains('guardado na caixinha') ||
        lower.contains('aplicação caixinha') ||
        lower.contains('aplicacao caixinha') ||
        (lower.contains('cofrinho') && isExpenseBySign)) {
      return StatementOperationType.cofrinhoDeposit;
    }

    // Caso mencione cofrinho com sinal de entrada e não caiu nas regras acima, é resgate do cofrinho
    if (lower.contains('cofrinho') && !isExpenseBySign) {
      return StatementOperationType.cofrinhoWithdraw;
    }

    // 4. Transferência entre contas próprias
    if (lower.contains('transferência entre contas') ||
        lower.contains('transferencia entre contas') ||
        lower.contains('mesma titularidade') ||
        lower.contains('conta própria') ||
        lower.contains('conta propria')) {
      return StatementOperationType.transfer;
    }

    return isExpenseBySign
        ? StatementOperationType.expense
        : StatementOperationType.income;
  }

  /// Inverte Receita <-> Despesa (e Guardar <-> Retirada Cofrinho) de todos os candidatos e recalcula metadados
  static void invertAllCandidateTypes({
    required List<ImportedTransactionCandidate> candidates,
    required List<CategoryModel> categories,
    required List<TransactionModel> existingTransactions,
    List<GoalModel> goals = const [],
    List<Account> accounts = const [],
    String? sourceAccountId,
  }) {
    for (final c in candidates) {
      if (c.operationType == StatementOperationType.expense) {
        c.operationType = StatementOperationType.income;
      } else if (c.operationType == StatementOperationType.income) {
        c.operationType = StatementOperationType.expense;
      } else if (c.operationType == StatementOperationType.cofrinhoDeposit) {
        c.operationType = StatementOperationType.cofrinhoWithdraw;
      } else if (c.operationType == StatementOperationType.cofrinhoWithdraw) {
        c.operationType = StatementOperationType.cofrinhoDeposit;
      }
      applyOperationMetadata(
        candidate: c,
        categories: categories,
        existingTransactions: existingTransactions,
        goals: goals,
        accounts: accounts,
        sourceAccountId: sourceAccountId,
      );
    }
  }

  static List<ImportedTransactionCandidate> _parseOfx(
    String content, {
    required bool forceExpenseForCreditCard,
    required bool invertSigns,
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
          invertSigns: invertSigns,
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
        invertSigns: invertSigns,
      );
      if (candidate != null) results.add(candidate);
    }
    return results;
  }

  static ImportedTransactionCandidate? _extractOfxBlock(
    String block, {
    required bool forceExpenseForCreditCard,
    required bool invertSigns,
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
    bool isExpense = forceExpenseForCreditCard
        ? (parsedAmt > 0)
        : (parsedAmt < 0);
    if (invertSigns) {
      isExpense = !isExpense;
    }

    final absAmount = parsedAmt.abs();
    final hash = computeImportHash(date: date, amount: absAmount, title: memo);
    final opType = detectOperationType(
      title: memo,
      isExpenseBySign: isExpense,
    );

    return ImportedTransactionCandidate(
      title: memo,
      amount: absAmount,
      date: date,
      type: opType.transactionType,
      operationType: opType,
      importHash: hash,
    );
  }

  static List<ImportedTransactionCandidate> _parseCsvOrLines(
    String content, {
    required bool forceExpenseForCreditCard,
    required bool invertSigns,
  }) {
    final results = <ImportedTransactionCandidate>[];
    final lines = const LineSplitter().convert(content);

    // Detecta automaticamente o cabeçalho de fatura do Nubank (date,title,amount ou date,category,title,amount),
    // onde valores positivos (+) são compras (Despesas) e valores negativos (-) são pagamentos/estornos (Receitas).
    bool isNubankPositiveExpenseCsv = false;
    bool hasCategoryColumn = false;

    for (final rawLine in lines) {
      final lower = rawLine.trim().toLowerCase();
      if (lower.isEmpty) continue;
      if (lower.startsWith('date') && lower.contains('amount')) {
        isNubankPositiveExpenseCsv = true;
        if (lower.contains('category')) {
          hasCategoryColumn = true;
        }
        break;
      }
      if (lower.startsWith('data') || lower.startsWith('"data"')) {
        break;
      }
    }

    // Também detecta heurística Nubank quando não há cabeçalho mas há linhas ISO YYYY-MM-DD com "pagamento recebido" negativo
    if (!isNubankPositiveExpenseCsv) {
      for (final rawLine in lines) {
        final lower = rawLine.trim().toLowerCase();
        if (lower.contains('pagamento recebido') && lower.contains('-')) {
          isNubankPositiveExpenseCsv = true;
          break;
        }
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignora cabeçalhos comuns de CSV (data, valor, descrição, title, amount...)
      final lower = line.toLowerCase();
      if (lower.startsWith('data') ||
          lower.startsWith('date') ||
          lower.startsWith('"data"') ||
          lower.startsWith('"date"')) {
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
      StatementOperationType? explicitOpType;
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
        if (explicitOpType == null) {
          final parsedOp = StatementOperationType.tryParseCsvToken(col);
          if (parsedOp != null) {
            explicitOpType = parsedOp;
            continue;
          }
        }
        // Ignora coluna Identificador UUID do extrato da NuConta
        if (_uuidRegex.hasMatch(col)) {
          continue;
        }
        textParts.add(col);
      }

      if (foundDate != null && foundAmount != null) {
        String title;
        if (hasCategoryColumn && textParts.length >= 2) {
          // Em date,category,title,amount do Nubank, textParts[0] é category e textParts[1..] é o title
          title = textParts.sublist(1).join(' - ');
        } else {
          title = textParts.isNotEmpty
              ? textParts.join(' - ')
              : 'Lançamento Importado';
        }

        // Define se positivo é despesa (padrão fatura Nubank / cartão de crédito)
        // ou se negativo é despesa (padrão extrato conta corrente)
        final bool positiveMeansExpense =
            forceExpenseForCreditCard || isNubankPositiveExpenseCsv;

        bool isExpense = positiveMeansExpense
            ? (foundAmount > 0)
            : (foundAmount < 0);

        if (invertSigns) {
          isExpense = !isExpense;
        }

        final opType = explicitOpType ??
            detectOperationType(
              title: title,
              isExpenseBySign: isExpense,
            );

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
            type: opType.transactionType,
            operationType: opType,
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

    // Heurística de despesas brasileiras + categorias do CSV Nubank
    if (lower.contains('uber') ||
        lower.contains('99') ||
        lower.contains('posto') ||
        lower.contains('combust') ||
        lower.contains('shell') ||
        lower.contains('ipiranga') ||
        lower.contains('petrobras') ||
        lower.contains('estacionamento') ||
        lower.contains('sem parar') ||
        lower.contains('veloe') ||
        lower.contains('pedagio')) {
      return findByKeyword('transporte');
    }
    if (lower.contains('ifood') ||
        lower.contains('restaurante') ||
        lower.contains('padaria') ||
        lower.contains('lanch') ||
        lower.contains('burger') ||
        lower.contains('mcdonald') ||
        lower.contains('bk ') ||
        lower.contains('outback') ||
        lower.contains('pizza') ||
        lower.contains('sushi') ||
        lower.contains('acai') ||
        lower.contains('açaí') ||
        lower.contains('cafe') ||
        lower.contains('café')) {
      return findByKeyword('restaurante') ?? findByKeyword('alimenta');
    }
    if (lower.contains('mercado') ||
        lower.contains('supermercado') ||
        lower.contains('atacad') ||
        lower.contains('carrefour') ||
        lower.contains('assai') ||
        lower.contains('assaí') ||
        lower.contains('pao de acucar') ||
        lower.contains('hortifruti') ||
        lower.contains(' sacolao') ||
        lower.contains('acougue')) {
      return findByKeyword('mercado') ?? findByKeyword('alimenta');
    }
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('prime') ||
        lower.contains('icloud') ||
        lower.contains('apple.com/bill') ||
        lower.contains('google') ||
        lower.contains('youtube') ||
        lower.contains('chatgpt') ||
        lower.contains('openai') ||
        lower.contains('claude') ||
        lower.contains('disney') ||
        lower.contains('hbo') ||
        lower.contains('max')) {
      return findByKeyword('assinatura');
    }
    if (lower.contains('farmacia') ||
        lower.contains('farmácia') ||
        lower.contains('droga') ||
        lower.contains('raia') ||
        lower.contains('pacheco') ||
        lower.contains('pague menos') ||
        lower.contains('panvel') ||
        lower.contains('hospital') ||
        lower.contains('unimed') ||
        lower.contains('medico') ||
        lower.contains('médico') ||
        lower.contains('clinica') ||
        lower.contains('clínica') ||
        lower.contains('laboratorio') ||
        lower.contains('smartfit') ||
        lower.contains('gympass') ||
        lower.contains('wellhub')) {
      return findByKeyword('saúde') ?? findByKeyword('saude');
    }
    if (lower.contains('escola') ||
        lower.contains('faculdade') ||
        lower.contains('curso') ||
        lower.contains('udemy') ||
        lower.contains('alura') ||
        lower.contains('livraria')) {
      return findByKeyword('educação') ?? findByKeyword('educacao');
    }
    if (lower.contains('mercado livre') ||
        lower.contains('mercadolivre') ||
        lower.contains('meli') ||
        lower.contains('shopee') ||
        lower.contains('amazon') ||
        lower.contains('shein') ||
        lower.contains('magalu') ||
        lower.contains('magazine') ||
        lower.contains('renner') ||
        lower.contains('riachuelo') ||
        lower.contains('cea') ||
        lower.contains('zara') ||
        lower.contains('centauro') ||
        lower.contains('nike')) {
      return findByKeyword('compras') ?? findByKeyword('vestuário');
    }
    if (lower.contains('cinema') ||
        lower.contains('ingresso') ||
        lower.contains('steam') ||
        lower.contains('playstation') ||
        lower.contains('xbox') ||
        lower.contains('nintendo') ||
        lower.contains('hotel') ||
        lower.contains('airbnb') ||
        lower.contains('booking') ||
        lower.contains('latam') ||
        lower.contains('azul') ||
        lower.contains('gol ')) {
      return findByKeyword('lazer') ?? findByKeyword('viagens');
    }
    if (lower.contains('aluguel') ||
        lower.contains('condominio') ||
        lower.contains('condomínio') ||
        lower.contains('energia') ||
        lower.contains('enel') ||
        lower.contains('cpfl') ||
        lower.contains('light') ||
        lower.contains('sabesp') ||
        lower.contains('saneago') ||
        lower.contains('copasa') ||
        lower.contains('comgas') ||
        lower.contains('vivo') ||
        lower.contains('claro') ||
        lower.contains('tim') ||
        lower.contains('internet')) {
      return findByKeyword('moradia');
    }

    return validCats.first.id;
  }
}
