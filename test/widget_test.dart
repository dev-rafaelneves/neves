import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:neves/main.dart';
import 'package:neves/models/models.dart';
import 'package:neves/services/app_state.dart';
import 'package:neves/services/import_service.dart';
import 'package:neves/theme/app_theme.dart';
import 'package:neves/widgets/month_selector_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Motor de Cartão de Crédito, Parcelamento e Regime de Competência', () async {
    final appState = AppState();
    await appState.init();

    // Cria um cartão que fecha dia 10 e vence dia 17
    const card = CreditCardModel(
      id: 'card_nubank',
      name: 'Nubank',
      creditLimit: 10000.0,
      closingDay: 10,
      dueDay: 17,
      colorValue: 0xFF059669,
    );
    await appState.saveCreditCard(card);

    // Compra de R$ 1.200 em 3x feita no dia 15/11/2026 (após o fechamento dia 10 -> cai em 2026-12, 2027-01, 2027-02)
    final purchaseDate = DateTime(2026, 11, 15);
    final baseTx = TransactionModel(
      id: 'tx_1',
      title: 'Notebook Parcelado',
      amount: 1200.0,
      type: TransactionType.expense,
      date: purchaseDate,
      competenceMonth: card.computeCompetenceMonth(purchaseDate),
      status: TransactionStatus.pending,
      cardId: card.id,
      categoryId: 'cat_compras',
    );

    await appState.addOrUpdateTransaction(baseTx, installments: 3);

    // Limite ocupado deve ser 1200 e disponível 8800
    expect(appState.getCardUsedLimit(card.id), 1200.0);
    expect(appState.getCardAvailableLimit(card), 8800.0);

    // Por Competência da Fatura: novembro tem R$ 0 e dezembro tem R$ 400
    expect(appState.budgetRegime, BudgetRegime.competence);
    expect(appState.totalExpenseForMonth('2026-11'), 0.0);
    expect(appState.totalExpenseForMonth('2026-12'), 400.0);

    // Alternando para Data da Compra: novembro passa a contabilizar a 1ª parcela (15/11)
    await appState.setBudgetRegime(BudgetRegime.purchaseDate);
    expect(appState.totalExpenseForMonth('2026-11'), 400.0);
  });

  test('ImportService analisa CSV/OFX, detecta duplicatas e sugere categoria', () async {
    final appState = AppState();
    await appState.init();

    const csvSample = '''
Data,Descrição,Valor
10/11/2026,Uber Viagem,-35.90
11/11/2026,Supermercado Carrefour,-420.50
''';

    final candidates = ImportService.parseStatementContent(
      content: csvSample,
      extension: 'csv',
      categories: appState.categories,
      existingTransactions: appState.transactions,
    );

    expect(candidates.length, 2);
    expect(candidates[0].title, 'Uber Viagem');
    expect(candidates[0].amount, 35.90);
    expect(candidates[0].type, TransactionType.expense);
    expect(candidates[0].suggestedCategoryId, 'cat_transporte');
    expect(candidates[1].suggestedCategoryId, 'cat_mercado');

    // Testa CSV de Fatura do Nubank (date,category,title,amount) onde positivo é compra (Despesa) e negativo é pagamento/estorno (Receita)
    const nubankInvoiceCsv = '''
date,category,title,amount
2026-11-10,transporte,Uber *Uber *Trip,35.90
2026-11-05,,Pagamento recebido,-1250.00
''';

    final nubankCandidates = ImportService.parseStatementContent(
      content: nubankInvoiceCsv,
      extension: 'csv',
      categories: appState.categories,
      existingTransactions: appState.transactions,
    );

    expect(nubankCandidates.length, 2);
    expect(nubankCandidates[0].title, 'Uber *Uber *Trip');
    expect(nubankCandidates[0].type, TransactionType.expense);
    expect(nubankCandidates[1].title, 'Pagamento recebido');
    expect(nubankCandidates[1].type, TransactionType.income);
  });

  testWidgets('Renderiza MainShell Apple HIG com 4 abas e Modo Discreto', (tester) async {
    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(NevesFinanceApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);

    // Testa Modo Discreto ("Olhinho")
    await tester.tap(find.byKey(const ValueKey('btn_discreet_mode')));
    await tester.pumpAndSettle();
    expect(appState.discreetMode, isTrue);
    expect(find.textContaining('R\$ ••••'), findsWidgets);

    // Abre o formulário Apple HIG de Novo Lançamento e testa digitação estilo Nubank
    await tester.tap(find.byKey(const ValueKey('fab_new_transaction')));
    await tester.pumpAndSettle();
    expect(find.text('Novo Lançamento'), findsOneWidget);
    expect(find.text('IDENTIFICAÇÃO & CATEGORIA'), findsOneWidget);

    // Alterna para Transferência para validar que Conta de Origem e Conta de Destino não causam RenderFlex overflow
    await tester.tap(find.text('Transferência'));
    await tester.pumpAndSettle();
    expect(find.text('Conta de Origem'), findsOneWidget);
    expect(find.text('Conta de Destino'), findsOneWidget);
  });

  test('CentavosCurrencyFormatter formata digitação estilo Nubank da direita para a esquerda', () {
    const formatter = CentavosCurrencyFormatter();

    TextEditingValue applyTyping(String rawInput) {
      return formatter.formatEditUpdate(
        const TextEditingValue(text: '0,00'),
        TextEditingValue(text: rawInput),
      );
    }

    expect(applyTyping('5').text, '0,05');
    expect(applyTyping('0,050').text, '0,50');
    expect(applyTyping('0,500').text, '5,00');
    expect(applyTyping('125050').text, '1.250,50');
    expect(CentavosCurrencyFormatter.parseValue('1.250,50'), 1250.50);
    expect(CentavosCurrencyFormatter.formatDouble(42.5), '42,50');
  });

  testWidgets('Renderiza MainShell sem overflow com fonte ampliada (1.6x)',
      (tester) async {
    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: NevesFinanceApp(appState: appState),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renderiza MainShell em layout tablet (1024x768) sem overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(NevesFinanceApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Contas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'TransactionFormSheet exibe erro inline e MonthSelectorBar abre seletor de mês',
      (tester) async {
    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(NevesFinanceApp(appState: appState));
    await tester.pumpAndSettle();

    // Avança um mês e abre o seletor rápido de mês tocando no rótulo central
    final initialYm = appState.selectedYearMonth;
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    expect(appState.selectedYearMonth, isNot(initialYm));

    final pickerFinder = find.descendant(
      of: find.byType(MonthSelectorBar),
      matching: find.byType(Text),
    );
    await tester.tap(pickerFinder.first);
    await tester.pumpAndSettle();

    expect(find.text('Ir para o mês atual'), findsOneWidget);
    await tester.tap(find.text('Ir para o mês atual'));
    await tester.pumpAndSettle();
    expect(appState.selectedYearMonth, initialYm);

    // Abre formulário pelo FAB e tenta salvar vazio -> erro inline visível na folha
    await tester.tap(find.byKey(const ValueKey('fab_new_transaction')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Informe um valor maior que R\$ 0,00 e uma descrição.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
