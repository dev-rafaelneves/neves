import '../models/models.dart';
import '../theme/app_theme.dart';

enum ImportDestinationType {
  checking('Conta Corrente / Pix (À Vista)'),
  creditCard('Fatura de Cartão');

  final String label;
  const ImportDestinationType(this.label);
}

class ImportCandidate {
  final String id;
  String title;
  DateTime date;
  double amount; // Valor absoluto (sempre > 0)

  /// Na Conta Corrente: true = Receita (+), false = Despesa à Vista (-)
  /// No Cartão de Crédito: false = Compra normal (+ na fatura), true = Estorno/Crédito (- na fatura)
  bool isCreditOrRefund;

  ImportDestinationType destination;
  String? cardId;
  String categoryId;

  int installmentIndex;
  int installmentTotal;
  bool projectFutureInstallments;

  bool selected;
  bool isDuplicate;
  bool isIgnored;
  String? ignoreReason;

  ImportCandidate({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isCreditOrRefund,
    required this.destination,
    this.cardId,
    required this.categoryId,
    this.installmentIndex = 1,
    this.installmentTotal = 1,
    this.projectFutureInstallments = false,
    this.selected = true,
    this.isDuplicate = false,
    this.isIgnored = false,
    this.ignoreReason,
  });

  bool get hasInstallments => installmentTotal > 1;
  bool get canProjectFuture =>
      destination == ImportDestinationType.creditCard &&
      !isCreditOrRefund &&
      installmentTotal > installmentIndex;
}

class ImportService {
  static const Map<String, int> _ptMonths = {
    'jan': 1,
    'fev': 2,
    'mar': 3,
    'abr': 4,
    'mai': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'set': 9,
    'out': 10,
    'nov': 11,
    'dez': 12,
  };

  /// Analisa o conteúdo (OFX, CSV ou Texto colado) e retorna a lista de candidatos prontos para revisão.
  static List<ImportCandidate> parseContent({
    required String content,
    required ImportDestinationType defaultDestination,
    required String selectedInvoiceMonth, // 'YYYY-MM'
    String? defaultCardId,
    required List<CategoryItem> categories,
    required List<TransactionItem> existingTransactions,
    bool invertSigns = false,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];

    final fallbackYear =
        int.tryParse(selectedInvoiceMonth.split('-').first) ??
            DateTime.now().year;

    final bool isOfx = trimmed.toUpperCase().contains('<OFX') ||
        trimmed.toUpperCase().contains('<STMTTRN>');

    final rawRows = isOfx
        ? _parseOfx(
            trimmed,
            defaultDestination: defaultDestination,
            invertSigns: invertSigns,
          )
        : _parseCsvOrText(
            trimmed,
            defaultDestination: defaultDestination,
            fallbackYear: fallbackYear,
            invertSigns: invertSigns,
          );

    final candidates = <ImportCandidate>[];
    for (int i = 0; i < rawRows.length; i++) {
      final row = rawRows[i];
      final inst = extractInstallmentInfo(row.title);
      final instIdx = inst?.index ?? 1;
      final instTotal = inst?.total ?? 1;

      final ignoreReason = detectIgnoreReason(row.title);

      final targetMonth = defaultDestination == ImportDestinationType.creditCard
          ? selectedInvoiceMonth
          : AppFormatters.yearMonthFromDate(row.date);

      final isDup = isDuplicateTransaction(
        title: row.title,
        amount: row.amount,
        date: row.date,
        targetMonth: targetMonth,
        destination: defaultDestination,
        cardId: defaultCardId,
        installmentIndex: instIdx,
        installmentTotal: instTotal,
        existingTransactions: existingTransactions,
      );

      final txTypeForCat =
          (defaultDestination == ImportDestinationType.checking &&
                  row.isCreditOrRefund)
              ? TransactionType.income
              : TransactionType.expense;

      final suggestedCatId = suggestCategoryId(
        title: row.title,
        type: txTypeForCat,
        categories: categories,
        existingTransactions: existingTransactions,
      );

      final shouldSelect = ignoreReason == null && !isDup;

      candidates.add(
        ImportCandidate(
          id: 'imp_${i}_${row.date.millisecondsSinceEpoch}',
          title: row.title,
          date: row.date,
          amount: row.amount,
          isCreditOrRefund: row.isCreditOrRefund,
          destination: defaultDestination,
          cardId: defaultCardId,
          categoryId: suggestedCatId,
          installmentIndex: instIdx,
          installmentTotal: instTotal,
          projectFutureInstallments:
              defaultDestination == ImportDestinationType.creditCard &&
                  !row.isCreditOrRefund &&
                  instTotal > instIdx &&
                  shouldSelect,
          selected: shouldSelect,
          isDuplicate: isDup,
          ignoreReason: ignoreReason,
        ),
      );
    }

    return candidates;
  }

  /// Reavalia duplicatas e categorias quando o usuário troca o destino global no topo da tela.
  static void applyGlobalDestination({
    required List<ImportCandidate> candidates,
    required ImportDestinationType destination,
    required String selectedInvoiceMonth,
    String? cardId,
    required List<CategoryItem> categories,
    required List<TransactionItem> existingTransactions,
  }) {
    for (final c in candidates) {
      c.destination = destination;
      if (destination == ImportDestinationType.creditCard) {
        c.cardId = cardId;
      }
      final targetMonth = destination == ImportDestinationType.creditCard
          ? selectedInvoiceMonth
          : AppFormatters.yearMonthFromDate(c.date);

      c.isDuplicate = isDuplicateTransaction(
        title: c.title,
        amount: c.amount,
        date: c.date,
        targetMonth: targetMonth,
        destination: destination,
        cardId: cardId,
        installmentIndex: c.installmentIndex,
        installmentTotal: c.installmentTotal,
        existingTransactions: existingTransactions,
      );

      final txType =
          (destination == ImportDestinationType.checking && c.isCreditOrRefund)
              ? TransactionType.income
              : TransactionType.expense;

      c.categoryId = suggestCategoryId(
        title: c.title,
        type: txType,
        categories: categories,
        existingTransactions: existingTransactions,
      );

      c.selected = c.ignoreReason == null && !c.isDuplicate;
      c.projectFutureInstallments =
          destination == ImportDestinationType.creditCard &&
              !c.isCreditOrRefund &&
              c.installmentTotal > c.installmentIndex &&
              c.selected;
    }
  }

  /// Detecta se a linha é Pagamento de Fatura ou Movimentação de Cofrinho/CDB/RDB.
  static String? detectIgnoreReason(String title) {
    final lower = _normalizeText(title);

    // 1. Pagamentos de fatura (para não duplicar a fatura com a conta corrente)
    if (lower.contains('pagamento de fatura') ||
        lower.contains('pagto fatura') ||
        lower.contains('pagamento fatura') ||
        lower.contains('pagamento recebido') ||
        lower.contains('pgto fatura') ||
        lower.contains('deb aut fatura') ||
        lower.contains('debito automatico fatura') ||
        lower.contains('fatura cartao')) {
      return 'Pagamento de fatura';
    }

    // 2. Cofrinhos, Caixinhas, RDB, CDB e aplicações internas
    if (lower.contains('cofrinho') ||
        lower.contains('caixinha') ||
        lower.contains('aplicacao rdb') ||
        lower.contains('resgate rdb') ||
        lower.contains('aplicacao cdb') ||
        lower.contains('resgate cdb') ||
        lower.contains('dinheiro guardado') ||
        lower.contains('guardar dinheiro') ||
        lower.contains('resgate de investimento') ||
        lower.contains('aplicacao automatica')) {
      return 'Cofrinho / Investimento';
    }

    // 3. Saldo anterior / Totalizador de extrato
    if (lower == 'saldo anterior' ||
        lower == 'saldo do dia' ||
        lower == 'saldo final' ||
        lower == 'total da fatura') {
      return 'Linha de saldo';
    }

    return null;
  }

  /// Extrai informação de parcela como "2/10", "02/06", "Parcela 3 de 12".
  static ({int index, int total})? extractInstallmentInfo(String title) {
    final regexes = [
      RegExp(
        r'(?:parcela|parc\.?)\s*(\d{1,2})\s*(?:/|de)\s*(\d{1,2})\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(\d{1,2})\s*/\s*(\d{1,2})\b'),
    ];

    for (final reg in regexes) {
      final matches = reg.allMatches(title);
      for (final match in matches) {
        final idx = int.tryParse(match.group(1) ?? '');
        final total = int.tryParse(match.group(2) ?? '');
        if (idx != null &&
            total != null &&
            idx >= 1 &&
            total > 1 &&
            idx <= total &&
            total <= 48) {
          return (index: idx, total: total);
        }
      }
    }
    return null;
  }

  /// Remove sufixos de parcela ("02/10", "Parcela 2/10") para comparar títulos base entre meses.
  static String normalizeBaseTitle(String title) {
    var s = _normalizeText(title);
    s = s.replaceAll(
      RegExp(r'(?:parcela|parc\.?)?\s*\b\d{1,2}\s*(?:/|de)\s*\d{1,2}\b'),
      '',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éê]'), 'e')
        .replaceAll(RegExp(r'[í]'), 'i')
        .replaceAll(RegExp(r'[óôõ]'), 'o')
        .replaceAll(RegExp(r'[úü]'), 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  /// Verifica se o candidato já existe nas transações do mês (incluindo parcelas projetadas anteriormente).
  static bool isDuplicateTransaction({
    required String title,
    required double amount,
    required DateTime date,
    required String targetMonth,
    required ImportDestinationType destination,
    String? cardId,
    required int installmentIndex,
    required int installmentTotal,
    required List<TransactionItem> existingTransactions,
  }) {
    final baseCandidate = normalizeBaseTitle(title);

    for (final tx in existingTransactions) {
      if (tx.competenceMonth != targetMonth) continue;

      final txAbs = tx.amount.abs();
      if ((txAbs - amount).abs() > 0.015) continue;

      if (destination == ImportDestinationType.creditCard) {
        if (tx.paymentMethod != PaymentMethod.creditCard) continue;
        if (cardId != null && tx.cardId != cardId) continue;

        final baseExisting = normalizeBaseTitle(tx.title);
        // Se for a mesma parcela projetada ou mesmo título na fatura
        if (installmentTotal > 1 &&
            tx.installmentTotal == installmentTotal &&
            tx.installmentIndex == installmentIndex &&
            (baseExisting == baseCandidate ||
                baseExisting.contains(baseCandidate) ||
                baseCandidate.contains(baseExisting))) {
          return true;
        }
        if (baseExisting == baseCandidate) {
          return true;
        }
      } else {
        if (tx.paymentMethod != PaymentMethod.cash) continue;
        final baseExisting = normalizeBaseTitle(tx.title);
        final sameDay = tx.date.year == date.year &&
            tx.date.month == date.month &&
            tx.date.day == date.day;
        if (sameDay && baseExisting == baseCandidate) {
          return true;
        }
      }
    }
    return false;
  }

  /// Sugere o ID da categoria com base no histórico do usuário e em palavras-chave brasileiras.
  static String suggestCategoryId({
    required String title,
    required TransactionType type,
    required List<CategoryItem> categories,
    required List<TransactionItem> existingTransactions,
  }) {
    final validCats = categories.where((c) => c.type == type).toList();
    if (validCats.isEmpty) {
      return categories.isNotEmpty ? categories.first.id : 'cat_other_exp';
    }

    final normTitle = normalizeBaseTitle(title);

    // 1. Aprende com o histórico do próprio usuário
    for (final tx in existingTransactions) {
      if (tx.type != type) continue;
      final normExisting = normalizeBaseTitle(tx.title);
      if (normExisting.isNotEmpty &&
          (normExisting == normTitle ||
              (normTitle.length >= 5 && normExisting.contains(normTitle)) ||
              (normExisting.length >= 5 && normTitle.contains(normExisting)))) {
        if (validCats.any((c) => c.id == tx.categoryId)) {
          return tx.categoryId;
        }
      }
    }

    String? findByIdOrKeyword(String id, String keyword) {
      for (final c in validCats) {
        if (c.id == id) return c.id;
      }
      for (final c in validCats) {
        if (_normalizeText(c.name).contains(keyword)) return c.id;
      }
      return null;
    }

    if (type == TransactionType.income) {
      if (normTitle.contains('salario') ||
          normTitle.contains('pagamento') ||
          normTitle.contains('provento') ||
          normTitle.contains('13') ||
          normTitle.contains('ferias') ||
          normTitle.contains('adiantamento')) {
        return findByIdOrKeyword('cat_salary', 'salario') ?? validCats.first.id;
      }
      if (normTitle.contains('dividendo') ||
          normTitle.contains('rendimento') ||
          normTitle.contains('jcp') ||
          normTitle.contains('juros')) {
        return findByIdOrKeyword('cat_invest_inc', 'rendimento') ??
            validCats.first.id;
      }
      return findByIdOrKeyword('cat_extra', 'extra') ?? validCats.first.id;
    }

    // Despesas por palavras-chave
    if (normTitle.contains('mercado') ||
        normTitle.contains('supermercado') ||
        normTitle.contains('atacadao') ||
        normTitle.contains('assai') ||
        normTitle.contains('carrefour') ||
        normTitle.contains('pao de acucar') ||
        normTitle.contains('extra ') ||
        normTitle.contains('ifood') ||
        normTitle.contains('ifd*') ||
        normTitle.contains('rappi') ||
        normTitle.contains('padaria') ||
        normTitle.contains('panificadora') ||
        normTitle.contains('restaurante') ||
        normTitle.contains('lanchonete') ||
        normTitle.contains('burger') ||
        normTitle.contains('mcdonalds') ||
        normTitle.contains('bk ') ||
        normTitle.contains('outback') ||
        normTitle.contains('acougue') ||
        normTitle.contains('hortifruti') ||
        normTitle.contains('cafe') ||
        normTitle.contains('pizza') ||
        normTitle.contains('sushi')) {
      return findByIdOrKeyword('cat_food', 'alimenta') ?? validCats.first.id;
    }

    if (normTitle.contains('uber') ||
        normTitle.contains('99app') ||
        normTitle.contains('99*') ||
        normTitle.contains('99 pop') ||
        normTitle.contains('posto') ||
        normTitle.contains('combustivel') ||
        normTitle.contains('gasolina') ||
        normTitle.contains('ipiranga') ||
        normTitle.contains('shell') ||
        normTitle.contains('petrobras') ||
        normTitle.contains('estacionamento') ||
        normTitle.contains('sem parar') ||
        normTitle.contains('veloe') ||
        normTitle.contains('conectcar') ||
        normTitle.contains('pedagio') ||
        normTitle.contains('metro') ||
        normTitle.contains('onibus') ||
        normTitle.contains('oficina')) {
      return findByIdOrKeyword('cat_transport', 'transporte') ??
          validCats.first.id;
    }

    if (normTitle.contains('aluguel') ||
        normTitle.contains('condominio') ||
        normTitle.contains('energia') ||
        normTitle.contains('enel') ||
        normTitle.contains('cpfl') ||
        normTitle.contains('light') ||
        normTitle.contains('cemig') ||
        normTitle.contains('copel') ||
        normTitle.contains('celesc') ||
        normTitle.contains('equatorial') ||
        normTitle.contains('neoenergia') ||
        normTitle.contains('sabesp') ||
        normTitle.contains('copasa') ||
        normTitle.contains('sanepar') ||
        normTitle.contains('agua') ||
        normTitle.contains('gas') ||
        normTitle.contains('internet') ||
        normTitle.contains('vivo') ||
        normTitle.contains('claro') ||
        normTitle.contains('tim') ||
        normTitle.contains('iptu') ||
        normTitle.contains('ipva')) {
      return findByIdOrKeyword('cat_home', 'moradia') ?? validCats.first.id;
    }

    if (normTitle.contains('farmacia') ||
        normTitle.contains('droga') ||
        normTitle.contains('drogasil') ||
        normTitle.contains('raia') ||
        normTitle.contains('pague menos') ||
        normTitle.contains('panvel') ||
        normTitle.contains('araujo') ||
        normTitle.contains('hospital') ||
        normTitle.contains('unimed') ||
        normTitle.contains('medico') ||
        normTitle.contains('clinica') ||
        normTitle.contains('exame') ||
        normTitle.contains('dentista') ||
        normTitle.contains('academia') ||
        normTitle.contains('smartfit') ||
        normTitle.contains('wellhub') ||
        normTitle.contains('gympass')) {
      return findByIdOrKeyword('cat_health', 'saude') ?? validCats.first.id;
    }

    if (normTitle.contains('netflix') ||
        normTitle.contains('spotify') ||
        normTitle.contains('youtube') ||
        normTitle.contains('amazon prime') ||
        normTitle.contains('disney') ||
        normTitle.contains('hbo') ||
        normTitle.contains('max ') ||
        normTitle.contains('globoplay') ||
        normTitle.contains('apple.com/bill') ||
        normTitle.contains('icloud') ||
        normTitle.contains('google one') ||
        normTitle.contains('chatgpt') ||
        normTitle.contains('openai') ||
        normTitle.contains('claude')) {
      return findByIdOrKeyword('cat_subs', 'assinatura') ?? validCats.first.id;
    }

    if (normTitle.contains('cinema') ||
        normTitle.contains('cinemark') ||
        normTitle.contains('ingresso') ||
        normTitle.contains('sympla') ||
        normTitle.contains('show') ||
        normTitle.contains('steam') ||
        normTitle.contains('playstation') ||
        normTitle.contains('xbox') ||
        normTitle.contains('hotel') ||
        normTitle.contains('airbnb') ||
        normTitle.contains('booking') ||
        normTitle.contains('latam') ||
        normTitle.contains('azul') ||
        normTitle.contains('bar ')) {
      return findByIdOrKeyword('cat_leisure', 'lazer') ?? validCats.first.id;
    }

    if (normTitle.contains('shopee') ||
        normTitle.contains('mercado livre') ||
        normTitle.contains('mercadolivre') ||
        normTitle.contains('meli') ||
        normTitle.contains('amazon') ||
        normTitle.contains('magalu') ||
        normTitle.contains('magazine') ||
        normTitle.contains('shein') ||
        normTitle.contains('aliexpress') ||
        normTitle.contains('renner') ||
        normTitle.contains('riachuelo') ||
        normTitle.contains('cea') ||
        normTitle.contains('zara') ||
        normTitle.contains('centauro') ||
        normTitle.contains('netshoes')) {
      return findByIdOrKeyword('cat_shopping', 'compras') ?? validCats.first.id;
    }

    return findByIdOrKeyword('cat_shopping', 'compras') ?? validCats.first.id;
  }

  // ==================== PARSER OFX ====================

  static List<_RawParsedRow> _parseOfx(
    String content, {
    required ImportDestinationType defaultDestination,
    required bool invertSigns,
  }) {
    final rows = <_RawParsedRow>[];
    final blockExp = RegExp(
      r'<STMTTRN>(.*?)(?:</STMTTRN>|(?=<STMTTRN>|$))',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = blockExp.allMatches(content);
    for (final m in matches) {
      final block = m.group(1) ?? '';
      final rawAmount = _extractOfxTag(block, 'TRNAMT');
      final rawDate = _extractOfxTag(block, 'DTPOSTED');
      final memo = _extractOfxTag(block, 'MEMO');
      final name = _extractOfxTag(block, 'NAME');
      final trnType = (_extractOfxTag(block, 'TRNTYPE') ?? '').toUpperCase();

      if (rawAmount == null) continue;
      final signedVal = _parseFlexibleNumber(rawAmount);
      if (signedVal == null || signedVal.abs() < 0.005) continue;

      final dt = _parseOfxDate(rawDate) ?? DateTime.now();
      final title = (memo != null && memo.isNotEmpty)
          ? memo
          : ((name != null && name.isNotEmpty) ? name : 'Lançamento OFX');

      bool isCreditOrRefund;
      if (defaultDestination == ImportDestinationType.creditCard) {
        // No OFX de cartão (<CCSTMTRS>), compras costumam vir negativas (-50.00) e estornos/pagamentos positivos (+50.00).
        // Se também houver textos explícitos de estorno, marcamos como crédito/estorno.
        final lower = _normalizeText(title);
        final looksRefund = lower.contains('estorno') ||
            lower.contains('credito de') ||
            lower.contains('reembolso') ||
            trnType == 'CREDIT';
        isCreditOrRefund = signedVal > 0 || looksRefund;
      } else {
        // Na Conta Corrente, > 0 é Receita e < 0 é Despesa
        isCreditOrRefund = signedVal > 0;
      }

      if (invertSigns) {
        isCreditOrRefund = !isCreditOrRefund;
      }

      rows.add(
        _RawParsedRow(
          title: _cleanTitleNoise(title),
          date: dt,
          amount: signedVal.abs(),
          isCreditOrRefund: isCreditOrRefund,
        ),
      );
    }

    return rows;
  }

  static String? _extractOfxTag(String block, String tag) {
    final reg = RegExp(
      '<$tag>([^<\\r\\n]+)',
      caseSensitive: false,
    );
    final m = reg.firstMatch(block);
    return m?.group(1)?.trim();
  }

  static DateTime? _parseOfxDate(String? raw) {
    if (raw == null || raw.length < 8) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    final y = int.tryParse(digits.substring(0, 4));
    final m = int.tryParse(digits.substring(4, 6));
    final d = int.tryParse(digits.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m.clamp(1, 12), d.clamp(1, 31));
  }

  // ==================== PARSER CSV E TEXTO COLADO ====================

  static List<_RawParsedRow> _parseCsvOrText(
    String content, {
    required ImportDestinationType defaultDestination,
    required int fallbackYear,
    required bool invertSigns,
  }) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    // 1. Tenta detectar se é um CSV estruturado (com cabeçalho ou delimitador consistente ';' ou ',')
    final csvRows = _tryParseStructuredCsv(
      lines,
      defaultDestination: defaultDestination,
      fallbackYear: fallbackYear,
      invertSigns: invertSigns,
    );
    if (csvRows.isNotEmpty) return csvRows;

    // 2. Fallback para Texto Colado (de PDF de fatura, extrato bancário ou lista livre)
    return _parseFreeTextLines(
      lines,
      defaultDestination: defaultDestination,
      fallbackYear: fallbackYear,
      invertSigns: invertSigns,
    );
  }

  static List<_RawParsedRow> _tryParseStructuredCsv(
    List<String> lines, {
    required ImportDestinationType defaultDestination,
    required int fallbackYear,
    required bool invertSigns,
  }) {
    if (lines.isEmpty) return [];

    // Escolhe o delimitador mais provável (';', ',' ou '\t')
    final first = lines.first;
    String? delimiter;
    if (first.split(';').length >= 3) {
      delimiter = ';';
    } else if (first.split('\t').length >= 3) {
      delimiter = '\t';
    } else if (first.split(',').length >= 3) {
      delimiter = ',';
    }
    if (delimiter == null) return [];

    final rows = <_RawParsedRow>[];
    for (int i = 0; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i], delimiter);
      if (cols.length < 2) continue;

      DateTime? foundDate;
      double? foundSignedAmount;
      final textParts = <String>[];

      for (final col in cols) {
        final c = col.trim();
        if (c.isEmpty) continue;

        if (foundDate == null) {
          final dt = _tryParseDateToken(c, fallbackYear: fallbackYear);
          if (dt != null) {
            foundDate = dt;
            continue;
          }
        }

        // Verifica se a coluna é puramente um valor monetário
        if (_looksLikePureMoneyColumn(c)) {
          final val = _parseFlexibleNumber(c);
          if (val != null && val.abs() >= 0.01) {
            foundSignedAmount = val;
            continue;
          }
        }

        textParts.add(c);
      }

      if (foundDate == null || foundSignedAmount == null) continue;
      final rawTitle =
          textParts.isNotEmpty ? textParts.join(' - ') : 'Lançamento';
      final cleanTitle = _cleanTitleNoise(rawTitle);

      bool isCreditOrRefund = _resolveCsvOrTextCreditFlag(
        signedAmount: foundSignedAmount,
        title: cleanTitle,
        destination: defaultDestination,
      );
      if (invertSigns) {
        isCreditOrRefund = !isCreditOrRefund;
      }

      rows.add(
        _RawParsedRow(
          title: cleanTitle,
          date: foundDate,
          amount: foundSignedAmount.abs(),
          isCreditOrRefund: isCreditOrRefund,
        ),
      );
    }

    return rows;
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && ch == delimiter) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  static List<_RawParsedRow> _parseFreeTextLines(
    List<String> lines, {
    required ImportDestinationType defaultDestination,
    required int fallbackYear,
    required bool invertSigns,
  }) {
    final rows = <_RawParsedRow>[];

    // Regex para data no início ou meio da linha: '12/11/2026', '12/11', '2026-11-12', '12 NOV'
    final dateStartExp = RegExp(
      r'^(\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?|\d{4}-\d{2}-\d{2}|\d{1,2}\s+(?:jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez))\b',
      caseSensitive: false,
    );

    // Regex para valor monetário no final da linha: ex: '-R$ 1.234,56', 'R$ 45,90', '-120,00', '45,90 C', '45,90 D'
    final moneyEndExp = RegExp(
      r'([+\-]?\s*(?:R\$\s*)?[+\-]?\s*(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}|\b[+\-]?\d+\.\d{2})\s*([CDcd])?$',
    );

    DateTime? pendingDate;
    final pendingText = <String>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final dateMatch = dateStartExp.firstMatch(line);
      final moneyMatch = moneyEndExp.firstMatch(line);

      // Caso 1: A linha tem Data E Valor na mesma linha
      if (dateMatch != null &&
          moneyMatch != null &&
          moneyMatch.start > dateMatch.end) {
        final dt = _tryParseDateToken(
          dateMatch.group(1)!,
          fallbackYear: fallbackYear,
        );
        final rawMoney = moneyMatch.group(1)!;
        final cdFlag = moneyMatch.group(2)?.toUpperCase();
        final middleText =
            line.substring(dateMatch.end, moneyMatch.start).trim();

        final val = _parseFlexibleNumber(rawMoney);
        if (dt != null && val != null && val.abs() >= 0.01) {
          double signed = val;
          if (cdFlag == 'D' && signed > 0) signed = -signed;
          if (cdFlag == 'C' && signed < 0) signed = -signed;

          final title = _cleanTitleNoise(
            middleText.isEmpty ? 'Lançamento' : middleText,
          );
          bool isCredit = _resolveCsvOrTextCreditFlag(
            signedAmount: signed,
            title: title,
            destination: defaultDestination,
          );
          if (invertSigns) isCredit = !isCredit;

          rows.add(
            _RawParsedRow(
              title: title,
              date: dt,
              amount: signed.abs(),
              isCreditOrRefund: isCredit,
            ),
          );
          pendingDate = null;
          pendingText.clear();
          continue;
        }
      }

      // Caso 2: Linha só com Data (comum em PDF de banco/fatura onde descrição e valor vêm nas linhas seguintes)
      if (dateMatch != null && moneyMatch == null) {
        final dt = _tryParseDateToken(
          dateMatch.group(1)!,
          fallbackYear: fallbackYear,
        );
        if (dt != null) {
          pendingDate = dt;
          pendingText.clear();
          final rest = line.substring(dateMatch.end).trim();
          if (rest.isNotEmpty) pendingText.add(rest);
          continue;
        }
      }

      // Caso 3: Linha com Valor no fim e já tínhamos uma Data pendente
      if (moneyMatch != null && pendingDate != null) {
        final rawMoney = moneyMatch.group(1)!;
        final cdFlag = moneyMatch.group(2)?.toUpperCase();
        final beforeMoney = line.substring(0, moneyMatch.start).trim();
        if (beforeMoney.isNotEmpty) pendingText.add(beforeMoney);

        final val = _parseFlexibleNumber(rawMoney);
        if (val != null && val.abs() >= 0.01 && pendingText.isNotEmpty) {
          double signed = val;
          if (cdFlag == 'D' && signed > 0) signed = -signed;
          if (cdFlag == 'C' && signed < 0) signed = -signed;

          final title = _cleanTitleNoise(pendingText.join(' '));
          bool isCredit = _resolveCsvOrTextCreditFlag(
            signedAmount: signed,
            title: title,
            destination: defaultDestination,
          );
          if (invertSigns) isCredit = !isCredit;

          rows.add(
            _RawParsedRow(
              title: title,
              date: pendingDate,
              amount: signed.abs(),
              isCreditOrRefund: isCredit,
            ),
          );
          pendingText.clear();
          continue;
        }
      }

      if (pendingDate != null) {
        pendingText.add(line);
      }
    }

    return rows;
  }

  static bool _resolveCsvOrTextCreditFlag({
    required double signedAmount,
    required String title,
    required ImportDestinationType destination,
  }) {
    final lower = _normalizeText(title);
    if (destination == ImportDestinationType.creditCard) {
      // Em faturas CSV/PDF brasileiras (ex.: Nubank, Itaú), compras vêm positivas (+50,00)
      // e estornos/descontos vêm negativos (-50,00) ou contêm a palavra "estorno"/"crédito".
      final hasRefundWord = lower.contains('estorno') ||
          lower.contains('credito na fatura') ||
          lower.contains('desconto na fatura') ||
          lower.contains('reembolso');
      return signedAmount < 0 || hasRefundWord;
    } else {
      // Na Conta Corrente, positivo é Receita (Entrada) e negativo é Despesa (Saída)
      return signedAmount > 0;
    }
  }

  static bool _looksLikePureMoneyColumn(String col) {
    final cleaned = col
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('+', '')
        .replaceAll('-', '');
    return RegExp(r'^(?:\d{1,3}(?:[.,]\d{3})*|\d+)[.,]\d{2}$')
        .hasMatch(cleaned);
  }

  static double? _parseFlexibleNumber(String raw) {
    var s = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (s.isEmpty) return null;

    bool isNegative = false;
    if (s.contains('-')) {
      isNegative = true;
      s = s.replaceAll('-', '');
    }
    s = s.replaceAll('+', '');

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');

    if (lastComma > lastDot) {
      // Formato brasileiro: 1.234,56
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma && lastComma != -1) {
      // Formato US com milhar: 1,234.56
      s = s.replaceAll(',', '');
    } else if (lastComma != -1 && lastDot == -1) {
      s = s.replaceAll(',', '.');
    }

    final val = double.tryParse(s);
    if (val == null) return null;
    return isNegative ? -val : val;
  }

  static DateTime? _tryParseDateToken(
    String token, {
    required int fallbackYear,
  }) {
    final s = token.trim();

    // YYYY-MM-DD
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m.clamp(1, 12), d.clamp(1, 31));
    }

    // DD/MM/YYYY ou DD/MM/YY ou DD/MM
    final brMatch =
        RegExp(r'^(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?$').firstMatch(s);
    if (brMatch != null) {
      final d = int.parse(brMatch.group(1)!);
      final m = int.parse(brMatch.group(2)!);
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      int y = fallbackYear;
      if (brMatch.group(3) != null) {
        final rawY = int.parse(brMatch.group(3)!);
        y = rawY < 100 ? (2000 + rawY) : rawY;
      }
      return DateTime(y, m, d);
    }

    // DD MMM (ex.: '12 NOV' ou '05 fev')
    final ptMatch = RegExp(
      r'^(\d{1,2})\s+(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (ptMatch != null) {
      final d = int.parse(ptMatch.group(1)!);
      final m = _ptMonths[ptMatch.group(2)!.toLowerCase()] ?? 1;
      return DateTime(fallbackYear, m, d.clamp(1, 31));
    }

    return null;
  }

  static String _cleanTitleNoise(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-\•\*]+'), '')
        .trim();
    if (s.isEmpty) return 'Lançamento';
    return s;
  }
}

class _RawParsedRow {
  final String title;
  final DateTime date;
  final double amount;
  final bool isCreditOrRefund;

  const _RawParsedRow({
    required this.title,
    required this.date,
    required this.amount,
    required this.isCreditOrRefund,
  });
}
