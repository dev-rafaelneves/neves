import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'backup_service.dart';
import 'database_service.dart';
import 'gemini_service.dart';
import 'notification_service.dart';
import 'security_service.dart';

class AppState extends ChangeNotifier {
  static const _uuid = Uuid();

  SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool _discreetMode = false;
  bool get discreetMode => _discreetMode;

  BudgetRegime _budgetRegime = BudgetRegime.competence;
  BudgetRegime get budgetRegime => _budgetRegime;

  String _userName = 'Minha Carteira';
  String get userName => _userName;

  late String _selectedYearMonth;
  String get selectedYearMonth => _selectedYearMonth;

  // Segurança (AppLockGate)
  bool _hasPinLock = false;
  bool get hasPinLock => _hasPinLock;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _useBiometrics = true;
  bool get useBiometrics => _useBiometrics;

  bool _blockScreenshots = true;
  bool get blockScreenshots => _blockScreenshots;

  DateTime? _lockoutUntil;
  bool get isLockedOut =>
      _lockoutUntil != null && _lockoutUntil!.isAfter(DateTime.now());
  int get remainingLockoutSeconds =>
      SecurityService.getRemainingLockoutSeconds(_lockoutUntil);

  // Lembretes
  bool _dailyBillsReminderEnabled = false;
  bool get dailyBillsReminderEnabled => _dailyBillsReminderEnabled;
  int _dailyBillsReminderHour = 9;
  int get dailyBillsReminderHour => _dailyBillsReminderHour;
  int _dailyBillsReminderMinute = 0;
  int get dailyBillsReminderMinute => _dailyBillsReminderMinute;

  // Entidades em memória sincronizadas com SQLite / SharedPreferences
  List<Account> _accounts = [];
  List<Account> get accounts => List.unmodifiable(_accounts);

  List<CreditCardModel> _creditCards = [];
  List<CreditCardModel> get creditCards => List.unmodifiable(_creditCards);

  List<CreditCardInvoice> _invoices = [];
  List<CreditCardInvoice> get invoices => List.unmodifiable(_invoices);

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => List.unmodifiable(_categories);

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  List<BudgetModel> _budgets = [];
  List<BudgetModel> get budgets => List.unmodifiable(_budgets);

  List<GoalModel> _goals = [];
  List<GoalModel> get goals => List.unmodifiable(_goals);

  AppState() {
    final now = DateTime.now();
    _selectedYearMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await DatabaseService.init();
    await NotificationService.instance.init();

    // Carregar preferências
    final isDark = _prefs?.getBool('neves_dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _discreetMode = _prefs?.getBool('neves_discreet_mode') ?? false;
    _budgetRegime = BudgetRegime.fromString(
      _prefs?.getString('neves_budget_regime'),
    );
    _userName = _prefs?.getString('neves_user_name') ?? 'Minha Carteira';

    _dailyBillsReminderEnabled =
        _prefs?.getBool('neves_daily_reminder_enabled') ?? false;
    _dailyBillsReminderHour = _prefs?.getInt('neves_daily_reminder_hour') ?? 9;
    _dailyBillsReminderMinute =
        _prefs?.getInt('neves_daily_reminder_min') ?? 0;

    // Segurança
    _hasPinLock = await SecurityService.hasSecurePin();
    _isLocked = _hasPinLock;
    _useBiometrics = SecurityService.isBiometricsEnabled(_prefs);
    _blockScreenshots = SecurityService.isBlockScreenshotsEnabled(_prefs);
    _lockoutUntil = SecurityService.getLockoutUntil(_prefs);
    if (_blockScreenshots) {
      await SecurityService.setFlagSecure(true);
    }

    await _loadAllData();
    await _ensureSeeds();

    await BackupService.instance.checkAndRunWeeklyAutoBackup(this);
    notifyListeners();
  }

  Future<void> _loadAllData() async {
    if (DatabaseService.isAvailable) {
      _accounts = await DatabaseService.getAccounts();
      _creditCards = await DatabaseService.getCreditCards();
      _invoices = await DatabaseService.getInvoices();
      _categories = await DatabaseService.getCategories();
      _transactions = await DatabaseService.getTransactions();
      _budgets = await DatabaseService.getBudgets();
      _goals = await DatabaseService.getGoals();
      if (_creditCards.isEmpty && _prefs != null) {
        final rawCards = _prefs!.getString('neves_cards');
        if (rawCards != null && rawCards.isNotEmpty) {
          try {
            final list = jsonDecode(rawCards) as List<dynamic>;
            _creditCards = list
                .map((e) =>
                    CreditCardModel.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList();
          } catch (_) {}
        }
      }
    } else {
      // Fallback SharedPreferences caso rode na Web ou teste sem sqflite
      _loadFromPrefsFallback();
    }
  }

  void _loadFromPrefsFallback() {
    if (_prefs == null) return;
    List<T> decodeList<T>(
      String key,
      T Function(Map<String, dynamic>) fromMap,
    ) {
      final raw = _prefs!.getString(key);
      if (raw == null || raw.isEmpty) return [];
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        return [];
      }
    }

    _accounts = decodeList('neves_accounts', Account.fromMap);
    _creditCards = decodeList('neves_cards', CreditCardModel.fromMap);
    _invoices = decodeList('neves_invoices', CreditCardInvoice.fromMap);
    _categories = decodeList('neves_categories', CategoryModel.fromMap);
    _transactions = decodeList('neves_transactions', TransactionModel.fromMap);
    _budgets = decodeList('neves_budgets', BudgetModel.fromMap);
    _goals = decodeList('neves_goals', GoalModel.fromMap);
  }

  Future<void> _persistFallbackIfNeeded() async {
    if (_prefs == null) return;
    await _prefs!.setString(
      'neves_accounts',
      jsonEncode(_accounts.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_cards',
      jsonEncode(_creditCards.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_invoices',
      jsonEncode(_invoices.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_categories',
      jsonEncode(_categories.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_transactions',
      jsonEncode(_transactions.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_budgets',
      jsonEncode(_budgets.map((e) => e.toMap()).toList()),
    );
    await _prefs!.setString(
      'neves_goals',
      jsonEncode(_goals.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> _ensureSeeds() async {
    if (_categories.isEmpty) {
      final defaultCategories = <CategoryModel>[
        const CategoryModel(
          id: 'cat_moradia',
          name: 'Moradia & Contas',
          type: TransactionType.expense,
          pillar: Pillar503020.essential,
          colorValue: 0xFF059669,
          iconName: 'home',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_mercado',
          name: 'Supermercado',
          type: TransactionType.expense,
          pillar: Pillar503020.essential,
          colorValue: 0xFF10B981,
          iconName: 'shopping_cart',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_transporte',
          name: 'Transporte & Combustível',
          type: TransactionType.expense,
          pillar: Pillar503020.essential,
          colorValue: 0xFF3B82F6,
          iconName: 'directions_car',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_saude',
          name: 'Saúde & Farmácia',
          type: TransactionType.expense,
          pillar: Pillar503020.essential,
          colorValue: 0xFFF43F5E,
          iconName: 'favorite',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_educacao',
          name: 'Educação & Cursos',
          type: TransactionType.expense,
          pillar: Pillar503020.essential,
          colorValue: 0xFF06B6D4,
          iconName: 'school',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_restaurante',
          name: 'Restaurantes & Delivery',
          type: TransactionType.expense,
          pillar: Pillar503020.lifestyle,
          colorValue: 0xFFF97316,
          iconName: 'restaurant',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_lazer',
          name: 'Lazer & Viagens',
          type: TransactionType.expense,
          pillar: Pillar503020.lifestyle,
          colorValue: 0xFF0D9488,
          iconName: 'sports_esports',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_assinaturas',
          name: 'Assinaturas & Apps',
          type: TransactionType.expense,
          pillar: Pillar503020.lifestyle,
          colorValue: 0xFF16A34A,
          iconName: 'subscriptions',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_compras',
          name: 'Compras & Vestuário',
          type: TransactionType.expense,
          pillar: Pillar503020.lifestyle,
          colorValue: 0xFFF59E0B,
          iconName: 'shopping_bag',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_aportes',
          name: 'Aportes & Futuro',
          type: TransactionType.expense,
          pillar: Pillar503020.future,
          colorValue: 0xFF059669,
          iconName: 'savings',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_salario',
          name: 'Salário & Pró-Labore',
          type: TransactionType.income,
          pillar: Pillar503020.essential,
          colorValue: 0xFF10B981,
          iconName: 'work',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_rendimentos',
          name: 'Dividendos & Rendimentos',
          type: TransactionType.income,
          pillar: Pillar503020.future,
          colorValue: 0xFF059669,
          iconName: 'trending_up',
          isSystem: true,
        ),
        const CategoryModel(
          id: 'cat_outras_receitas',
          name: 'Renda Extra & Reembolsos',
          type: TransactionType.income,
          pillar: Pillar503020.lifestyle,
          colorValue: 0xFF3B82F6,
          iconName: 'redeem',
          isSystem: true,
        ),
      ];

      for (final c in defaultCategories) {
        _categories.add(c);
        await DatabaseService.saveCategory(c);
      }
    }

    if (_accounts.isEmpty) {
      final defaultAccounts = <Account>[
        const Account(
          id: 'acc_principal',
          name: 'Conta Corrente Principal',
          type: AccountType.checking,
          initialBalance: 0.0,
          currentBalance: 0.0,
          colorValue: 0xFF059669,
          iconName: 'account_balance',
        ),
        const Account(
          id: 'acc_investimentos',
          name: 'Carteira de Investimentos',
          type: AccountType.investment,
          initialBalance: 0.0,
          currentBalance: 0.0,
          colorValue: 0xFF10B981,
          iconName: 'trending_up',
        ),
      ];
      for (final a in defaultAccounts) {
        _accounts.add(a);
        await DatabaseService.saveAccount(a);
      }
    }

    if (_goals.isEmpty) {
      const emergencyGoal = GoalModel(
        id: 'goal_reserva',
        name: 'Reserva de Emergência',
        targetAmount: 15000.0,
        currentAmount: 0.0,
        colorValue: 0xFF10B981,
        iconName: 'shield',
      );
      _goals.add(emergencyGoal);
      await DatabaseService.saveGoal(emergencyGoal);
    }

    await _persistFallbackIfNeeded();
  }

  // --- Navegação de Mês e Preferências ---
  void setSelectedYearMonth(String ym) {
    _selectedYearMonth = ym;
    notifyListeners();
  }

  void changeMonth(int deltaMonths) {
    final parts = _selectedYearMonth.split('-');
    int y = int.parse(parts[0]);
    int m = int.parse(parts[1]) + deltaMonths;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    _selectedYearMonth = '$y-${m.toString().padLeft(2, '0')}';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs?.setBool('neves_dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> toggleDiscreetMode() async {
    _discreetMode = !_discreetMode;
    await _prefs?.setBool('neves_discreet_mode', _discreetMode);
    notifyListeners();
  }

  Future<void> setBudgetRegime(BudgetRegime regime) async {
    _budgetRegime = regime;
    await _prefs?.setString('neves_budget_regime', regime.name);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    if (name.trim().isEmpty) return;
    _userName = name.trim();
    await _prefs?.setString('neves_user_name', _userName);
    notifyListeners();
  }

  // --- Segurança (PIN / Biometria / FLAG_SECURE) ---
  Future<void> setAppPin(String? pin) async {
    if (pin == null || pin.trim().isEmpty) {
      await SecurityService.removeSecurePin();
      _hasPinLock = false;
      _isLocked = false;
    } else {
      await SecurityService.saveSecurePin(pin.trim());
      _hasPinLock = true;
      _isLocked = false;
    }
    await SecurityService.resetFailedAttempts(_prefs);
    _lockoutUntil = null;
    notifyListeners();
  }

  void lockSession() {
    if (_hasPinLock) {
      _isLocked = true;
      notifyListeners();
    }
  }

  Future<bool> unlockSession(String candidatePin) async {
    if (isLockedOut) return false;
    final ok = await SecurityService.verifyPin(candidatePin);
    if (ok) {
      _isLocked = false;
      _lockoutUntil = null;
      await SecurityService.resetFailedAttempts(_prefs);
      notifyListeners();
      return true;
    } else {
      _lockoutUntil = await SecurityService.recordFailedAttempt(_prefs);
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_hasPinLock || !_useBiometrics || isLockedOut) return false;
    final ok = await SecurityService.authenticateBiometric();
    if (ok) {
      _isLocked = false;
      _lockoutUntil = null;
      await SecurityService.resetFailedAttempts(_prefs);
      notifyListeners();
    }
    return ok;
  }

  Future<void> toggleBiometrics() async {
    _useBiometrics = !_useBiometrics;
    await SecurityService.setBiometricsEnabled(_prefs, _useBiometrics);
    notifyListeners();
  }

  Future<void> toggleBlockScreenshots() async {
    _blockScreenshots = !_blockScreenshots;
    await SecurityService.setBlockScreenshotsEnabled(
      _prefs,
      _blockScreenshots,
    );
    notifyListeners();
  }

  // --- Lembretes e Gemini ---
  Future<void> updateDailyBillsReminder({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    if (enabled != null) _dailyBillsReminderEnabled = enabled;
    if (hour != null) _dailyBillsReminderHour = hour;
    if (minute != null) _dailyBillsReminderMinute = minute;

    await _prefs?.setBool(
      'neves_daily_reminder_enabled',
      _dailyBillsReminderEnabled,
    );
    await _prefs?.setInt('neves_daily_reminder_hour', _dailyBillsReminderHour);
    await _prefs?.setInt('neves_daily_reminder_min', _dailyBillsReminderMinute);

    if (_dailyBillsReminderEnabled) {
      await NotificationService.instance.requestPermissions();
    }
    await NotificationService.instance.scheduleDailyBillsReminder(
      enabled: _dailyBillsReminderEnabled,
      hour: _dailyBillsReminderHour,
      minute: _dailyBillsReminderMinute,
    );
    notifyListeners();
  }

  Future<void> saveGeminiApiKey(String key) async {
    await GeminiService.saveApiKey(key);
    notifyListeners();
  }

  Future<void> removeGeminiApiKey() async {
    await GeminiService.removeApiKey();
    notifyListeners();
  }

  // --- CRUD Contas ---
  Account? getAccountById(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> saveAccount(Account account) async {
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      _accounts[idx] = account;
    } else {
      _accounts.add(account);
    }
    await DatabaseService.saveAccount(account);
    await _recalculateAccountBalances();
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> updateInvestmentBalance(String accountId, double newBalance) async {
    final acc = getAccountById(accountId);
    if (acc == null) return;
    // Ajusta initialBalance para que currentBalance fique igual a newBalance
    final delta = newBalance - acc.currentBalance;
    final updated = acc.copyWith(
      initialBalance: acc.initialBalance + delta,
      currentBalance: newBalance,
    );
    await saveAccount(updated);
  }

  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await DatabaseService.deleteAccount(id);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  // --- CRUD Cartões de Crédito e Faturas ---
  CreditCardModel? getCardById(String? id) {
    if (id == null) return null;
    for (final c in _creditCards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> saveCreditCard(CreditCardModel card) async {
    final idx = _creditCards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _creditCards[idx] = card;
    } else {
      _creditCards.add(card);
    }
    await DatabaseService.saveCreditCard(card);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> deleteCreditCard(String id) async {
    _creditCards.removeWhere((c) => c.id == id);
    await DatabaseService.deleteCreditCard(id);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  /// Retorna o limite total ocupado no cartão por compras/parcelas ainda não pagas
  double getCardUsedLimit(String cardId) {
    double used = 0.0;
    for (final t in _transactions) {
      if (t.cardId == cardId &&
          !t.isInvoicePayment &&
          t.status == TransactionStatus.pending) {
        used += t.amount;
      }
    }
    return used;
  }

  double getCardAvailableLimit(CreditCardModel card) {
    return (card.creditLimit - getCardUsedLimit(card.id))
        .clamp(0.0, double.infinity);
  }

  /// Lista todos os lançamentos pertencentes à fatura de um cartão em determinado mês (YYYY-MM)
  List<TransactionModel> getInvoiceTransactions(
    String cardId,
    String yearMonth,
  ) {
    return _transactions
        .where(
          (t) =>
              t.cardId == cardId &&
              t.competenceMonth == yearMonth &&
              !t.isInvoicePayment,
        )
        .toList();
  }

  double getInvoiceTotal(String cardId, String yearMonth) {
    return getInvoiceTransactions(cardId, yearMonth)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  InvoiceStatus getInvoiceStatus(CreditCardModel card, String yearMonth) {
    for (final inv in _invoices) {
      if (inv.cardId == card.id && inv.yearMonth == yearMonth) {
        return inv.status;
      }
    }
    final txs = getInvoiceTransactions(card.id, yearMonth);
    if (txs.isNotEmpty && txs.every((t) => t.status == TransactionStatus.paid)) {
      return InvoiceStatus.paid;
    }
    final parts = yearMonth.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final closingDate = DateTime(y, m, card.closingDay);
    if (DateTime.now().isAfter(closingDate)) {
      return InvoiceStatus.closed;
    }
    return InvoiceStatus.open;
  }

  /// Efetua o pagamento total ou parcial da fatura debitando de uma conta bancária
  Future<void> payCreditCardInvoice({
    required CreditCardModel card,
    required String yearMonth,
    required String sourceAccountId,
    double? customAmount,
  }) async {
    final invoiceTxs = getInvoiceTransactions(card.id, yearMonth);
    final total = invoiceTxs.fold(0.0, (s, t) => s + t.amount);
    final amountToPay = customAmount ?? total;

    // 1. Marca as compras daquela fatura como pagas (liberando limite do cartão)
    for (int i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (t.cardId == card.id &&
          t.competenceMonth == yearMonth &&
          !t.isInvoicePayment) {
        final updated = t.copyWith(status: TransactionStatus.paid);
        _transactions[i] = updated;
        await DatabaseService.saveTransaction(updated);
      }
    }

    // 2. Cria uma transação de transferência/pagamento de fatura na conta corrente (não duplica despesa em categoria)
    if (amountToPay > 0) {
      final paymentTx = TransactionModel(
        id: _uuid.v4(),
        title: 'Pagamento Fatura ${card.name} ($yearMonth)',
        amount: amountToPay,
        type: TransactionType.transfer,
        date: DateTime.now(),
        competenceMonth: yearMonth,
        status: TransactionStatus.paid,
        accountId: sourceAccountId,
        cardId: card.id,
        isInvoicePayment: true,
      );
      _transactions.insert(0, paymentTx);
      await DatabaseService.saveTransaction(paymentTx);
    }

    // 3. Registra a fatura como paga
    final inv = CreditCardInvoice(
      id: 'inv_${card.id}_$yearMonth',
      cardId: card.id,
      yearMonth: yearMonth,
      status: InvoiceStatus.paid,
      paidAmount: amountToPay,
      paidAt: DateTime.now(),
    );
    final idx = _invoices.indexWhere((i) => i.id == inv.id);
    if (idx >= 0) {
      _invoices[idx] = inv;
    } else {
      _invoices.add(inv);
    }
    await DatabaseService.saveInvoice(inv);

    await _recalculateAccountBalances();
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  // --- Categorias ---
  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> saveCategory(CategoryModel cat) async {
    final idx = _categories.indexWhere((c) => c.id == cat.id);
    if (idx >= 0) {
      _categories[idx] = cat;
    } else {
      _categories.add(cat);
    }
    await DatabaseService.saveCategory(cat);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id && !c.isSystem);
    await DatabaseService.deleteCategory(id);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  // --- Transações (com suporte a Parcelamento 1x..48x e Recorrência) ---
  Future<void> addOrUpdateTransaction(
    TransactionModel baseTx, {
    int installments = 1,
  }) async {
    final existingIdx = _transactions.indexWhere((t) => t.id == baseTx.id);

    if (existingIdx >= 0 || installments <= 1) {
      if (existingIdx >= 0) {
        _transactions[existingIdx] = baseTx;
      } else {
        _transactions.insert(0, baseTx);
      }
      await DatabaseService.saveTransaction(baseTx);
    } else {
      // Criação de compra parcelada (1/N .. N/N) alocando cada parcela na competência correta
      final groupId = _uuid.v4();
      final perInstallment =
          double.parse((baseTx.amount / installments).toStringAsFixed(2));
      final card = getCardById(baseTx.cardId);

      final baseCompetence = card != null
          ? card.computeCompetenceMonth(baseTx.date)
          : baseTx.competenceMonth;
      final compParts = baseCompetence.split('-');
      int baseYear = int.parse(compParts[0]);
      int baseMonth = int.parse(compParts[1]);

      for (int i = 0; i < installments; i++) {
        int y = baseYear;
        int m = baseMonth + i;
        while (m > 12) {
          m -= 12;
          y += 1;
        }
        final compYm = '$y-${m.toString().padLeft(2, '0')}';
        final installmentDate = DateTime(
          baseTx.date.year,
          baseTx.date.month + i,
          baseTx.date.day,
        );

        // Ajuste de centavos na primeira parcela
        final exactAmount = i == 0
            ? double.parse(
                (baseTx.amount - perInstallment * (installments - 1))
                    .toStringAsFixed(2),
              )
            : perInstallment;

        final item = baseTx.copyWith(
          id: i == 0 ? baseTx.id : _uuid.v4(),
          title: baseTx.title,
          amount: exactAmount,
          date: installmentDate,
          competenceMonth: compYm,
          status: baseTx.isCreditCard
              ? TransactionStatus.pending
              : (i == 0 ? baseTx.status : TransactionStatus.pending),
          installmentGroupId: groupId,
          installmentIndex: i + 1,
          installmentTotal: installments,
        );
        _transactions.insert(0, item);
        await DatabaseService.saveTransaction(item);
      }
    }

    // Se a transação está vinculada a uma Meta (Caixinha), atualiza o saldo da meta
    if (baseTx.goalId != null) {
      await _recalculateGoals();
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _recalculateAccountBalances();
    await _persistFallbackIfNeeded();

    // Verifica limite de orçamento para alertar 80% / 100%
    if (baseTx.type == TransactionType.expense && baseTx.categoryId != null) {
      await _checkBudgetThresholdAlert(
        baseTx.categoryId!,
        baseTx.effectiveMonth(_budgetRegime),
      );
    }

    notifyListeners();
  }

  Future<void> toggleTransactionPaid(TransactionModel tx) async {
    final nextStatus = tx.status == TransactionStatus.paid
        ? TransactionStatus.pending
        : TransactionStatus.paid;
    final updated = tx.copyWith(status: nextStatus);
    await addOrUpdateTransaction(updated);
  }

  Future<void> deleteTransaction(
    TransactionModel tx, {
    bool deleteAllInstallments = false,
  }) async {
    if (deleteAllInstallments && tx.installmentGroupId != null) {
      _transactions.removeWhere(
        (t) => t.installmentGroupId == tx.installmentGroupId,
      );
      await DatabaseService.deleteInstallmentGroup(tx.installmentGroupId!);
    } else {
      _transactions.removeWhere((t) => t.id == tx.id);
      await DatabaseService.deleteTransaction(tx.id);
    }
    await _recalculateAccountBalances();
    await _recalculateGoals();
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> _recalculateAccountBalances() async {
    for (int i = 0; i < _accounts.length; i++) {
      final acc = _accounts[i];
      double bal = acc.initialBalance;

      for (final t in _transactions) {
        if (t.status != TransactionStatus.paid) continue;
        if (t.isCreditCard && !t.isInvoicePayment) continue;

        if (t.type == TransactionType.income && t.accountId == acc.id) {
          bal += t.amount;
        } else if (t.type == TransactionType.expense &&
            t.accountId == acc.id) {
          bal -= t.amount;
        } else if (t.type == TransactionType.transfer) {
          if (t.accountId == acc.id) bal -= t.amount;
          if (t.destinationAccountId == acc.id) bal += t.amount;
        }
      }

      final updated = acc.copyWith(currentBalance: bal);
      _accounts[i] = updated;
      await DatabaseService.saveAccount(updated);
    }
  }

  Future<void> _recalculateGoals() async {
    for (int i = 0; i < _goals.length; i++) {
      final g = _goals[i];
      double sum = 0.0;
      for (final t in _transactions) {
        if (t.goalId == g.id && t.status == TransactionStatus.paid) {
          sum += t.amount;
        }
      }
      if (sum > 0) {
        final updated = g.copyWith(currentAmount: sum);
        _goals[i] = updated;
        await DatabaseService.saveGoal(updated);
      }
    }
  }

  // --- Orçamentos (Budgets) e Metas (Goals) ---
  BudgetModel? getBudgetForCategory(String categoryId, String yearMonth) {
    for (final b in _budgets) {
      if (b.categoryId == categoryId && b.yearMonth == yearMonth) {
        return b;
      }
    }
    return null;
  }

  Future<void> saveBudget({
    required String categoryId,
    required String yearMonth,
    required double limitAmount,
  }) async {
    final existing = getBudgetForCategory(categoryId, yearMonth);
    final budget = BudgetModel(
      id: existing?.id ?? 'b_${categoryId}_$yearMonth',
      categoryId: categoryId,
      yearMonth: yearMonth,
      limitAmount: limitAmount,
    );
    final idx = _budgets.indexWhere((b) => b.id == budget.id);
    if (limitAmount <= 0) {
      if (idx >= 0) _budgets.removeAt(idx);
      await DatabaseService.deleteBudget(budget.id);
    } else {
      if (idx >= 0) {
        _budgets[idx] = budget;
      } else {
        _budgets.add(budget);
      }
      await DatabaseService.saveBudget(budget);
    }
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> _checkBudgetThresholdAlert(
    String categoryId,
    String yearMonth,
  ) async {
    final budget = getBudgetForCategory(categoryId, yearMonth);
    if (budget == null || budget.limitAmount <= 0) return;

    final cat = getCategoryById(categoryId);
    if (cat == null) return;

    final spent = getCategorySpent(categoryId, yearMonth);
    final ratio = spent / budget.limitAmount;
    if (ratio >= 0.80) {
      await NotificationService.instance.notifyBudgetThreshold(
        categoryName: cat.name,
        percentage: ratio,
        spent: spent,
        limit: budget.limitAmount,
      );
    }
  }

  Future<void> saveGoal(GoalModel goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      _goals[idx] = goal;
    } else {
      _goals.add(goal);
    }
    await DatabaseService.saveGoal(goal);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  Future<void> addContributionToGoal(GoalModel goal, double delta) async {
    final updated = goal.copyWith(
      currentAmount: (goal.currentAmount + delta).clamp(0.0, double.infinity),
    );
    await saveGoal(updated);
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await DatabaseService.deleteGoal(id);
    await _persistFallbackIfNeeded();
    notifyListeners();
  }

  // --- Cálculos Financeiros do Mês e Patrimônio Líquido ---
  List<TransactionModel> transactionsForMonth(String yearMonth) {
    return _transactions
        .where((t) => t.effectiveMonth(_budgetRegime) == yearMonth)
        .toList();
  }

  double totalIncomeForMonth(String yearMonth, {bool onlyPaid = false}) {
    return transactionsForMonth(yearMonth)
        .where((t) =>
            t.type == TransactionType.income &&
            (!onlyPaid || t.status == TransactionStatus.paid))
        .fold(0.0, (s, t) => s + t.amount);
  }

  double totalExpenseForMonth(String yearMonth, {bool onlyPaid = false}) {
    return transactionsForMonth(yearMonth)
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.isInvoicePayment &&
            (!onlyPaid ||
                t.status == TransactionStatus.paid ||
                t.isCreditCard))
        .fold(0.0, (s, t) => s + t.amount);
  }

  double get liquidAccountsBalance {
    return _accounts
        .where((a) => !a.archived && a.type != AccountType.investment)
        .fold(0.0, (s, a) => s + a.currentBalance);
  }

  double get investmentAccountsBalance {
    return _accounts
        .where((a) => !a.archived && a.type == AccountType.investment)
        .fold(0.0, (s, a) => s + a.currentBalance);
  }

  double get totalCreditCardUnpaidDebt {
    return _creditCards
        .where((c) => !c.archived)
        .fold(0.0, (s, c) => s + getCardUsedLimit(c.id));
  }

  double get netWorth {
    final assets = _accounts
        .where((a) => !a.archived && a.includeInNetWorth)
        .fold(0.0, (s, a) => s + a.currentBalance);
    return assets - totalCreditCardUnpaidDebt;
  }

  /// Saldo Projetado no Fim do Mês = Saldo Atual em Contas Líquidas + Receitas Pendentes do Mês - Despesas Pendentes do Mês - Faturas de Cartão do Mês não pagas
  double projectedEndOfMonthBalance(String yearMonth) {
    final monthTxs = transactionsForMonth(yearMonth);
    final pendingIncome = monthTxs
        .where((t) =>
            t.type == TransactionType.income &&
            t.status == TransactionStatus.pending)
        .fold(0.0, (s, t) => s + t.amount);

    final pendingCashExpense = monthTxs
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.isCreditCard &&
            t.status == TransactionStatus.pending)
        .fold(0.0, (s, t) => s + t.amount);

    final unpaidCardInvoicesThisMonth = _transactions
        .where((t) =>
            t.isCreditCard &&
            !t.isInvoicePayment &&
            t.competenceMonth == yearMonth &&
            t.status == TransactionStatus.pending)
        .fold(0.0, (s, t) => s + t.amount);

    return liquidAccountsBalance +
        pendingIncome -
        pendingCashExpense -
        unpaidCardInvoicesThisMonth;
  }

  double getCategorySpent(String categoryId, String yearMonth) {
    return transactionsForMonth(yearMonth)
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.isInvoicePayment &&
            t.categoryId == categoryId)
        .fold(0.0, (s, t) => s + t.amount);
  }

  Map<CategoryModel, double> categoryExpenseBreakdown(String yearMonth) {
    final map = <CategoryModel, double>{};
    for (final cat
        in _categories.where((c) => c.type == TransactionType.expense)) {
      final spent = getCategorySpent(cat.id, yearMonth);
      if (spent > 0) {
        map[cat] = spent;
      }
    }
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  /// Calcula o realizado de cada pilar da Regra 50/30/20 no mês
  Map<Pillar503020, double> pillar503020Breakdown(String yearMonth) {
    final result = {
      Pillar503020.essential: 0.0,
      Pillar503020.lifestyle: 0.0,
      Pillar503020.future: 0.0,
    };

    for (final t in transactionsForMonth(yearMonth)) {
      if (t.type != TransactionType.expense || t.isInvoicePayment) continue;
      final cat = getCategoryById(t.categoryId);
      final pillar = cat?.pillar ?? Pillar503020.essential;
      result[pillar] = (result[pillar] ?? 0.0) + t.amount;
    }

    return result;
  }

  List<String> get allUsedTags {
    final set = <String>{};
    for (final t in _transactions) {
      set.addAll(t.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  // --- Backup & Restore ---
  Map<String, dynamic> exportBackupJson() {
    return {
      'app': 'neves_finance',
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'user_name': _userName,
      'budget_regime': _budgetRegime.name,
      'accounts': _accounts.map((e) => e.toMap()).toList(),
      'credit_cards': _creditCards.map((e) => e.toMap()).toList(),
      'invoices': _invoices.map((e) => e.toMap()).toList(),
      'categories': _categories.map((e) => e.toMap()).toList(),
      'transactions': _transactions.map((e) => e.toMap()).toList(),
      'budgets': _budgets.map((e) => e.toMap()).toList(),
      'goals': _goals.map((e) => e.toMap()).toList(),
    };
  }

  BackupPreviewInfo inspectBackupJson(Map<String, dynamic> json) {
    final ts = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString())
        : null;
    final accs = (json['accounts'] as List?)?.length ?? 0;
    final cards = (json['credit_cards'] as List?)?.length ?? 0;
    final txs = (json['transactions'] as List?)?.length ?? 0;
    final gls = (json['goals'] as List?)?.length ?? 0;
    return BackupPreviewInfo(
      timestamp: ts,
      accountsCount: accs,
      cardsCount: cards,
      transactionsCount: txs,
      goalsCount: gls,
    );
  }

  Future<void> importBackupJson(
    Map<String, dynamic> json, {
    required bool merge,
  }) async {
    if (!merge) {
      await DatabaseService.clearAllData();
      _accounts.clear();
      _creditCards.clear();
      _invoices.clear();
      _categories.clear();
      _transactions.clear();
      _budgets.clear();
      _goals.clear();
    }

    if (json['user_name'] != null) {
      await setUserName(json['user_name'].toString());
    }
    if (json['budget_regime'] != null) {
      await setBudgetRegime(
        BudgetRegime.fromString(json['budget_regime'].toString()),
      );
    }

    for (final raw in (json['categories'] as List? ?? [])) {
      final item = CategoryModel.fromMap(Map<String, dynamic>.from(raw as Map));
      await saveCategory(item);
    }
    for (final raw in (json['accounts'] as List? ?? [])) {
      final item = Account.fromMap(Map<String, dynamic>.from(raw as Map));
      final idx = _accounts.indexWhere((a) => a.id == item.id);
      if (idx >= 0) {
        _accounts[idx] = item;
      } else {
        _accounts.add(item);
      }
      await DatabaseService.saveAccount(item);
    }
    for (final raw in (json['credit_cards'] as List? ?? [])) {
      final item =
          CreditCardModel.fromMap(Map<String, dynamic>.from(raw as Map));
      await saveCreditCard(item);
    }
    for (final raw in (json['invoices'] as List? ?? [])) {
      final item =
          CreditCardInvoice.fromMap(Map<String, dynamic>.from(raw as Map));
      final idx = _invoices.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _invoices[idx] = item;
      } else {
        _invoices.add(item);
      }
      await DatabaseService.saveInvoice(item);
    }
    for (final raw in (json['goals'] as List? ?? [])) {
      final item = GoalModel.fromMap(Map<String, dynamic>.from(raw as Map));
      await saveGoal(item);
    }
    for (final raw in (json['budgets'] as List? ?? [])) {
      final item = BudgetModel.fromMap(Map<String, dynamic>.from(raw as Map));
      await saveBudget(
        categoryId: item.categoryId,
        yearMonth: item.yearMonth,
        limitAmount: item.limitAmount,
      );
    }
    for (final raw in (json['transactions'] as List? ?? [])) {
      final item =
          TransactionModel.fromMap(Map<String, dynamic>.from(raw as Map));
      final idx = _transactions.indexWhere((t) => t.id == item.id);
      if (idx >= 0) {
        _transactions[idx] = item;
      } else {
        _transactions.add(item);
      }
      await DatabaseService.saveTransaction(item);
    }

    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _ensureSeeds();
    await _recalculateAccountBalances();
    await _persistFallbackIfNeeded();
    notifyListeners();
  }
}
