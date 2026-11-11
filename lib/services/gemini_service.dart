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
  static const String _defaultModel = 'gemini-2.5-flash';
  static String _activeModel = _defaultModel;
  static const List<String> candidateModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
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
      if (cached != null && cached.isNotEmpty) {
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
Analise os dados financeiros reais do mês ($yearMonth) abaixo e forneça um diagnóstico executivo, direto, empático e acionável em português brasileiro.

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
4. Formate em Markdown limpo com subtítulos curtos, bullet points e no máximo 320 palavras.
''';

    final text = await _callGeminiApi(key: key, prompt: prompt);

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

    final prompt = '''
Você é um classificador inteligente de extratos bancários e faturas de cartão no Brasil (Nubank, Itaú, Inter, Bradesco, C6, etc.).
Associe cada lançamento abaixo ao `id` da categoria mais adequada, respeitando o tipo (`expense` usa apenas CATEGORIAS DE DESPESA; `income` usa apenas CATEGORIAS DE RECEITA).

CATEGORIAS DE DESPESA (expense):
${jsonEncode(expenseCats)}

CATEGORIAS DE RECEITA (income):
${jsonEncode(incomeCats)}

LANÇAMENTOS PARA CLASSIFICAR:
${jsonEncode(itemsPayload)}

Responda APENAS com um objeto JSON válido (sem blocos markdown ```json e sem texto extra) mapeando o índice "i" (como string) para o "id" exato da categoria escolhida.
Exemplo de formato esperado:
{"0": "cat_mercado", "1": "cat_transporte"}
''';

    final rawResponse = await _callGeminiApi(
      key: key,
      prompt: prompt,
      maxOutputTokens: 1200,
      temperature: 0.1,
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
    int maxOutputTokens = 750,
    double temperature = 0.35,
  }) async {
    final modelsToTry = [
      _activeModel,
      ...candidateModels.where((m) => m != _activeModel),
    ];

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'temperature': temperature,
      },
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
            .timeout(const Duration(seconds: 25));

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
          final text = parts.first['text'] as String?;
          return text?.trim() ?? 'Sem resposta.';
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

        if (response.statusCode == 400 || response.statusCode == 403) break;
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw StateError('Erro retornado pela API do Gemini: $lastError');
  }
}
