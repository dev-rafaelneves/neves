import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/models.dart';

/// Serviço local para importação de extratos e faturas em formato OFX, CSV ou texto extraído de PDF,
/// com detecção de duplicatas via hash SHA-256 e sugestão inteligente de categoria por histórico/palavras-chave.
class ImportService {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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
      candidate.suggestedCategoryId = suggestCategory(
        title: candidate.title,
        type: candidate.type,
        categories: categories,
        existingTransactions: existingTransactions,
      );
    }

    return rawCandidates;
  }

  /// Inverte Receita <-> Despesa de todos os candidatos e recalcula a sugestão de categoria
  static void invertAllCandidateTypes({
    required List<ImportedTransactionCandidate> candidates,
    required List<CategoryModel> categories,
    required List<TransactionModel> existingTransactions,
  }) {
    for (final c in candidates) {
      c.type = c.type == TransactionType.expense
          ? TransactionType.income
          : TransactionType.expense;
      c.suggestedCategoryId = suggestCategory(
        title: c.title,
        type: c.type,
        categories: categories,
        existingTransactions: existingTransactions,
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

    String? findByIdOrKeyword(String preferredId, String nameFragment) {
      for (final c in validCats) {
        if (c.id == preferredId) return c.id;
      }
      for (final c in validCats) {
        if (c.name.toLowerCase().contains(nameFragment)) return c.id;
      }
      return null;
    }

    if (type == TransactionType.income) {
      if (lower.contains('salário') ||
          lower.contains('salario') ||
          lower.contains('folha') ||
          lower.contains('pro-labore') ||
          lower.contains('pró-labore') ||
          lower.contains('adiantamento salarial')) {
        return findByIdOrKeyword('cat_salario', 'salário') ??
            validCats.first.id;
      }
      if (lower.contains('dividendo') ||
          lower.contains('rendimento') ||
          lower.contains('juros') ||
          lower.contains('jcp') ||
          lower.contains('fii') ||
          lower.contains('cdb') ||
          lower.contains('remuneração') ||
          lower.contains('remuneracao')) {
        return findByIdOrKeyword('cat_rendimentos', 'rendimento') ??
            validCats.first.id;
      }
      return findByIdOrKeyword('cat_outras_receitas', 'renda extra') ??
          validCats.last.id;
    }

    // 1. Aportes, Cofrinho e Investimentos
    if (lower.contains('cofrinho') ||
        lower.contains('caixinha') ||
        lower.contains('reserva') ||
        lower.contains('aporte') ||
        lower.contains('investimento') ||
        lower.contains('tesouro') ||
        lower.contains('cdb') ||
        lower.contains('rdb') ||
        lower.contains('poupança') ||
        lower.contains('poupanca')) {
      return findByIdOrKeyword('cat_aportes', 'aportes');
    }

    // 2. E-commerce, Lojas e Compras (antes de "mercado" para que "Mercado Livre" / "Mercado Pago" não caia em Supermercado)
    if (lower.contains('mercado livre') ||
        lower.contains('mercadolivre') ||
        lower.contains('meli') ||
        lower.contains('shopee') ||
        lower.contains('shpp') ||
        lower.contains('amazon') ||
        lower.contains('shein') ||
        lower.contains('aliexpress') ||
        lower.contains('magalu') ||
        lower.contains('magazine') ||
        lower.contains('casas bahia') ||
        lower.contains('americanas') ||
        lower.contains('renner') ||
        lower.contains('riachuelo') ||
        lower.contains('cea') ||
        lower.contains('c&a') ||
        lower.contains('zara') ||
        lower.contains('centauro') ||
        lower.contains('nike') ||
        lower.contains('adidas') ||
        lower.contains('decathlon') ||
        lower.contains('kabum') ||
        lower.contains('pichau') ||
        lower.contains('kalunga') ||
        lower.contains('leroy') ||
        lower.contains('boticario') ||
        lower.contains('boticário') ||
        lower.contains('natura') ||
        lower.contains('sephora') ||
        lower.contains('petz') ||
        lower.contains('cobasi') ||
        lower.contains('petshop') ||
        lower.contains('loja ')) {
      return findByIdOrKeyword('cat_compras', 'compras');
    }

    // 3. Transporte, Apps de Mobilidade e Combustível
    if (lower.contains('uber') ||
        lower.contains('99app') ||
        lower.contains('99*') ||
        lower.contains('99 pop') ||
        lower.contains('99taxi') ||
        lower.contains('indriver') ||
        lower.contains('taxi') ||
        lower.contains('táxi') ||
        lower.contains('posto') ||
        lower.contains('combust') ||
        lower.contains('gasolina') ||
        lower.contains('etanol') ||
        lower.contains('shell') ||
        lower.contains('ipiranga') ||
        lower.contains('petrobras') ||
        lower.contains('auto posto') ||
        lower.contains('estacionamento') ||
        lower.contains('estapar') ||
        lower.contains('indigo') ||
        lower.contains('sem parar') ||
        lower.contains('semparar') ||
        lower.contains('veloe') ||
        lower.contains('conectcar') ||
        lower.contains('pedagio') ||
        lower.contains('pedágio') ||
        lower.contains('metro') ||
        lower.contains('metrô') ||
        lower.contains('onibus') ||
        lower.contains('ônibus') ||
        lower.contains('bilhete unico') ||
        lower.contains('oficina') ||
        lower.contains('pneu') ||
        lower.contains('localiza') ||
        lower.contains('movida') ||
        lower.contains('unidas')) {
      return findByIdOrKeyword('cat_transporte', 'transporte');
    }

    // 4. Restaurantes, Delivery, Padarias e Lanches
    if (lower.contains('ifood') ||
        lower.contains('ifd*') ||
        lower.contains('rappi') ||
        lower.contains('ze delivery') ||
        lower.contains('zé delivery') ||
        lower.contains('aiqfome') ||
        lower.contains('restaurante') ||
        lower.contains('padaria') ||
        lower.contains('panificadora') ||
        lower.contains('confeitaria') ||
        lower.contains('lanch') ||
        lower.contains('burger') ||
        lower.contains('hamburgueria') ||
        lower.contains('mcdonald') ||
        lower.contains('mc donald') ||
        lower.contains('bk ') ||
        lower.contains('burger king') ||
        lower.contains('outback') ||
        lower.contains('madero') ||
        lower.contains('jeronimo') ||
        lower.contains('subway') ||
        lower.contains('habib') ||
        lower.contains('bobs') ||
        lower.contains('spoleto') ||
        lower.contains('coco bambu') ||
        lower.contains('pizza') ||
        lower.contains('sushi') ||
        lower.contains('temaki') ||
        lower.contains('acai') ||
        lower.contains('açaí') ||
        lower.contains('sorvete') ||
        lower.contains('gelato') ||
        lower.contains('cafe') ||
        lower.contains('café') ||
        lower.contains('starbucks') ||
        lower.contains('cacau show') ||
        lower.contains('kopenhagen') ||
        lower.contains('churrascaria') ||
        lower.contains('espetinho') ||
        lower.contains('bar ') ||
        lower.contains('choperia') ||
        lower.contains('doceria')) {
      return findByIdOrKeyword('cat_restaurante', 'restaurante');
    }

    // 5. Supermercado, Atacadistas, Mercearias e Conveniência
    final isMercadoPagoOrLivre = lower.contains('mercado pago') ||
        lower.contains('mercadopago') ||
        lower.contains('mercado livre') ||
        lower.contains('mercadolivre');
    if ((!isMercadoPagoOrLivre && lower.contains('mercado')) ||
        lower.contains('supermercado') ||
        lower.contains('atacad') ||
        lower.contains('carrefour') ||
        lower.contains('assai') ||
        lower.contains('assaí') ||
        lower.contains('pao de acucar') ||
        lower.contains('pão de açúcar') ||
        lower.contains('hortifruti') ||
        lower.contains('sacolao') ||
        lower.contains('sacolão') ||
        lower.contains('acougue') ||
        lower.contains('açougue') ||
        lower.contains('mercearia') ||
        lower.contains('oxxo') ||
        lower.contains('muffato') ||
        lower.contains('condor') ||
        lower.contains('angeloni') ||
        lower.contains('zaffari') ||
        lower.contains('guanabara') ||
        lower.contains('mundial') ||
        lower.contains('sonda') ||
        lower.contains('savegnago') ||
        lower.contains('covabra') ||
        lower.contains('tenda') ||
        lower.contains('swift') ||
        lower.contains('emporio') ||
        lower.contains('empório')) {
      return findByIdOrKeyword('cat_mercado', 'mercado');
    }

    // 6. Assinaturas, Streaming e Serviços Digitais
    if (lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('amazon prime') ||
        lower.contains('prime video') ||
        lower.contains('icloud') ||
        lower.contains('apple.com/bill') ||
        lower.contains('google one') ||
        lower.contains('google play') ||
        lower.contains('youtube') ||
        lower.contains('chatgpt') ||
        lower.contains('openai') ||
        lower.contains('claude') ||
        lower.contains('anthropic') ||
        lower.contains('disney') ||
        lower.contains('hbo') ||
        lower.contains('max') ||
        lower.contains('globoplay') ||
        lower.contains('paramount') ||
        lower.contains('crunchyroll') ||
        lower.contains('deezer') ||
        lower.contains('canva') ||
        lower.contains('adobe') ||
        lower.contains('microsoft') ||
        lower.contains('meli+') ||
        lower.contains('assinatura')) {
      return findByIdOrKeyword('cat_assinaturas', 'assinatura');
    }

    // 7. Saúde, Farmácia, Academia e Cuidados Pessoais
    if (lower.contains('farmacia') ||
        lower.contains('farmácia') ||
        lower.contains('droga') ||
        lower.contains('drogaria') ||
        lower.contains('drogasil') ||
        lower.contains('raia') ||
        lower.contains('pacheco') ||
        lower.contains('pague menos') ||
        lower.contains('panvel') ||
        lower.contains('araujo') ||
        lower.contains('araújo') ||
        lower.contains('nissei') ||
        lower.contains('extrafarma') ||
        lower.contains('hospital') ||
        lower.contains('unimed') ||
        lower.contains('amil') ||
        lower.contains('sulamerica') ||
        lower.contains('hapvida') ||
        lower.contains('medico') ||
        lower.contains('médico') ||
        lower.contains('consulta') ||
        lower.contains('clinica') ||
        lower.contains('clínica') ||
        lower.contains('laboratorio') ||
        lower.contains('laboratório') ||
        lower.contains('exame') ||
        lower.contains('fleury') ||
        lower.contains('dasa') ||
        lower.contains('dentista') ||
        lower.contains('odonto') ||
        lower.contains('psicolog') ||
        lower.contains('terapia') ||
        lower.contains('smartfit') ||
        lower.contains('smart fit') ||
        lower.contains('bluefit') ||
        lower.contains('bodytech') ||
        lower.contains('academia') ||
        lower.contains('gympass') ||
        lower.contains('wellhub') ||
        lower.contains('totalpass') ||
        lower.contains('suplemento') ||
        lower.contains('barbearia') ||
        lower.contains('salao') ||
        lower.contains('salão')) {
      return findByIdOrKeyword('cat_saude', 'saúde');
    }

    // 8. Educação, Cursos e Livros
    if (lower.contains('escola') ||
        lower.contains('colégio') ||
        lower.contains('colegio') ||
        lower.contains('faculdade') ||
        lower.contains('universidade') ||
        lower.contains('curso') ||
        lower.contains('udemy') ||
        lower.contains('alura') ||
        lower.contains('rocketseat') ||
        lower.contains('hotmart') ||
        lower.contains('kiwify') ||
        lower.contains('eduzz') ||
        lower.contains('livraria') ||
        lower.contains('saraiva') ||
        lower.contains('papelaria')) {
      return findByIdOrKeyword('cat_educacao', 'educação');
    }

    // 9. Lazer, Cinema, Jogos e Viagens
    if (lower.contains('cinema') ||
        lower.contains('cinemark') ||
        lower.contains('ingresso') ||
        lower.contains('sympla') ||
        lower.contains('eventim') ||
        lower.contains('show') ||
        lower.contains('teatro') ||
        lower.contains('steam') ||
        lower.contains('playstation') ||
        lower.contains('xbox') ||
        lower.contains('nintendo') ||
        lower.contains('riot') ||
        lower.contains('hotel') ||
        lower.contains('pousada') ||
        lower.contains('airbnb') ||
        lower.contains('booking') ||
        lower.contains('decolar') ||
        lower.contains('latam') ||
        lower.contains('azul') ||
        lower.contains('gol ') ||
        lower.contains('passagem') ||
        lower.contains('viagem')) {
      return findByIdOrKeyword('cat_lazer', 'lazer');
    }

    // 10. Moradia, Contas Residenciais, Telefonia e Impostos
    if (lower.contains('aluguel') ||
        lower.contains('quintoandar') ||
        lower.contains('quinto andar') ||
        lower.contains('condominio') ||
        lower.contains('condomínio') ||
        lower.contains('energia') ||
        lower.contains('eletricidade') ||
        lower.contains('enel') ||
        lower.contains('cpfl') ||
        lower.contains('light') ||
        lower.contains('cemig') ||
        lower.contains('copel') ||
        lower.contains('celesc') ||
        lower.contains('equatorial') ||
        lower.contains('neoenergia') ||
        lower.contains('sabesp') ||
        lower.contains('saneago') ||
        lower.contains('copasa') ||
        lower.contains('sanepar') ||
        lower.contains('embasa') ||
        lower.contains('cedae') ||
        lower.contains('comgas') ||
        lower.contains('ultragaz') ||
        lower.contains('vivo') ||
        lower.contains('claro') ||
        lower.contains('tim') ||
        lower.contains('internet') ||
        lower.contains('iptu') ||
        lower.contains('ipva') ||
        lower.contains('darf') ||
        lower.contains('imposto') ||
        lower.contains('tarifa') ||
        lower.contains('iof') ||
        lower.contains('seguro')) {
      return findByIdOrKeyword('cat_moradia', 'moradia');
    }

    // Fallback padrão para compras/pagamentos diversos: Compras & Vestuário (em vez de Moradia)
    return findByIdOrKeyword('cat_compras', 'compras') ?? validCats.first.id;
  }
}
