import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';
import 'security_service.dart';

class GeminiTestResult {
  final bool success;
  final String message;

  const GeminiTestResult({required this.success, required this.message});
}

class GeminiService {
  static const String _keyGeminiApiKey = 'neves_gemini_api_key';
  static const String _defaultModel = 'gemini-3.8-flash';
  static String _activeModel = _defaultModel;
  static const List<String> candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];
  static const String _apiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String get activeModel => _activeModel;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @visibleForTesting
  static final Map<String, String> inMemorySecureStore = {};

  @visibleForTesting
  static String? mockResponseText;

  static Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (SecurityService.isTestEnvironment) {
      inMemorySecureStore[_keyGeminiApiKey] = trimmed;
      return;
    }
    try {
      await _secureStorage.write(key: _keyGeminiApiKey, value: trimmed);
    } catch (_) {
      inMemorySecureStore[_keyGeminiApiKey] = trimmed;
    }
  }

  static Future<String?> getApiKey() async {
    if (SecurityService.isTestEnvironment) {
      return inMemorySecureStore[_keyGeminiApiKey];
    }
    try {
      final key = await _secureStorage.read(key: _keyGeminiApiKey);
      return key ?? inMemorySecureStore[_keyGeminiApiKey];
    } catch (_) {
      return inMemorySecureStore[_keyGeminiApiKey];
    }
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  static Future<void> removeApiKey() async {
    if (SecurityService.isTestEnvironment) {
      inMemorySecureStore.remove(_keyGeminiApiKey);
      return;
    }
    try {
      await _secureStorage.delete(key: _keyGeminiApiKey);
      inMemorySecureStore.remove(_keyGeminiApiKey);
    } catch (_) {
      inMemorySecureStore.remove(_keyGeminiApiKey);
    }
  }

  static String maskApiKey(String? key) {
    if (key == null || key.trim().isEmpty) return 'Não configurada';
    final trimmed = key.trim();
    if (trimmed.length <= 10) return '••••••••••••';
    return '${trimmed.substring(0, 6)}••••••••••••${trimmed.substring(trimmed.length - 4)}';
  }

  static Future<GeminiTestResult> testConnection([String? specificKey]) async {
    final keyToTest = specificKey?.trim() ?? await getApiKey();
    if (keyToTest == null || keyToTest.isEmpty) {
      return const GeminiTestResult(
        success: false,
        message: 'Nenhuma chave informada para teste.',
      );
    }

    if (SecurityService.isTestEnvironment) {
      if (keyToTest.contains('invalid') || keyToTest.length < 5) {
        return const GeminiTestResult(
          success: false,
          message: 'Chave de API inválida ou não autorizada.',
        );
      }
      return const GeminiTestResult(
        success: true,
        message: 'Conexão com Gemini estabelecida com sucesso!',
      );
    }

    final modelsToTry = [
      _activeModel,
      ...candidateModels.where((m) => m != _activeModel),
    ];

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': 'Responda apenas com a palavra: OK'},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 5,
        'temperature': 0.0,
      },
    };

    final bodyJson = jsonEncode(payload);
    String lastError = '';

    for (final model in modelsToTry) {
      final endpoint = Uri.parse(
        '$_apiBaseUrl/$model:generateContent?key=$keyToTest',
      );

      try {
        final response = await http
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: bodyJson,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _activeModel = model;
          return GeminiTestResult(
            success: true,
            message: 'Conexão com Gemini validada com sucesso ($model)!',
          );
        }

        String errorMsg = 'Código ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final errorObj = decoded['error'] as Map<String, dynamic>?;
          if (errorObj != null && errorObj['message'] != null) {
            errorMsg = errorObj['message'].toString();
          }
        } catch (_) {}
        lastError = errorMsg;

        final lower = errorMsg.toLowerCase();
        if (response.statusCode == 400 &&
            (lower.contains('api key') || lower.contains('invalid'))) {
          break;
        }
        if (response.statusCode == 403) break;
      } catch (e) {
        lastError = e.toString();
      }
    }

    return GeminiTestResult(
      success: false,
      message: 'Falha ao testar conexão: $lastError',
    );
  }

  static Future<String> generateMonthlyFinancialInsight({
    required String yearMonth,
    required double totalIncome,
    required double totalExpense,
    required double projectedEndBalance,
    required double netWorth,
    required double essentialSpent,
    required double lifestyleSpent,
    required double futureSaved,
    required Map<String, double> categoryBreakdown,
    required double futureInstallmentsTotal,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await DatabaseService.getAiInsight(yearMonth);
      // Ignora cache antigo caso tenha sido salvo cortado (< 220 chars) ou com fragmentos em inglês
      if (cached != null &&
          cached.trim().length >= 220 &&
          !cached.contains('The Paradox') &&
          !cached.contains('Step 3:')) {
        return cached;
      }
    }

    if (SecurityService.isTestEnvironment && mockResponseText != null) {
      await DatabaseService.saveAiInsight(
        yearMonth: yearMonth,
        contentMd: mockResponseText!,
        model: _defaultModel,
      );
      return mockResponseText!;
    }

    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw StateError(
        'Chave da API do Gemini não configurada. Acesse Ajustes para cadastrar.',
      );
    }

    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100)
        : 0.0;

    final catLines = categoryBreakdown.entries
        .map((e) => '- ${e.key}: R\$ ${e.value.toStringAsFixed(2)}')
        .join('\n');

    final prompt = '''
Você é o Consultor Financeiro Pessoal do aplicativo Neves.
Analise os dados financeiros reais do mês ($yearMonth) abaixo e forneça um diagnóstico executivo completo, direto, empático e acionável, escrito 100% em português brasileiro (nunca responda em inglês).

RESUMO DO MÊS ($yearMonth):
- Receitas Totais: R\$ ${totalIncome.toStringAsFixed(2)}
- Despesas Totais: R\$ ${totalExpense.toStringAsFixed(2)}
- Taxa de Poupança do Mês: ${savingsRate.toStringAsFixed(1)}%
- Saldo Projetado para o Fim do Mês: R\$ ${projectedEndBalance.toStringAsFixed(2)}
- Patrimônio Líquido Consolidado (Net Worth): R\$ ${netWorth.toStringAsFixed(2)}
- Comprometimento com Parcelas Futuras de Cartão: R\$ ${futureInstallmentsTotal.toStringAsFixed(2)}

DISTRIBUIÇÃO 50 / 30 / 20:
- Essenciais (Meta 50%): R\$ ${essentialSpent.toStringAsFixed(2)}
- Estilo de Vida (Meta 30%): R\$ ${lifestyleSpent.toStringAsFixed(2)}
- Futuro & Reserva (Meta 20%): R\$ ${futureSaved.toStringAsFixed(2)}

DESPESAS POR CATEGORIA:
${catLines.isEmpty ? '- Sem despesas registradas neste mês.' : catLines}

DIRETRIZES DA RESPOSTA:
1. **Diagnóstico de Fluxo de Caixa e Regra 50/30/20**: Avalie o equilíbrio entre receitas e despesas e aponte se algum pilar da regra 50/30/20 está desajustado.
2. **Maiores Vilões e Cartão de Crédito**: Identifique as categorias que mais pesaram no orçamento e comente sobre o nível de parcelas futuras no cartão.
3. **Plano de Ação Prático (3 Passos)**: Sugira 3 ações concretas e realistas para otimizar a taxa de poupança e acelerar as metas financeiras no próximo mês.
4. Formate em Markdown limpo com subtítulos curtos, bullet points e entre 220 e 350 palavras. Entregue o texto completo até a conclusão.
''';

    final text = await _callGeminiApi(
      key: key,
      prompt: prompt,
      maxOutputTokens: 4096,
      temperature: 0.35,
    );

    await DatabaseService.saveAiInsight(
      yearMonth: yearMonth,
      contentMd: text,
      model: _activeModel,
    );

    return text;
  }

  /// Categoriza automaticamente uma lista de transações importadas (OFX/CSV/PDF) usando o Gemini IA.
  /// Retorna um mapa {indexDaTransacao: categoryId} apenas para os itens em que a IA encontrou correspondência válida.
  static Future<Map<int, String>> categorizeImportedTransactions({
    required List<ImportedTransactionCandidate> candidates,
    required List<CategoryModel> categories,
  }) async {
    if (candidates.isEmpty || categories.isEmpty) return {};

    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw StateError(
        'Chave da API do Gemini não configurada. Configure em Ajustes para usar a categorização por IA.',
      );
    }

    final expenseCats = categories
        .where((c) => c.type == TransactionType.expense)
        .map((c) => {'id': c.id, 'name': c.name})
        .toList();
    final incomeCats = categories
        .where((c) => c.type == TransactionType.income)
        .map((c) => {'id': c.id, 'name': c.name})
        .toList();

    final itemsPayload = <Map<String, dynamic>>[];
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      itemsPayload.add({
        'i': i,
        'title': c.title,
        'type': c.type == TransactionType.expense ? 'expense' : 'income',
        'amount': c.amount,
      });
    }

    if (itemsPayload.isEmpty) return {};

    final prompt = '''
Você é um especialista em categorização de extratos bancários e faturas de cartão no Brasil (Mercado Pago, Nubank, Itaú, Inter, Bradesco, C6).
Classifique cada lançamento em seu `id` de categoria exato, respeitando obrigatoriamente o campo `type` (`expense` -> apenas categorias de despesa; `income` -> apenas categorias de receita).

GUIA DE CATEGORIAS DO BRASIL:
- `cat_mercado` (Supermercado): APENAS supermercados, atacadistas, mercearias, hortifruti, açougues, conveniências (Assaí, Atacadão, Carrefour, Pão de Açúcar, Oxxo, Extra). ATENÇÃO: "Mercado Livre" e "Mercado Pago" NÃO são supermercado!
- `cat_compras` (Compras & Vestuário): Compras online e físicas, Mercado Livre, Shopee, Amazon, Shein, AliExpress, Magalu, Casas Bahia, Americanas, roupas (Renner, Riachuelo, C&A, Zara, Nike), eletrônicos, presentes, petshop, cosméticos e pagamentos/Pix para comércios ou prestadores diversos.
- `cat_restaurante` (Restaurantes & Delivery): iFood, Rappi, Zé Delivery, restaurantes, padarias, lanchonetes, hamburguerias, pizzarias, açaí, sorveterias, cafeterias, bares (McDonald's, BK, Outback, Cacau Show).
- `cat_transporte` (Transporte & Combustível): Uber, 99, táxi, postos de combustível (Shell, Ipiranga, Petrobras), estacionamento, pedágio (Sem Parar, Veloe, ConectCar), ônibus, metrô, manutenção/oficina.
- `cat_assinaturas` (Assinaturas & Apps): Streaming, serviços digitais, softwares e clubes (Netflix, Spotify, Prime, Disney+, HBO Max, YouTube, Apple/iCloud, Google Play/One, ChatGPT, Meli+).
- `cat_saude` (Saúde & Farmácia): Farmácias e drogarias (Drogasil, Raia, Pacheco, Pague Menos, Panvel), consultas médicas, exames, hospitais, planos de saúde (Unimed), dentista, academia (SmartFit, Wellhub/Gympass), barbearia/salão.
- `cat_educacao` (Educação & Cursos): Escola, faculdade, cursos online (Udemy, Alura, Hotmart, Kiwify), livros, livrarias, papelaria, idiomas.
- `cat_lazer` (Lazer & Viagens): Cinema, shows, ingressos (Sympla, Eventim), jogos (Steam, PlayStation, Xbox, Nintendo), hotéis, Airbnb, passagens aéreas (Latam, Gol, Azul), passeios.
- `cat_moradia` (Moradia & Contas): Aluguel, condomínio, luz/energia (Enel, CPFL, Light, Cemig), água (Sabesp, Copasa, Saneago), gás, internet/celular (Vivo, Claro, Tim), impostos (IPTU, IPVA, DARF), taxas/seguros.
- `cat_aportes` (Aportes & Futuro): Dinheiro guardado no Cofrinho/Caixinha/Reservas, aplicações em CDB, RDB, Tesouro Direto, FIIs, ações.
- `cat_salario` (Salário & Pró-Labore): Salário, folha de pagamento, pró-labore, adiantamento salarial (apenas para `income`).
- `cat_rendimentos` (Dividendos & Rendimentos): Rendimentos do Cofrinho/CDI, juros, dividendos, FIIs (apenas para `income`).
- `cat_outras_receitas` (Renda Extra & Reembolsos): Pix recebidos de terceiros/clientes, transferências recebidas, vendas, estornos, reembolsos, resgate de cofrinho (apenas para `income`).

CATEGORIAS DE DESPESA DISPONÍVEIS (`expense`):
${jsonEncode(expenseCats)}

CATEGORIAS DE RECEITA DISPONÍVEIS (`income`):
${jsonEncode(incomeCats)}

LANÇAMENTOS PARA CLASSIFICAR:
${jsonEncode(itemsPayload)}

Responda APENAS com um objeto JSON válido mapeando o índice "i" (como string) para o "id" exato da categoria escolhida.
Exemplo: {"0": "cat_compras", "1": "cat_restaurante"}
''';

    final rawResponse = await _callGeminiApi(
      key: key,
      prompt: prompt,
      maxOutputTokens: 8192,
      temperature: 0.0,
      responseMimeType: 'application/json',
    );

    String cleaned = rawResponse.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    final startBrace = cleaned.indexOf('{');
    final endBrace = cleaned.lastIndexOf('}');
    if (startBrace >= 0 && endBrace > startBrace) {
      cleaned = cleaned.substring(startBrace, endBrace + 1);
    }

    final validIds = categories.map((c) => c.id).toSet();
    final Map<int, String> result = {};

    try {
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final idx = int.tryParse(k);
        final catId = v?.toString();
        if (idx != null &&
            idx >= 0 &&
            idx < candidates.length &&
            catId != null &&
            validIds.contains(catId)) {
          result[idx] = catId;
        }
      });
    } catch (_) {}

    return result;
  }

  static Future<String> _callGeminiApi({
    required String key,
    required String prompt,
    int maxOutputTokens = 4096,
    double temperature = 0.35,
    String? responseMimeType,
  }) async {
    final modelsToTry = [
      _activeModel,
      ...candidateModels.where((m) => m != _activeModel),
    ];

    final generationConfig = <String, dynamic>{
      'maxOutputTokens': maxOutputTokens,
      'temperature': temperature,
    };
    if (responseMimeType != null) {
      generationConfig['responseMimeType'] = responseMimeType;
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': generationConfig,
    };

    final bodyJson = jsonEncode(payload);
    String lastError = '';

    for (final model in modelsToTry) {
      final endpoint = Uri.parse(
        '$_apiBaseUrl/$model:generateContent?key=$key',
      );

      try {
        final response = await http
            .post(
              endpoint,
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: bodyJson,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          _activeModel = model;
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = decoded['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw StateError('O modelo não gerou resposta.');
          }
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) {
            throw StateError('Conteúdo vazio do Gemini.');
          }

          // Filtra partes internas de raciocínio ("thought": true) dos modelos Gemini 2.5 / 3.x
          // e concatena todas as partes reais da resposta final.
          final nonThoughtTexts = <String>[];
          final allTexts = <String>[];
          for (final part in parts) {
            if (part is Map) {
              final txt = part['text']?.toString();
              if (txt != null && txt.trim().isNotEmpty) {
                allTexts.add(txt.trim());
                if (part['thought'] != true) {
                  nonThoughtTexts.add(txt.trim());
                }
              }
            }
          }

          final finalText = nonThoughtTexts.isNotEmpty
              ? nonThoughtTexts.join('\n\n').trim()
              : (allTexts.isNotEmpty ? allTexts.last : '');

          if (finalText.isEmpty) {
            throw StateError('Resposta vazia retornada pelo Gemini.');
          }
          return finalText;
        }

        String msg = 'Código ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final errorObj = decoded['error'] as Map<String, dynamic>?;
          if (errorObj != null && errorObj['message'] != null) {
            msg = errorObj['message'].toString();
          }
        } catch (_) {}
        lastError = msg;

        final lower = msg.toLowerCase();
        if (response.statusCode == 400 &&
            (lower.contains('api key') || lower.contains('invalid'))) {
          break;
        }
        if (response.statusCode == 403) {
          break;
        }

        continue;
      } catch (e) {
        if (kIsWeb) {
          throw StateError(
            'Bloqueio de CORS do navegador. O Google Gemini bloqueia chamadas diretas de browsers. Teste no Android ou inicie o Chrome com --disable-web-security.',
          );
        }
        lastError = e.toString();
        continue;
      }
    }

    throw StateError('Erro retornado pela API do Gemini: $lastError');
  }
}
