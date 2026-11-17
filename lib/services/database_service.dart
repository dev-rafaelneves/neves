import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  static const _prefFallbackCats = 'neves_mvp_fb_categories';
  static const _prefFallbackCards = 'neves_mvp_fb_cards';
  static const _prefFallbackTxs = 'neves_mvp_fb_transactions';

  Database? _db;
  bool _inMemoryMode = false;
  bool _isTestMode = false;
  bool _fallbackLoaded = false;

  final List<CategoryItem> _memCategories = [];
  final List<CreditCardItem> _memCards = [];
  final List<TransactionItem> _memTransactions = [];

  void enableInMemoryModeForTest() {
    _inMemoryMode = true;
    _isTestMode = true;
    _fallbackLoaded = true;
    _memCategories
      ..clear()
      ..addAll(CategoryItem.defaultCategories());
    _memCards
      ..clear()
      ..addAll(CreditCardItem.defaultCards());
    _memTransactions.clear();
  }

  Future<Database?> get database async {
    if (_inMemoryMode || kIsWeb) {
      await _ensureFallbackInitialized();
      return null;
    }
    if (_db != null) return _db;
    try {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, 'neves_mvp_v2.db');
      _db = await openDatabase(
        fullPath,
        version: 3,
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seedDefaults(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            try {
              await db.execute(
                'ALTER TABLE transactions ADD COLUMN isIgnored INTEGER NOT NULL DEFAULT 0',
              );
            } catch (_) {}
          }
          if (oldVersion < 3) {
            try {
              await db.execute(
                'ALTER TABLE categories ADD COLUMN monthlyBudget REAL NOT NULL DEFAULT 0',
              );
            } catch (_) {}
          }
        },
      );
      return _db;
    } catch (_) {
      _inMemoryMode = true;
      await _ensureFallbackInitialized();
      return null;
    }
  }

  Future<void> _ensureFallbackInitialized() async {
    if (_fallbackLoaded) return;
    _fallbackLoaded = true;

    if (_isTestMode) {
      if (_memCategories.isEmpty) {
        _memCategories.addAll(CategoryItem.defaultCategories());
      }
      if (_memCards.isEmpty) {
        _memCards.addAll(CreditCardItem.defaultCards());
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final catsJson = prefs.getString(_prefFallbackCats);
      final cardsJson = prefs.getString(_prefFallbackCards);
      final txsJson = prefs.getString(_prefFallbackTxs);

      if (catsJson != null) {
        final list = jsonDecode(catsJson) as List<dynamic>;
        _memCategories
          ..clear()
          ..addAll(
            list.map(
              (e) => CategoryItem.fromMap(Map<String, dynamic>.from(e as Map)),
            ),
          );
      } else {
        _memCategories
          ..clear()
          ..addAll(CategoryItem.defaultCategories());
      }

      if (cardsJson != null) {
        final list = jsonDecode(cardsJson) as List<dynamic>;
        _memCards
          ..clear()
          ..addAll(
            list.map(
              (e) =>
                  CreditCardItem.fromMap(Map<String, dynamic>.from(e as Map)),
            ),
          );
      } else {
        _memCards
          ..clear()
          ..addAll(CreditCardItem.defaultCards());
      }

      if (txsJson != null) {
        final list = jsonDecode(txsJson) as List<dynamic>;
        _memTransactions
          ..clear()
          ..addAll(
            list.map(
              (e) =>
                  TransactionItem.fromMap(Map<String, dynamic>.from(e as Map)),
            ),
          );
      }
      await _saveFallbackToPrefs();
    } catch (_) {
      if (_memCategories.isEmpty) {
        _memCategories.addAll(CategoryItem.defaultCategories());
      }
      if (_memCards.isEmpty) {
        _memCards.addAll(CreditCardItem.defaultCards());
      }
    }
  }

  Future<void> _saveFallbackToPrefs() async {
    if (_isTestMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefFallbackCats,
        jsonEncode(_memCategories.map((c) => c.toMap()).toList()),
      );
      await prefs.setString(
        _prefFallbackCards,
        jsonEncode(_memCards.map((c) => c.toMap()).toList()),
      );
      await prefs.setString(
        _prefFallbackTxs,
        jsonEncode(_memTransactions.map((t) => t.toMap()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconKey TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        type TEXT NOT NULL,
        monthlyBudget REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE credit_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        closingDay INTEGER NOT NULL,
        dueDay INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        competenceMonth TEXT NOT NULL,
        type TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        cardId TEXT,
        groupId TEXT,
        installmentIndex INTEGER NOT NULL DEFAULT 1,
        installmentTotal INTEGER NOT NULL DEFAULT 1,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        isIgnored INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tx_month ON transactions(competenceMonth)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_group ON transactions(groupId)',
    );
  }

  Future<void> _seedDefaults(Database db) async {
    final batch = db.batch();
    for (final cat in CategoryItem.defaultCategories()) {
      batch.insert(
        'categories',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final card in CreditCardItem.defaultCards()) {
      batch.insert(
        'credit_cards',
        card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryItem>> loadCategories() async {
    final db = await database;
    if (db == null) {
      return List<CategoryItem>.from(_memCategories);
    }
    final rows = await db.query('categories');
    if (rows.isEmpty) {
      await _seedDefaults(db);
      final seeded = await db.query('categories');
      return seeded.map(CategoryItem.fromMap).toList();
    }
    return rows.map(CategoryItem.fromMap).toList();
  }

  Future<List<CreditCardItem>> loadCards() async {
    final db = await database;
    if (db == null) {
      return List<CreditCardItem>.from(_memCards);
    }
    final rows = await db.query('credit_cards');
    return rows.map(CreditCardItem.fromMap).toList();
  }

  Future<List<TransactionItem>> loadTransactions() async {
    final db = await database;
    if (db == null) {
      return List<TransactionItem>.from(_memTransactions);
    }
    final rows = await db.query('transactions', orderBy: 'date DESC');
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<void> upsertCategory(CategoryItem category) async {
    final db = await database;
    if (db == null) {
      final idx = _memCategories.indexWhere((c) => c.id == category.id);
      if (idx >= 0) {
        _memCategories[idx] = category;
      } else {
        _memCategories.add(category);
      }
      await _saveFallbackToPrefs();
      return;
    }
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    if (db == null) {
      _memCategories.removeWhere((c) => c.id == id);
      await _saveFallbackToPrefs();
      return;
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertCard(CreditCardItem card) async {
    final db = await database;
    if (db == null) {
      final idx = _memCards.indexWhere((c) => c.id == card.id);
      if (idx >= 0) {
        _memCards[idx] = card;
      } else {
        _memCards.add(card);
      }
      await _saveFallbackToPrefs();
      return;
    }
    await db.insert(
      'credit_cards',
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCard(String id) async {
    final db = await database;
    if (db == null) {
      _memCards.removeWhere((c) => c.id == id);
      _memTransactions.removeWhere((t) => t.cardId == id);
      await _saveFallbackToPrefs();
      return;
    }
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'cardId = ?', whereArgs: [id]);
      await txn.delete('credit_cards', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> upsertTransactionsBatch(List<TransactionItem> items) async {
    if (items.isEmpty) return;
    final db = await database;
    if (db == null) {
      for (final item in items) {
        final idx = _memTransactions.indexWhere((t) => t.id == item.id);
        if (idx >= 0) {
          _memTransactions[idx] = item;
        } else {
          _memTransactions.add(item);
        }
      }
      await _saveFallbackToPrefs();
      return;
    }
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'transactions',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTransactionIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    if (db == null) {
      final set = ids.toSet();
      _memTransactions.removeWhere((t) => set.contains(t.id));
      await _saveFallbackToPrefs();
      return;
    }
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('transactions', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllData({
    required List<CategoryItem> categories,
    required List<CreditCardItem> cards,
    required List<TransactionItem> transactions,
  }) async {
    final db = await database;
    if (db == null) {
      _memCategories
        ..clear()
        ..addAll(categories);
      _memCards
        ..clear()
        ..addAll(cards);
      _memTransactions
        ..clear()
        ..addAll(transactions);
      await _saveFallbackToPrefs();
      return;
    }
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('credit_cards');
      await txn.delete('categories');
      final batch = txn.batch();
      for (final c in categories) {
        batch.insert('categories', c.toMap());
      }
      for (final card in cards) {
        batch.insert('credit_cards', card.toMap());
      }
      for (final tx in transactions) {
        batch.insert('transactions', tx.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
