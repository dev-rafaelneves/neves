import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:neves/main.dart';
import 'package:neves/models/models.dart';
import 'package:neves/services/app_state.dart';
import 'package:neves/services/backup_service.dart';
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

  test('BackupService gera relatório textual de conciliação completo', () async {
    final appState = AppState();
    await appState.init();

    final report = BackupService.instance.buildReconciliationReport(appState);

    expect(report, contains('RELATÓRIO DE CONCILIAÇÃO FINANCEIRA — NEVES'));
    expect(report, contains('1. RESUMO GERAL'));
    expect(report, contains('2. CONTAS BANCÁRIAS'));
    expect(report, contains('3. CARTÕES DE CRÉDITO'));
    expect(report, contains('5. LANÇAMENTOS'));
  });

  test('Crédito/estorno no cartão abate fatura e Caixinha não infla receitas/despesas',
      () async {
    final appState = AppState();
    await appState.init();

    const account = Account(
      id: 'acc_mp',
      name: 'Mercado Pago',
      type: AccountType.checking,
      initialBalance: 100.0,
      currentBalance: 100.0,
      colorValue: 0xFF059669,
      iconName: 'account_balance',
    );
    await appState.saveAccount(account);

    const card = CreditCardModel(
      id: 'card_nb',
      name: 'Nubank',
      creditLimit: 5000.0,
      closingDay: 28,
      dueDay: 4,
      colorValue: 0xFF059669,
    );
    await appState.saveCreditCard(card);

    const goal = GoalModel(
      id: 'goal_emg',
      name: 'Emergência',
      targetAmount: 1000.0,
      currentAmount: 0.0,
      colorValue: 0xFF10B981,
      iconName: 'savings',
    );
    await appState.saveGoal(goal);

    // Compra R$ 200 e crédito/pagamento antecipado R$ 75 no cartão -> fatura líquida R$ 125
    await appState.addOrUpdateTransaction(
      TransactionModel(
        id: 'c1',
        title: 'Compra',
        amount: 200.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 10),
        competenceMonth: '2026-11',
        status: TransactionStatus.pending,
        cardId: card.id,
        categoryId: 'cat_compras',
      ),
    );
    await appState.addOrUpdateTransaction(
      TransactionModel(
        id: 'c2',
        title: 'Pagamento recebido',
        amount: 75.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 11),
        competenceMonth: '2026-11',
        status: TransactionStatus.pending,
        cardId: card.id,
        categoryId: 'cat_outras_receitas',
      ),
    );

    // Aporte R$ 50 na Caixinha, Resgate R$ 20, Rendimento R$ 5
    await appState.addOrUpdateTransaction(
      TransactionModel(
        id: 'g1',
        title: 'Aporte Cofrinho',
        amount: 50.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 12),
        competenceMonth: '2026-11',
        status: TransactionStatus.paid,
        accountId: account.id,
        categoryId: 'cat_aportes',
        goalId: goal.id,
        tags: const ['cofrinho_aporte'],
      ),
    );
    await appState.addOrUpdateTransaction(
      TransactionModel(
        id: 'g2',
        title: 'Resgate Cofrinho',
        amount: 20.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 13),
        competenceMonth: '2026-11',
        status: TransactionStatus.paid,
        accountId: account.id,
        categoryId: 'cat_outras_receitas',
        goalId: goal.id,
        tags: const ['resgate_cofrinho'],
      ),
    );
    await appState.addOrUpdateTransaction(
      TransactionModel(
        id: 'g3',
        title: 'Rendimento Cofrinho',
        amount: 5.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 14),
        competenceMonth: '2026-11',
        status: TransactionStatus.paid,
        categoryId: 'cat_rendimentos',
        goalId: goal.id,
        tags: const ['rendimento_cofrinho'],
      ),
    );

    expect(appState.getInvoiceTotal(card.id, '2026-11'), 125.0);
    expect(appState.getCardUsedLimit(card.id), 125.0);
    expect(appState.totalExpenseForMonth('2026-11'), 200.0);
    expect(appState.totalIncomeForMonth('2026-11'), 5.0);
    expect(appState.getAccountById(account.id)!.currentBalance, 70.0);
    expect(appState.goalsTotalBalance, 35.0);
  });

  testWidgets('Adicionar e editar cartão de crédito sem erro de _dependents.isEmpty',
      (tester) async {
    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(NevesFinanceApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cartões'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar Primeiro Cartão'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nubank'));
    await tester.pumpAndSettle();

    // Testa abrir dropdown de fechamento
    await tester.tap(find.text('Dia 5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia 8').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(appState.creditCards.length, 1);
    expect(appState.creditCards.first.name, 'Nubank');
    expect(appState.creditCards.first.closingDay, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adicionar Caixinha em Planejamento sem erro de assertion',
      (tester) async {
    final appState = AppState();
    await appState.init();

    await tester.pumpWidget(NevesFinanceApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Planejamento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Caixinhas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova Caixinha'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.bySemanticsLabel('Nome (ex: Reserva de Emergência, Viagem...)').first.evaluate().isEmpty
          ? find.widgetWithText(TextField, '').last
          : find.bySemanticsLabel('Nome (ex: Reserva de Emergência, Viagem...)'),
      'Carro',
    );
    await tester.tap(find.text('Salvar Caixinha'));
    await tester.pumpAndSettle();

    expect(appState.goals.any((g) => g.name == 'Carro'), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('ImportService preserva centavos com vírgula em TSV, CSV com aspas, CSV sem aspas e PDF', () async {
    final appState = AppState();
    await appState.init();

    const mixedFormats = '''
2026-11-15\tDl *Uberrides\t42,99
2026-11-15,"Dl*Google Youtub","16,90"
2026-11-14,Shopee *Insider,30,62
15/11/2026;Posto Base;1.242,99
14/11/2026 | Amazon | R\$ +89,55
13/11/2026 Padaria Central 18,45
''';

    final parsed = ImportService.parseStatementContent(
      content: mixedFormats,
      extension: 'txt',
      categories: appState.categories,
      existingTransactions: appState.transactions,
      forceExpenseForCreditCard: true,
    );

    expect(parsed.length, 6);
    expect(parsed[0].title, 'Dl *Uberrides');
    expect(parsed[0].amount, 42.99);
    expect(parsed[1].title, 'Dl*Google Youtub');
    expect(parsed[1].amount, 16.90);
    expect(parsed[2].title, 'Shopee *Insider');
    expect(parsed[2].amount, 30.62);
    expect(parsed[3].title, 'Posto Base');
    expect(parsed[3].amount, 1242.99);
    expect(parsed[4].title, 'Amazon');
    expect(parsed[4].amount, 89.55);
    expect(parsed[5].title, 'Padaria Central');
    expect(parsed[5].amount, 18.45);
  });

  test(
      'Etapa 1: Caixinha preserva initialBalance, Terceiro entra na fatura sem inflar gastos e pagamento parcial abate restante',
      () async {
    final appState = AppState();
    await appState.init();

    const account = Account(
      id: 'acc_mp',
      name: 'Mercado Pago',
      type: AccountType.checking,
      initialBalance: 2000.0,
      currentBalance: 2000.0,
      colorValue: 0xFF059669,
      iconName: 'account_balance',
    );
    await appState.saveAccount(account);

    const card = CreditCardModel(
      id: 'card_mp',
      name: 'Mercado Pago',
      creditLimit: 5000.0,
      closingDay: 28,
      dueDay: 4,
      colorValue: 0xFF059669,
    );
    await appState.saveCreditCard(card);

    // 1. Caixinha criada com saldo inicial R$ 2.175,41 + lote com rendimento + despesa paga direto da caixinha
    const goal = GoalModel(
      id: 'goal_sal',
      name: 'Salário',
      targetAmount: 5000.0,
      initialBalance: 2175.41,
      currentAmount: 2175.41,
      colorValue: 0xFF10B981,
      iconName: 'savings',
    );
    await appState.saveGoal(goal);

    await appState.addTransactionsBatch([
      TransactionModel(
        id: 't_yield',
        title: 'Rendimento',
        amount: 10.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 5),
        competenceMonth: '2026-11',
        status: TransactionStatus.paid,
        categoryId: 'cat_rendimentos',
        goalId: goal.id,
        tags: const ['rendimento_cofrinho'],
      ),
      TransactionModel(
        id: 't_direct_boleto',
        title: 'Condomínio direto Caixinha',
        amount: 172.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 4),
        competenceMonth: '2026-11',
        status: TransactionStatus.paid,
        accountId: null,
        categoryId: 'cat_moradia',
        goalId: goal.id,
      ),
      TransactionModel(
        id: 't_card_mine',
        title: 'Compra Minha',
        amount: 1000.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 6),
        competenceMonth: '2026-11',
        status: TransactionStatus.pending,
        cardId: card.id,
        categoryId: 'cat_compras',
      ),
      TransactionModel(
        id: 't_card_third',
        title: 'Compra Terceiro',
        amount: 720.28,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 7),
        competenceMonth: '2026-11',
        status: TransactionStatus.pending,
        cardId: card.id,
        categoryId: 'cat_compras',
        isThirdParty: true,
      ),
    ]);

    // initialBalance preservado: 2175.41 + 10.0 - 172.0 = 2013.41
    expect(appState.goalsTotalBalance, closeTo(2013.41, 0.01));
    // Conta não foi afetada pelo boleto pago direto da caixinha
    expect(appState.getAccountById(account.id)!.currentBalance, 2000.0);
    // Fatura real do banco inclui compra de terceiro (1720.28), mas despesa pessoal exclui terceiro (172 + 1000 = 1172)
    expect(appState.getInvoiceTotal(card.id, '2026-11'), closeTo(1720.28, 0.01));
    expect(appState.totalExpenseForMonth('2026-11'), closeTo(1172.0, 0.01));

    // Pagamento parcial antecipado de R$ 680,41 mantém fatura aberta com restante R$ 1.039,87
    await appState.payCreditCardInvoice(
      card: card,
      yearMonth: '2026-11',
      sourceAccountId: account.id,
      customAmount: 680.41,
    );

    expect(
      appState.getInvoicePaidAmount(card.id, '2026-11'),
      closeTo(680.41, 0.01),
    );
    expect(
      appState.getInvoiceRemaining(card.id, '2026-11'),
      closeTo(1039.87, 0.01),
    );
    expect(appState.getCardUsedLimit(card.id), closeTo(1039.87, 0.01));
    expect(
      appState.getAccountById(account.id)!.currentBalance,
      closeTo(2000.0 - 680.41, 0.01),
    );
    expect(
      appState.getInvoiceStatus(card, '2026-11'),
      isNot(InvoiceStatus.paid),
    );
  });

  test(
      'Etapa 2: Roteamento Misto (Auto) separa Conta, Caixinha, Transferência e gera parcelas futuras',
      () async {
    final appState = AppState();
    await appState.init();

    const mpAcc = Account(
      id: 'acc_mp',
      name: 'Mercado Pago',
      type: AccountType.checking,
      initialBalance: 0.0,
      currentBalance: 0.0,
      colorValue: 0xFF059669,
      iconName: 'account_balance',
    );
    const nbAcc = Account(
      id: 'acc_nb',
      name: 'Nubank',
      type: AccountType.checking,
      initialBalance: 0.0,
      currentBalance: 0.0,
      colorValue: 0xFF059669,
      iconName: 'account_balance',
    );
    await appState.saveAccount(mpAcc);
    await appState.saveAccount(nbAcc);

    const card = CreditCardModel(
      id: 'card_mp',
      name: 'Mercado Pago',
      creditLimit: 5000.0,
      closingDay: 28,
      dueDay: 4,
      colorValue: 0xFF059669,
    );
    await appState.saveCreditCard(card);

    const goal = GoalModel(
      id: 'goal_emg',
      name: 'Emergências',
      targetAmount: 10000.0,
      initialBalance: 0.0,
      currentAmount: 0.0,
      colorValue: 0xFF10B981,
      iconName: 'savings',
    );
    await appState.saveGoal(goal);

    const mixedRaw = '''
02/11/2026;Esther Trindade;900,00
02/11/2026;Reserva em Emergências;-900,00
07/11/2026;Transferencia propria - Nubank;-75,74
09/11/2026;Mercado Livre Parcela 1/2;680,07
''';

    final candidates = ImportService.parseStatementContent(
      content: mixedRaw,
      extension: 'csv',
      categories: appState.categories,
      existingTransactions: appState.transactions,
      goals: appState.goals,
      accounts: appState.accounts,
      sourceAccountId: mpAcc.id,
      defaultGoalId: goal.id,
      forceExpenseForCreditCard: false,
      hasCardSelected: true,
      initialMode: ImportTargetMode.unified,
    );

    expect(candidates[0].rowTarget, ImportTargetMode.checking);
    expect(candidates[1].rowTarget, ImportTargetMode.cofrinho);
    expect(candidates[2].rowTarget, ImportTargetMode.transfer);
    expect(candidates[3].rowTarget, ImportTargetMode.creditCard);
    expect(candidates[3].installmentIndex, 1);
    expect(candidates[3].installmentTotal, 2);
    expect(candidates[3].generateFutureInstallments, isTrue);

    // Ajusta sinal do primeiro item (receita em conta) e da compra parcelada (despesa no cartão)
    candidates[0].type = TransactionType.income;
    candidates[3].type = TransactionType.expense;

    final txs = ImportService.buildTransactionsForImport(
      candidates: candidates,
      sourceAccountId: mpAcc.id,
      counterpartAccountId: nbAcc.id,
      card: card,
      defaultGoalId: goal.id,
      accounts: appState.accounts,
      goals: appState.goals,
    );

    await appState.addTransactionsBatch(txs);

    // 1 receita + 1 aporte + 1 transferencia + 2 parcelas (1/2 e 2/2) = 5 transações
    expect(txs.length, 5);
    expect(appState.getInvoiceTotal(card.id, '2026-11'), closeTo(680.07, 0.01));
    expect(appState.getInvoiceTotal(card.id, '2026-12'), closeTo(680.07, 0.01));
    expect(appState.getCardUsedLimit(card.id), closeTo(1360.14, 0.01));
    expect(appState.goalsTotalBalance, closeTo(900.0, 0.01));
    expect(appState.getAccountById(mpAcc.id)!.currentBalance, closeTo(-75.74, 0.01));
    expect(appState.getAccountById(nbAcc.id)!.currentBalance, closeTo(75.74, 0.01));
  });
}
