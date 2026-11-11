import 'dart:convert';
import 'package:flutter/material.dart';

enum AccountType {
  checking('Conta Corrente', Icons.account_balance_rounded),
  wallet('Carteira Física', Icons.account_balance_wallet_rounded),
  savings('Reserva / Poupança', Icons.savings_rounded),
  investment('Investimento', Icons.trending_up_rounded);

  final String label;
  final IconData defaultIcon;
  const AccountType(this.label, this.defaultIcon);

  static AccountType fromString(String? val) {
    return AccountType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AccountType.checking,
    );
  }
}

enum TransactionType {
  expense('Despesa'),
  income('Receita'),
  transfer('Transferência');

  final String label;
  const TransactionType(this.label);

  static TransactionType fromString(String? val) {
    return TransactionType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => TransactionType.expense,
    );
  }
}

enum TransactionStatus {
  paid('Pago / Efetivado'),
  pending('Pendente / Agendado');

  final String label;
  const TransactionStatus(this.label);

  static TransactionStatus fromString(String? val) {
    return TransactionStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => TransactionStatus.paid,
    );
  }
}

enum Pillar503020 {
  essential('Essenciais (50%)', 0.50),
  lifestyle('Estilo de Vida (30%)', 0.30),
  future('Futuro & Reserva (20%)', 0.20);

  final String label;
  final double targetRatio;
  const Pillar503020(this.label, this.targetRatio);

  static Pillar503020 fromString(String? val) {
    return Pillar503020.values.firstWhere(
      (e) => e.name == val,
      orElse: () => Pillar503020.essential,
    );
  }
}

enum BudgetRegime {
  competence('Por Competência da Fatura'),
  purchaseDate('Por Data da Compra');

  final String label;
  const BudgetRegime(this.label);

  static BudgetRegime fromString(String? val) {
    return BudgetRegime.values.firstWhere(
      (e) => e.name == val,
      orElse: () => BudgetRegime.competence,
    );
  }
}

enum RecurrenceRule {
  none('Única'),
  monthly('Mensal'),
  weekly('Semanal'),
  yearly('Anual');

  final String label;
  const RecurrenceRule(this.label);

  static RecurrenceRule fromString(String? val) {
    return RecurrenceRule.values.firstWhere(
      (e) => e.name == val,
      orElse: () => RecurrenceRule.none,
    );
  }
}

enum InvoiceStatus {
  open('Fatura Aberta'),
  closed('Fatura Fechada'),
  paid('Fatura Paga');

  final String label;
  const InvoiceStatus(this.label);

  static InvoiceStatus fromString(String? val) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => InvoiceStatus.open,
    );
  }
}

class AppIconsCatalog {
  static const Map<String, IconData> icons = {
    'home': Icons.home_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'restaurant': Icons.restaurant_rounded,
    'directions_car': Icons.directions_car_rounded,
    'favorite': Icons.favorite_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'school': Icons.school_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'work': Icons.work_rounded,
    'trending_up': Icons.trending_up_rounded,
    'savings': Icons.savings_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'pets': Icons.pets_rounded,
    'bolt': Icons.bolt_rounded,
    'account_balance': Icons.account_balance_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'credit_card': Icons.credit_card_rounded,
    'attach_money': Icons.attach_money_rounded,
    'redeem': Icons.redeem_rounded,
    'build': Icons.build_rounded,
    'shield': Icons.shield_rounded,
  };

  static IconData fromName(String? name) {
    return icons[name] ?? Icons.category_rounded;
  }
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double initialBalance;
  final double currentBalance;
  final int colorValue;
  final String iconName;
  final bool includeInNetWorth;
  final bool archived;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.currentBalance,
    required this.colorValue,
    required this.iconName,
    this.includeInNetWorth = true,
    this.archived = false,
  });

  Color get color => Color(colorValue);
  IconData get icon => AppIconsCatalog.icons[iconName] ?? type.defaultIcon;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? initialBalance,
    double? currentBalance,
    int? colorValue,
    String? iconName,
    bool? includeInNetWorth,
    bool? archived,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'initial_balance': initialBalance,
        'current_balance': currentBalance,
        'color_value': colorValue,
        'icon_name': iconName,
        'include_in_net_worth': includeInNetWorth ? 1 : 0,
        'archived': archived ? 1 : 0,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountType.fromString(m['type'] as String?),
        initialBalance: (m['initial_balance'] as num?)?.toDouble() ?? 0.0,
        currentBalance: (m['current_balance'] as num?)?.toDouble() ?? 0.0,
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF059669,
        iconName: (m['icon_name'] as String?) ?? 'account_balance',
        includeInNetWorth: (m['include_in_net_worth'] as num?) != 0,
        archived: (m['archived'] as num?) == 1,
      );
}

class CreditCardModel {
  final String id;
  final String name;
  final double creditLimit;
  final int closingDay;
  final int dueDay;
  final String? defaultAccountId;
  final int colorValue;
  final bool archived;

  const CreditCardModel({
    required this.id,
    required this.name,
    required this.creditLimit,
    required this.closingDay,
    required this.dueDay,
    this.defaultAccountId,
    required this.colorValue,
    this.archived = false,
  });

  Color get color => Color(colorValue);

  CreditCardModel copyWith({
    String? id,
    String? name,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
    String? defaultAccountId,
    int? colorValue,
    bool? archived,
  }) {
    return CreditCardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      colorValue: colorValue ?? this.colorValue,
      archived: archived ?? this.archived,
    );
  }

  /// Determina a competência (YYYY-MM) da fatura dado uma data de compra
  String computeCompetenceMonth(DateTime purchaseDate) {
    int year = purchaseDate.year;
    int month = purchaseDate.month;
    if (purchaseDate.day >= closingDay) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
    }
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'credit_limit': creditLimit,
        'closing_day': closingDay,
        'due_day': dueDay,
        'default_account_id': defaultAccountId,
        'color_value': colorValue,
        'archived': archived ? 1 : 0,
      };

  factory CreditCardModel.fromMap(Map<String, dynamic> m) => CreditCardModel(
        id: m['id'] as String,
        name: m['name'] as String,
        creditLimit: (m['credit_limit'] as num?)?.toDouble() ?? 0.0,
        closingDay: (m['closing_day'] as num?)?.toInt() ?? 1,
        dueDay: (m['due_day'] as num?)?.toInt() ?? 10,
        defaultAccountId: m['default_account_id'] as String?,
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF059669,
        archived: (m['archived'] as num?) == 1,
      );
}

class CreditCardInvoice {
  final String id;
  final String cardId;
  final String yearMonth; // YYYY-MM
  final InvoiceStatus status;
  final double paidAmount;
  final DateTime? paidAt;

  const CreditCardInvoice({
    required this.id,
    required this.cardId,
    required this.yearMonth,
    required this.status,
    this.paidAmount = 0.0,
    this.paidAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'card_id': cardId,
        'year_month': yearMonth,
        'status': status.name,
        'paid_amount': paidAmount,
        'paid_at': paidAt?.toIso8601String(),
      };

  factory CreditCardInvoice.fromMap(Map<String, dynamic> m) =>
      CreditCardInvoice(
        id: m['id'] as String,
        cardId: m['card_id'] as String,
        yearMonth: m['year_month'] as String,
        status: InvoiceStatus.fromString(m['status'] as String?),
        paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0.0,
        paidAt: m['paid_at'] != null
            ? DateTime.tryParse(m['paid_at'] as String)
            : null,
      );
}

class CategoryModel {
  final String id;
  final String name;
  final TransactionType type;
  final Pillar503020 pillar;
  final int colorValue;
  final String iconName;
  final bool isSystem;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.pillar = Pillar503020.essential,
    required this.colorValue,
    required this.iconName,
    this.isSystem = false,
  });

  Color get color => Color(colorValue);
  IconData get icon => AppIconsCatalog.fromName(iconName);

  CategoryModel copyWith({
    String? id,
    String? name,
    TransactionType? type,
    Pillar503020? pillar,
    int? colorValue,
    String? iconName,
    bool? isSystem,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pillar: pillar ?? this.pillar,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'pillar_503020': pillar.name,
        'color_value': colorValue,
        'icon_name': iconName,
        'is_system': isSystem ? 1 : 0,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'] as String,
        name: m['name'] as String,
        type: TransactionType.fromString(m['type'] as String?),
        pillar: Pillar503020.fromString(m['pillar_503020'] as String?),
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF059669,
        iconName: (m['icon_name'] as String?) ?? 'shopping_cart',
        isSystem: (m['is_system'] as num?) == 1,
      );
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String competenceMonth; // YYYY-MM (para fatura do cartão ou mês da transação)
  final TransactionStatus status;
  final String? accountId;
  final String? destinationAccountId;
  final String? cardId;
  final String? categoryId;
  final String? goalId;
  final String? installmentGroupId;
  final int installmentIndex;
  final int installmentTotal;
  final RecurrenceRule recurrenceRule;
  final List<String> tags;
  final String? notes;
  final String? importHash;
  final bool isInvoicePayment;
  final bool isIgnored;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.competenceMonth,
    required this.status,
    this.accountId,
    this.destinationAccountId,
    this.cardId,
    this.categoryId,
    this.goalId,
    this.installmentGroupId,
    this.installmentIndex = 1,
    this.installmentTotal = 1,
    this.recurrenceRule = RecurrenceRule.none,
    this.tags = const [],
    this.notes,
    this.importHash,
    this.isInvoicePayment = false,
    this.isIgnored = false,
  });

  bool get isCreditCard => cardId != null && cardId!.isNotEmpty;
  bool get isInstallment => installmentTotal > 1;
  String get purchaseYearMonth =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String effectiveMonth(BudgetRegime regime) {
    if (isCreditCard && regime == BudgetRegime.competence) {
      return competenceMonth;
    }
    return purchaseYearMonth;
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? competenceMonth,
    TransactionStatus? status,
    String? accountId,
    String? destinationAccountId,
    String? cardId,
    String? categoryId,
    String? goalId,
    String? installmentGroupId,
    int? installmentIndex,
    int? installmentTotal,
    RecurrenceRule? recurrenceRule,
    List<String>? tags,
    String? notes,
    String? importHash,
    bool? isInvoicePayment,
    bool? isIgnored,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      competenceMonth: competenceMonth ?? this.competenceMonth,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      cardId: cardId ?? this.cardId,
      categoryId: categoryId ?? this.categoryId,
      goalId: goalId ?? this.goalId,
      installmentGroupId: installmentGroupId ?? this.installmentGroupId,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      importHash: importHash ?? this.importHash,
      isInvoicePayment: isInvoicePayment ?? this.isInvoicePayment,
      isIgnored: isIgnored ?? this.isIgnored,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'date_iso': date.toIso8601String(),
        'competence_month': competenceMonth,
        'status': status.name,
        'account_id': accountId,
        'destination_account_id': destinationAccountId,
        'card_id': cardId,
        'category_id': categoryId,
        'goal_id': goalId,
        'installment_group_id': installmentGroupId,
        'installment_index': installmentIndex,
        'installment_total': installmentTotal,
        'recurrence_rule': recurrenceRule.name,
        'tags_json': jsonEncode(tags),
        'notes': notes,
        'import_hash': importHash,
        'is_invoice_payment': isInvoicePayment ? 1 : 0,
        'is_ignored': isIgnored ? 1 : 0,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) {
    List<String> parsedTags = [];
    final rawTags = m['tags_json'] as String?;
    if (rawTags != null && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags) as List<dynamic>;
        parsedTags = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    final dt = DateTime.tryParse(m['date_iso'] as String? ?? '') ??
        DateTime.now();
    return TransactionModel(
      id: m['id'] as String,
      title: m['title'] as String,
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.fromString(m['type'] as String?),
      date: dt,
      competenceMonth: (m['competence_month'] as String?) ??
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}',
      status: TransactionStatus.fromString(m['status'] as String?),
      accountId: m['account_id'] as String?,
      destinationAccountId: m['destination_account_id'] as String?,
      cardId: m['card_id'] as String?,
      categoryId: m['category_id'] as String?,
      goalId: m['goal_id'] as String?,
      installmentGroupId: m['installment_group_id'] as String?,
      installmentIndex: (m['installment_index'] as num?)?.toInt() ?? 1,
      installmentTotal: (m['installment_total'] as num?)?.toInt() ?? 1,
      recurrenceRule:
          RecurrenceRule.fromString(m['recurrence_rule'] as String?),
      tags: parsedTags,
      notes: m['notes'] as String?,
      importHash: m['import_hash'] as String?,
      isInvoicePayment: (m['is_invoice_payment'] as num?) == 1,
      isIgnored: (m['is_ignored'] as num?) == 1,
    );
  }
}

class BudgetModel {
  final String id;
  final String categoryId;
  final String yearMonth; // YYYY-MM
  final double limitAmount;

  const BudgetModel({
    required this.id,
    required this.categoryId,
    required this.yearMonth,
    required this.limitAmount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'year_month': yearMonth,
        'limit_amount': limitAmount,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> m) => BudgetModel(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        yearMonth: m['year_month'] as String,
        limitAmount: (m['limit_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final int colorValue;
  final String iconName;

  const GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.colorValue,
    required this.iconName,
  });

  Color get color => Color(colorValue);
  IconData get icon => AppIconsCatalog.fromName(iconName);
  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  GoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    int? colorValue,
    String? iconName,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'target_date_iso': targetDate?.toIso8601String(),
        'color_value': colorValue,
        'icon_name': iconName,
      };

  factory GoalModel.fromMap(Map<String, dynamic> m) => GoalModel(
        id: m['id'] as String,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num?)?.toDouble() ?? 0.0,
        currentAmount: (m['current_amount'] as num?)?.toDouble() ?? 0.0,
        targetDate: m['target_date_iso'] != null
            ? DateTime.tryParse(m['target_date_iso'] as String)
            : null,
        colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF10B981,
        iconName: (m['icon_name'] as String?) ?? 'savings',
      );
}

enum ImportTargetMode {
  checking('Conta Corrente'),
  creditCard('Fatura de Cartão'),
  cofrinho('Cofrinho / Caixinha'),
  transfer('Transferência');

  final String label;
  const ImportTargetMode(this.label);
}

enum CofrinhoOperationKind {
  deposit('Aporte (- Conta / + Cofrinho)'),
  withdraw('Resgate (+ Conta / - Cofrinho)'),
  yieldGain('Rendimento (+ Cofrinho)');

  final String label;
  const CofrinhoOperationKind(this.label);
}

class ImportedTransactionCandidate {
  final String title;
  final double amount;
  final DateTime date;
  TransactionType type;
  final String importHash;
  String? suggestedCategoryId;
  CofrinhoOperationKind cofrinhoOp;
  String? targetGoalId;
  String? counterpartAccountId;
  bool isOutgoingTransfer;
  bool selected;
  bool isDuplicate;
  bool ignored;

  ImportedTransactionCandidate({
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.importHash,
    this.suggestedCategoryId,
    this.cofrinhoOp = CofrinhoOperationKind.deposit,
    this.targetGoalId,
    this.counterpartAccountId,
    this.isOutgoingTransfer = true,
    this.selected = true,
    this.isDuplicate = false,
    this.ignored = false,
  });
}

class BackupPreviewInfo {
  final DateTime? timestamp;
  final int accountsCount;
  final int cardsCount;
  final int transactionsCount;
  final int goalsCount;

  const BackupPreviewInfo({
    this.timestamp,
    required this.accountsCount,
    required this.cardsCount,
    required this.transactionsCount,
    required this.goalsCount,
  });
}
