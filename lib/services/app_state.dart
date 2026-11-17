import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'database_service.dart';
import 'import_service.dart';

class AppState extends ChangeNotifier {
  static const _prefThemeMode = 'neves_mvp_theme_mode';
  static const _prefDiscreet = 'neves_mvp_discreet';

  final Uuid _uuid = const Uuid();

  List<CategoryItem> _categories = [];
  List<CreditCardItem> _cards = [];
  List<TransactionItem> _transactions = [];

  late String _selectedYearMonth;
  ThemeMode _themeMode = ThemeMode.system;
  bool _discreetMode = false;
  bool _isLoaded = false;

  // Navegação cruzada opcional (ex.: tocar em um cartão no Resumo abre o Extrato filtrado)
  int _activeTabIndex = 0;
  String? _extratoFilter; // null = Todos, 'cash', 'income', ou 'card:<cardId>'

  AppState() {
    _selectedYearMonth = AppFormatters.yearMonthFromDate(DateTime.now());
  }

  bool get isLoaded => _isLoaded;
  String get selectedYearMonth => _selectedYearMonth;
  ThemeMode get themeMode => _themeMode;
  bool get discreetMode => _discreetMode;
  int get activeTabIndex => _activeTabIndex;
  String? get extratoFilter => _extratoFilter;

  List<CategoryItem> get categories => List.unmodifiable(_categories);
  List<CreditCardItem> get cards => List.unmodifiable(_cards);
  List<TransactionItem> get allTransactions => List.unmodifiable(_transactions);

  List<CategoryItem> categoriesByType(TransactionType type) =>
      _categories.where((c) => c.type == type).toList();

  CategoryItem categoryById(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => const CategoryItem(
        id: 'cat_other_exp',
        name: 'Outros',
        iconKey: 'category',
        colorValue: 0xFF64748B,
        type: TransactionType.expense,
      ),
    );
  }

  CreditCardItem? cardById(String? id) {
    if (id == null) return null;
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString(_prefThemeMode);
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      _discreetMode = prefs.getBool(_prefDiscreet) ?? false;
    } catch (_) {}

    _categories = await DatabaseService.instance.loadCategories();
    _cards = await DatabaseService.instance.loadCards();
    _transactions = await DatabaseService.instance.loadTransactions();
    _sortTransactions();
    _isLoaded = true;
    notifyListeners();
  }

  void _sortTransactions() {
    _transactions.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });
  }

  void setActiveTab(int index, {String? filter}) {
    _activeTabIndex = index;
    if (filter != null) {
      _extratoFilter = filter;
    }
    notifyListeners();
  }

  void setExtratoFilter(String? filter) {
    _extratoFilter = filter;
    notifyListeners();
  }

  void setSelectedYearMonth(String ym) {
    if (_selectedYearMonth == ym) return;
    _selectedYearMonth = ym;
    notifyListeners();
  }

  void changeMonth(int delta) {
    _selectedYearMonth = AppFormatters.addMonths(_selectedYearMonth, delta);
    notifyListeners();
  }

  Future<void> toggleDiscreetMode() async {
    _discreetMode = !_discreetMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDiscreet, _discreetMode);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.dark ? 'dark' : 'system');
      await prefs.setString(_prefThemeMode, str);
    } catch (_) {}
  }

  // ==================== CÁLCULOS DO MÊS (REGRA ÚNICA) ====================

  List<TransactionItem> transactionsForMonth([String? ym]) {
    final target = ym ?? _selectedYearMonth;
    return _transactions.where((t) => t.competenceMonth == target).toList();
  }

  /// Total de Receitas do mês
  double monthIncome([String? ym]) {
    final target = ym ?? _selectedYearMonth;
    double sum = 0.0;
    for (final t in _transactions) {
      if (t.competenceMonth == target && t.type == TransactionType.income) {
        sum += t.amount;
      }
    }
    return sum;
  }

  /// Total de Gastos à Vista (Pix / Débito) no mês
  double monthCashExpense([String? ym]) {
    final target = ym ?? _selectedYearMonth;
    double sum = 0.0;
    for (final t in _transactions) {
      if (t.competenceMonth == target &&
          t.type == TransactionType.expense &&
          t.paymentMethod == PaymentMethod.cash) {
        sum += t.amount;
      }
    }
    return sum;
  }

  /// Total das Faturas de Cartão de Crédito no mês
  double monthCardExpense([String? ym]) {
    final target = ym ?? _selectedYearMonth;
    double sum = 0.0;
    for (final t in _transactions) {
      if (t.competenceMonth == target &&
          t.type == TransactionType.expense &&
          t.paymentMethod == PaymentMethod.creditCard) {
        sum += t.amount;
      }
    }
    return sum;
  }

  /// Total de Saídas do mês (Gastos à Vista + Faturas do Mês)
  double monthTotalExpense([String? ym]) {
    return monthCashExpense(ym) + monthCardExpense(ym);
  }

  /// Quanto Sobra no Mês (Receitas - Total de Saídas)
  double monthBalance([String? ym]) {
    return monthIncome(ym) - monthTotalExpense(ym);
  }

  /// Total da fatura de um cartão específico no mês
  double cardInvoiceTotal(String cardId, [String? ym]) {
    final target = ym ?? _selectedYearMonth;
    double sum = 0.0;
    for (final t in _transactions) {
      if (t.competenceMonth == target &&
          t.type == TransactionType.expense &&
          t.paymentMethod == PaymentMethod.creditCard &&
          t.cardId == cardId) {
        sum += t.amount;
      }
    }
    return sum;
  }

  /// Quantidade de lançamentos na fatura de um cartão no mês
  int cardInvoiceCount(String cardId, [String? ym]) {
    final target = ym ?? _selectedYearMonth;
    int count = 0;
    for (final t in _transactions) {
      if (t.competenceMonth == target &&
          t.type == TransactionType.expense &&
          t.paymentMethod == PaymentMethod.creditCard &&
          t.cardId == cardId) {
        count++;
      }
    }
    return count;
  }

  /// Resumo de despesas por categoria no mês (À Vista + Cartão)
  List<CategoryExpenseSummary> expensesByCategory([String? ym]) {
    final target = ym ?? _selectedYearMonth;
    final totalExp = monthTotalExpense(target);
    if (totalExp <= 0) return const [];

    final Map<String, double> sums = {};
    final Map<String, int> counts = {};

    for (final t in _transactions) {
      if (t.competenceMonth == target && t.type == TransactionType.expense) {
        sums[t.categoryId] = (sums[t.categoryId] ?? 0.0) + t.amount;
        counts[t.categoryId] = (counts[t.categoryId] ?? 0) + 1;
      }
    }

    final result = <CategoryExpenseSummary>[];
    double positiveCatTotal = 0.0;
    sums.forEach((_, amount) {
      if (amount > 0) positiveCatTotal += amount;
    });
    if (positiveCatTotal <= 0) return const [];

    sums.forEach((catId, amount) {
      if (amount <= 0.005) return;
      result.add(
        CategoryExpenseSummary(
          category: categoryById(catId),
          amount: amount,
          percentage: (amount / positiveCatTotal).clamp(0.0, 1.0),
          count: counts[catId] ?? 1,
        ),
      );
    });

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  // ==================== OPERAÇÕES DE LANÇAMENTOS ====================

  /// Divide um valor total em N parcelas exatas em centavos (a 1ª parcela absorve eventual diferença de centavos).
  static List<double> splitInstallments(double totalAmount, int installments) {
    if (installments <= 1) return [totalAmount];
    final totalCents = (totalAmount * 100).round();
    final baseCents = totalCents ~/ installments;
    final remainderCents = totalCents - (baseCents * installments);
    return List<double>.generate(installments, (index) {
      final cents = index == 0 ? baseCents + remainderCents : baseCents;
      return cents / 100.0;
    });
  }

  /// Cria um novo lançamento (à vista, parcelado no cartão ou fixo mensal).
  Future<void> createTransaction({
    required String title,
    required double totalAmount,
    required DateTime date,
    required TransactionType type,
    required PaymentMethod paymentMethod,
    required String categoryId,
    String? cardId,
    required String firstCompetenceMonth,
    int installments = 1,
    bool isRecurring = false,
  }) async {
    final cleanTitle = title.trim();
    final effectivePayment =
        type == TransactionType.income ? PaymentMethod.cash : paymentMethod;
    final effectiveCardId =
        effectivePayment == PaymentMethod.creditCard ? cardId : null;

    final List<TransactionItem> toSave = [];

    if (effectivePayment == PaymentMethod.creditCard && installments > 1) {
      // Compra parcelada no cartão: divide em N faturas consecutivas
      final groupId = _uuid.v4();
      final parts = splitInstallments(totalAmount, installments);
      for (int i = 0; i < installments; i++) {
        final targetMonth = AppFormatters.addMonths(firstCompetenceMonth, i);
        toSave.add(
          TransactionItem(
            id: _uuid.v4(),
            title: cleanTitle,
            amount: parts[i],
            date: date,
            competenceMonth: targetMonth,
            type: TransactionType.expense,
            paymentMethod: PaymentMethod.creditCard,
            categoryId: categoryId,
            cardId: effectiveCardId,
            groupId: groupId,
            installmentIndex: i + 1,
            installmentTotal: installments,
            isRecurring: false,
          ),
        );
      }
    } else if (isRecurring) {
      // Lançamento fixo mensal: gera 12 meses consecutivos com mesmo groupId
      final groupId = _uuid.v4();
      for (int i = 0; i < 12; i++) {
        final targetMonth = AppFormatters.addMonths(firstCompetenceMonth, i);
        final recurringDate = DateTime(
          date.year,
          date.month + i,
          date.day,
        );
        toSave.add(
          TransactionItem(
            id: _uuid.v4(),
            title: cleanTitle,
            amount: totalAmount,
            date: recurringDate,
            competenceMonth: targetMonth,
            type: type,
            paymentMethod: effectivePayment,
            categoryId: categoryId,
            cardId: effectiveCardId,
            groupId: groupId,
            installmentIndex: 1,
            installmentTotal: 1,
            isRecurring: true,
          ),
        );
      }
    } else {
      // Lançamento único (à vista ou 1x no cartão)
      toSave.add(
        TransactionItem(
          id: _uuid.v4(),
          title: cleanTitle,
          amount: totalAmount,
          date: date,
          competenceMonth: firstCompetenceMonth,
          type: type,
          paymentMethod: effectivePayment,
          categoryId: categoryId,
          cardId: effectiveCardId,
          groupId: null,
          installmentIndex: 1,
          installmentTotal: 1,
          isRecurring: false,
        ),
      );
    }

    await DatabaseService.instance.upsertTransactionsBatch(toSave);
    _transactions.addAll(toSave);
    _sortTransactions();
    notifyListeners();
  }

  /// Atualiza um lançamento existente (e opcionalmente os próximos do mesmo grupo se for recorrente/parcelado).
  Future<void> updateTransaction(
    TransactionItem updated, {
    bool applyToFutureInGroup = false,
  }) async {
    final List<TransactionItem> toSave = [updated];

    if (applyToFutureInGroup && updated.groupId != null) {
      for (final tx in _transactions) {
        if (tx.groupId == updated.groupId &&
            tx.id != updated.id &&
            tx.competenceMonth.compareTo(updated.competenceMonth) > 0) {
          toSave.add(
            tx.copyWith(
              title: updated.title,
              amount: updated.amount,
              categoryId: updated.categoryId,
              cardId: updated.cardId,
              paymentMethod: updated.paymentMethod,
            ),
          );
        }
      }
    }

    await DatabaseService.instance.upsertTransactionsBatch(toSave);
    for (final item in toSave) {
      final idx = _transactions.indexWhere((t) => t.id == item.id);
      if (idx >= 0) {
        _transactions[idx] = item;
      }
    }
    _sortTransactions();
    notifyListeners();
  }

  /// Exclui um lançamento (ou ele + futuros do mesmo grupo de parcelas/fixas).
  Future<void> deleteTransaction(
    TransactionItem item, {
    bool deleteFutureInGroup = false,
  }) async {
    final List<String> idsToDelete = [item.id];
    if (deleteFutureInGroup && item.groupId != null) {
      for (final tx in _transactions) {
        if (tx.groupId == item.groupId &&
            tx.id != item.id &&
            tx.competenceMonth.compareTo(item.competenceMonth) >= 0) {
          idsToDelete.add(tx.id);
        }
      }
    }
    await DatabaseService.instance.deleteTransactionIds(idsToDelete);
    final set = idsToDelete.toSet();
    _transactions.removeWhere((t) => set.contains(t.id));
    notifyListeners();
  }

  /// Salva em lote os candidatos selecionados no Importador Unificado.
  /// Retorna a quantidade de lançamentos criados (incluindo parcelas futuras projetadas).
  Future<int> commitImportedCandidates({
    required List<ImportCandidate> candidates,
    required String selectedInvoiceMonth,
  }) async {
    final toSave = <TransactionItem>[];

    for (final c in candidates) {
      if (!c.selected || c.amount <= 0) continue;

      if (c.destination == ImportDestinationType.checking) {
        final txType =
            c.isCreditOrRefund ? TransactionType.income : TransactionType.expense;
        toSave.add(
          TransactionItem(
            id: _uuid.v4(),
            title: c.title.trim(),
            amount: c.amount,
            date: c.date,
            competenceMonth: AppFormatters.yearMonthFromDate(c.date),
            type: txType,
            paymentMethod: PaymentMethod.cash,
            categoryId: c.categoryId,
            cardId: null,
            groupId: null,
            installmentIndex: 1,
            installmentTotal: 1,
            isRecurring: false,
          ),
        );
      } else {
        // Fatura de Cartão de Crédito
        final effectiveCardId =
            c.cardId ?? (_cards.isNotEmpty ? _cards.first.id : null);
        // Estorno/crédito na fatura entra com valor negativo para abater do total da fatura
        final signedExpenseAmount =
            c.isCreditOrRefund ? -c.amount : c.amount;

        final hasMultiInstallments =
            !c.isCreditOrRefund && c.installmentTotal > 1;
        final groupId = hasMultiInstallments ? _uuid.v4() : null;

        toSave.add(
          TransactionItem(
            id: _uuid.v4(),
            title: c.title.trim(),
            amount: signedExpenseAmount,
            date: c.date,
            competenceMonth: selectedInvoiceMonth,
            type: TransactionType.expense,
            paymentMethod: PaymentMethod.creditCard,
            categoryId: c.categoryId,
            cardId: effectiveCardId,
            groupId: groupId,
            installmentIndex: hasMultiInstallments ? c.installmentIndex : 1,
            installmentTotal: hasMultiInstallments ? c.installmentTotal : 1,
            isRecurring: false,
          ),
        );

        // Projeção automática das parcelas restantes nos meses futuros
        if (hasMultiInstallments &&
            c.projectFutureInstallments &&
            c.installmentIndex < c.installmentTotal) {
          for (int nextIdx = c.installmentIndex + 1;
              nextIdx <= c.installmentTotal;
              nextIdx++) {
            final offset = nextIdx - c.installmentIndex;
            final futureMonth =
                AppFormatters.addMonths(selectedInvoiceMonth, offset);

            final alreadyExists = ImportService.isDuplicateTransaction(
              title: c.title,
              amount: c.amount,
              date: c.date,
              targetMonth: futureMonth,
              destination: ImportDestinationType.creditCard,
              cardId: effectiveCardId,
              installmentIndex: nextIdx,
              installmentTotal: c.installmentTotal,
              existingTransactions: _transactions,
            );

            if (!alreadyExists) {
              toSave.add(
                TransactionItem(
                  id: _uuid.v4(),
                  title: c.title.trim(),
                  amount: c.amount,
                  date: c.date,
                  competenceMonth: futureMonth,
                  type: TransactionType.expense,
                  paymentMethod: PaymentMethod.creditCard,
                  categoryId: c.categoryId,
                  cardId: effectiveCardId,
                  groupId: groupId,
                  installmentIndex: nextIdx,
                  installmentTotal: c.installmentTotal,
                  isRecurring: false,
                ),
              );
            }
          }
        }
      }
    }

    if (toSave.isEmpty) return 0;

    await DatabaseService.instance.upsertTransactionsBatch(toSave);
    _transactions.addAll(toSave);
    _sortTransactions();
    notifyListeners();
    return toSave.length;
  }

  // ==================== CARTÕES DE CRÉDITO & CATEGORIAS ====================

  Future<void> saveCard({
    String? id,
    required String name,
    required int colorValue,
    required int closingDay,
    required int dueDay,
  }) async {
    final card = CreditCardItem(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      colorValue: colorValue,
      closingDay: closingDay.clamp(1, 31),
      dueDay: dueDay.clamp(1, 31),
    );
    await DatabaseService.instance.upsertCard(card);
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _cards[idx] = card;
    } else {
      _cards.add(card);
    }
    notifyListeners();
  }

  Future<void> deleteCard(String id) async {
    await DatabaseService.instance.deleteCard(id);
    _cards.removeWhere((c) => c.id == id);
    _transactions.removeWhere((t) => t.cardId == id);
    if (_extratoFilter == 'card:$id') {
      _extratoFilter = null;
    }
    notifyListeners();
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required String iconKey,
    required int colorValue,
    required TransactionType type,
  }) async {
    final category = CategoryItem(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      type: type,
    );
    await DatabaseService.instance.upsertCategory(category);
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      _categories[idx] = category;
    } else {
      _categories.add(category);
    }
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseService.instance.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // ==================== BACKUP JSON & RESET ====================

  String exportBackupJson() {
    final payload = {
      'app': 'neves_mvp',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': _categories.map((c) => c.toMap()).toList(),
      'cards': _cards.map((c) => c.toMap()).toList(),
      'transactions': _transactions.map((t) => t.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackupJson(String jsonString) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final rawCats = (decoded['categories'] as List<dynamic>?) ?? [];
    final rawCards = (decoded['cards'] as List<dynamic>?) ?? [];
    final rawTxs = (decoded['transactions'] as List<dynamic>?) ?? [];

    final importedCats = rawCats
        .map((e) => CategoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final importedCards = rawCards
        .map((e) => CreditCardItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final importedTxs = rawTxs
        .map(
            (e) => TransactionItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final finalCats = importedCats.isNotEmpty
        ? importedCats
        : CategoryItem.defaultCategories();

    await DatabaseService.instance.replaceAllData(
      categories: finalCats,
      cards: importedCards,
      transactions: importedTxs,
    );

    _categories = finalCats;
    _cards = importedCards;
    _transactions = importedTxs;
    _sortTransactions();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    final defaultCats = CategoryItem.defaultCategories();
    final defaultCards = CreditCardItem.defaultCards();

    await DatabaseService.instance.replaceAllData(
      categories: defaultCats,
      cards: defaultCards,
      transactions: const [],
    );

    _categories = defaultCats;
    _cards = defaultCards;
    _transactions = [];
    _extratoFilter = null;
    notifyListeners();
  }
}
