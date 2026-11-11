import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class DatabaseService {
  static Database? _database;

  static bool get isAvailable => _database != null && _database!.isOpen;

  static Database? get db => _database;

  // Fallback em memória para testes ou ambientes web/desktop sem driver nativo
  @visibleForTesting
  static final Map<String, String> inMemoryAiInsights = {};

  static Future<void> init({Database? customDb}) async {
    if (customDb != null) {
      _database = customDb;
      return;
    }

    if (_database != null && _database!.isOpen) return;

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'neves_finance.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          await _ensureTables(db);
        },
      );
    } catch (_) {
      _database = null;
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _ensureTables(db);
  }

  static Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initial_balance REAL NOT NULL,
        current_balance REAL NOT NULL,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL,
        include_in_net_worth INTEGER NOT NULL DEFAULT 1,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        credit_limit REAL NOT NULL,
        closing_day INTEGER NOT NULL,
        due_day INTEGER NOT NULL,
        default_account_id TEXT,
        color_value INTEGER NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        year_month TEXT NOT NULL,
        status TEXT NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        paid_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        pillar_503020 TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date_iso TEXT NOT NULL,
        competence_month TEXT NOT NULL,
        status TEXT NOT NULL,
        account_id TEXT,
        destination_account_id TEXT,
        card_id TEXT,
        category_id TEXT,
        goal_id TEXT,
        installment_group_id TEXT,
        installment_index INTEGER NOT NULL DEFAULT 1,
        installment_total INTEGER NOT NULL DEFAULT 1,
        recurrence_rule TEXT NOT NULL DEFAULT 'none',
        tags_json TEXT NOT NULL DEFAULT '[]',
        notes TEXT,
        import_hash TEXT,
        is_invoice_payment INTEGER NOT NULL DEFAULT 0,
        is_ignored INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Migração: adiciona is_ignored em bancos já existentes.
    final txCols = await db.rawQuery('PRAGMA table_info(transactions)');
    if (!txCols.any((c) => c['name'] == 'is_ignored')) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN is_ignored INTEGER NOT NULL DEFAULT 0',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        year_month TEXT NOT NULL,
        limit_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL,
        target_date_iso TEXT,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_insights (
        id TEXT PRIMARY KEY,
        year_month TEXT NOT NULL UNIQUE,
        content_md TEXT NOT NULL,
        model TEXT NOT NULL,
        created_at_iso TEXT NOT NULL
      )
    ''');
  }

  // --- Accounts ---
  static Future<List<Account>> getAccounts() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('accounts');
      return rows.map((r) => Account.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAccount(Account account) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'accounts',
        account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteAccount(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('accounts', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- Credit Cards ---
  static Future<List<CreditCardModel>> getCreditCards() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('credit_cards');
      return rows.map((r) => CreditCardModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCreditCard(CreditCardModel card) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'credit_cards',
        card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteCreditCard(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('credit_cards', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- Invoices ---
  static Future<List<CreditCardInvoice>> getInvoices() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('invoices');
      return rows.map((r) => CreditCardInvoice.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInvoice(CreditCardInvoice invoice) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  // --- Categories ---
  static Future<List<CategoryModel>> getCategories() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('categories');
      return rows.map((r) => CategoryModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCategory(CategoryModel cat) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'categories',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteCategory(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('categories', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- Transactions ---
  static Future<List<TransactionModel>> getTransactions() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query(
        'transactions',
        orderBy: 'date_iso DESC',
      );
      return rows.map((r) => TransactionModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTransaction(TransactionModel tx) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'transactions',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteTransaction(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('transactions', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<void> deleteInstallmentGroup(String groupId) async {
    if (!isAvailable) return;
    try {
      await _database!.delete(
        'transactions',
        where: 'installment_group_id = ?',
        whereArgs: [groupId],
      );
    } catch (_) {}
  }

  // --- Budgets ---
  static Future<List<BudgetModel>> getBudgets() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('budgets');
      return rows.map((r) => BudgetModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBudget(BudgetModel budget) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'budgets',
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteBudget(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('budgets', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- Goals ---
  static Future<List<GoalModel>> getGoals() async {
    if (!isAvailable) return [];
    try {
      final rows = await _database!.query('goals');
      return rows.map((r) => GoalModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveGoal(GoalModel goal) async {
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'goals',
        goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> deleteGoal(String id) async {
    if (!isAvailable) return;
    try {
      await _database!.delete('goals', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- AI Insights ---
  static Future<String?> getAiInsight(String yearMonth) async {
    if (inMemoryAiInsights.containsKey(yearMonth)) {
      return inMemoryAiInsights[yearMonth];
    }
    if (!isAvailable) return null;
    try {
      final rows = await _database!.query(
        'ai_insights',
        where: 'year_month = ?',
        whereArgs: [yearMonth],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['content_md'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAiInsight({
    required String yearMonth,
    required String contentMd,
    required String model,
  }) async {
    inMemoryAiInsights[yearMonth] = contentMd;
    if (!isAvailable) return;
    try {
      await _database!.insert(
        'ai_insights',
        {
          'id': 'insight_$yearMonth',
          'year_month': yearMonth,
          'content_md': contentMd,
          'model': model,
          'created_at_iso': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> clearAllData() async {
    inMemoryAiInsights.clear();
    if (!isAvailable) return;
    try {
      await _database!.delete('transactions');
      await _database!.delete('invoices');
      await _database!.delete('budgets');
      await _database!.delete('goals');
      await _database!.delete('credit_cards');
      await _database!.delete('accounts');
      await _database!.delete('categories');
      await _database!.delete('ai_insights');
    } catch (_) {}
  }
}
