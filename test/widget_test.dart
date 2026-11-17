import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:neves/main.dart';
import 'package:neves/models/models.dart';
import 'package:neves/services/app_state.dart';
import 'package:neves/services/database_service.dart';
import 'package:neves/services/import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseService.instance.enableInMemoryModeForTest();
  });

  test('Matemática do mês: Receitas, À Vista, Fatura de Cartão e Parcelas',
      () async {
    final state = AppState();
    await state.initialize();
    state.setSelectedYearMonth('2026-11');

    // 1. Receita de R$ 5.000,00 em Novembro/2026
    await state.createTransaction(
      title: 'Salário',
      totalAmount: 5000.00,
      date: DateTime(2026, 11, 5),
      type: TransactionType.income,
      paymentMethod: PaymentMethod.cash,
      categoryId: 'cat_salary',
      firstCompetenceMonth: '2026-11',
    );

    // 2. Despesa à Vista (Pix) de R$ 1.200,00 em Novembro/2026
    await state.createTransaction(
      title: 'Aluguel',
      totalAmount: 1200.00,
      date: DateTime(2026, 11, 10),
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.cash,
      categoryId: 'cat_home',
      firstCompetenceMonth: '2026-11',
    );

    // 3. Compra parcelada no Cartão de R$ 100,00 em 3x (1ª fatura em 2026-11)
    final cardId = state.cards.first.id;
    await state.createTransaction(
      title: 'Tênis',
      totalAmount: 100.00,
      date: DateTime(2026, 11, 12),
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.creditCard,
      categoryId: 'cat_shopping',
      cardId: cardId,
      firstCompetenceMonth: '2026-11',
      installments: 3,
    );

    // Verifica Novembro/2026 (1ª parcela absorve diferença de centavos: 33,34)
    expect(state.monthIncome('2026-11'), 5000.00);
    expect(state.monthCashExpense('2026-11'), 1200.00);
    expect(state.monthCardExpense('2026-11'), 33.34);
    expect(state.monthTotalExpense('2026-11'), 1233.34);
    expect(state.monthBalance('2026-11'), closeTo(3766.66, 0.001));

    // Verifica Dezembro/2026 e Janeiro/2027 (parcelas 2/3 e 3/3 = 33,33)
    expect(state.monthCardExpense('2026-12'), 33.33);
    expect(state.monthCardExpense('2027-01'), 33.33);
  });

  test('Sugestão automática de fatura pelo dia de fechamento', () {
    const card = CreditCardItem(
      id: 'c1',
      name: 'Nubank',
      colorValue: 0xFF8B5CF6,
      closingDay: 25,
      dueDay: 5,
    );

    expect(card.suggestInvoiceMonth(DateTime(2026, 11, 24)), '2026-11');
    expect(card.suggestInvoiceMonth(DateTime(2026, 11, 25)), '2026-12');
  });

  test(
      'Importador Unificado: Fatura com parcelas futuras, estorno e filtro de pagamento/cofrinho',
      () async {
    final state = AppState();
    await state.initialize();
    final cardId = state.cards.first.id;

    // 1. Importa Fatura de Novembro/2026
    const invoiceText = '''
05/11 Pagamento recebido -500,00
10/11 Supermercado Extra 150,00
12/11 Shopee 2/4 80,00
14/11 Estorno Shopee -30,00
''';

    final invoiceCandidates = ImportService.parseContent(
      content: invoiceText,
      defaultDestination: ImportDestinationType.creditCard,
      selectedInvoiceMonth: '2026-11',
      defaultCardId: cardId,
      categories: state.categories,
      existingTransactions: state.allTransactions,
    );

    expect(invoiceCandidates.length, 4);
    // 'Pagamento recebido' deve ser ignorado e desmarcado automaticamente
    expect(invoiceCandidates[0].ignoreReason, 'Pagamento de fatura');
    expect(invoiceCandidates[0].selected, isFalse);

    // 'Shopee 2/4' deve identificar parcela 2/4 e habilitar projeção futura (3/4 e 4/4)
    expect(invoiceCandidates[2].installmentIndex, 2);
    expect(invoiceCandidates[2].installmentTotal, 4);
    expect(invoiceCandidates[2].projectFutureInstallments, isTrue);

    // 'Estorno Shopee -30,00' deve entrar como estorno/crédito na fatura
    expect(invoiceCandidates[3].isCreditOrRefund, isTrue);
    expect(invoiceCandidates[3].selected, isTrue);

    final savedInvoiceCount = await state.commitImportedCandidates(
      candidates: invoiceCandidates,
      selectedInvoiceMonth: '2026-11',
    );
    // 3 itens de Novembro (150, 80, -30) + 2 parcelas futuras (3/4 em Dez e 4/4 em Jan) = 5 registros
    expect(savedInvoiceCount, 5);
    expect(state.cardInvoiceTotal(cardId, '2026-11'), closeTo(200.00, 0.001));
    expect(state.cardInvoiceTotal(cardId, '2026-12'), closeTo(80.00, 0.001));
    expect(state.cardInvoiceTotal(cardId, '2027-01'), closeTo(80.00, 0.001));

    // 2. Quando importar a fatura de Dezembro/2026 contendo 'Shopee 3/4', deve detectar duplicata!
    const decInvoiceText = '12/12 Shopee 3/4 80,00';
    final decCandidates = ImportService.parseContent(
      content: decInvoiceText,
      defaultDestination: ImportDestinationType.creditCard,
      selectedInvoiceMonth: '2026-12',
      defaultCardId: cardId,
      categories: state.categories,
      existingTransactions: state.allTransactions,
    );
    expect(decCandidates.single.isDuplicate, isTrue);
    expect(decCandidates.single.selected, isFalse);

    // 3. Importa Extrato de Conta Corrente (CSV) com Salário, Pix e Cofrinho
    const checkingCsv = '''
2026-11-05;Salário Empresa;4000,00
2026-11-08;Uber Viagem;-25,50
2026-11-09;Aplicação RDB Cofrinho;-300,00
2026-11-10;Pagamento de fatura;-200,00
''';

    final checkingCandidates = ImportService.parseContent(
      content: checkingCsv,
      defaultDestination: ImportDestinationType.checking,
      selectedInvoiceMonth: '2026-11',
      categories: state.categories,
      existingTransactions: state.allTransactions,
    );

    expect(checkingCandidates.length, 4);
    expect(checkingCandidates[0].isCreditOrRefund, isTrue); // Salário (+)
    expect(checkingCandidates[1].isCreditOrRefund, isFalse); // Uber (-)
    expect(checkingCandidates[2].ignoreReason, 'Cofrinho / Investimento');
    expect(checkingCandidates[2].selected, isFalse);
    expect(checkingCandidates[3].ignoreReason, 'Pagamento de fatura');
    expect(checkingCandidates[3].selected, isFalse);

    await state.commitImportedCandidates(
      candidates: checkingCandidates,
      selectedInvoiceMonth: '2026-11',
    );

    expect(state.monthIncome('2026-11'), closeTo(4000.00, 0.001));
    expect(state.monthCashExpense('2026-11'), closeTo(25.50, 0.001));
    // Saldo de Novembro = 4000 - (25,50 à vista + 200,00 fatura) = 3774,50
    expect(state.monthBalance('2026-11'), closeTo(3774.50, 0.001));
  });

  testWidgets('Renderiza as 3 abas do MVP e o botão de Importar',
      (WidgetTester tester) async {
    final state = AppState();
    await state.initialize();

    await tester.pumpWidget(NevesMvpApp(appState: state));
    await tester.pumpAndSettle();

    // Aba 1: Resumo
    expect(find.text('QUANTO SOBRA NO MÊS'), findsOneWidget);
    expect(find.text('Gasto'), findsOneWidget);
    expect(find.text('Receita'), findsOneWidget);
    expect(find.text('Importar'), findsOneWidget);

    // Navega para Aba 2: Extrato
    await tester.tap(find.text('Extrato'));
    await tester.pumpAndSettle();
    expect(find.text('À Vista (Pix)'), findsOneWidget);

    // Navega para Aba 3: Cartões & Ajustes
    await tester.tap(find.text('Cartões & Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Novo Cartão'), findsOneWidget);
    expect(find.text('Nova Categoria'), findsOneWidget);

    // Edita o Cartão Principal para 'Nubank Ultravioleta'
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar Cartão'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Cartão Principal'),
      'Nubank Ultravioleta',
    );
    await tester.tap(find.text('Salvar Cartão'));
    await tester.pumpAndSettle();
    expect(find.text('Nubank Ultravioleta'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Exportar Backup (JSON)'),
      200,
    );
    expect(find.text('Exportar Backup (JSON)'), findsOneWidget);
  });
}
