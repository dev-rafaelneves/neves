import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum TransactionType {
  expense('Despesa'),
  income('Receita');

  final String label;
  const TransactionType(this.label);

  static TransactionType fromString(String? val) {
    return TransactionType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => TransactionType.expense,
    );
  }
}

enum PaymentMethod {
  cash('Conta Corrente'),
  creditCard('Cartão de Crédito');

  final String label;
  const PaymentMethod(this.label);

  static PaymentMethod fromString(String? val) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == val,
      orElse: () => PaymentMethod.cash,
    );
  }
}

class AppIconsCatalog {
  static const Map<String, IconData> icons = {
    'restaurant': Icons.restaurant_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'home': Icons.home_rounded,
    'directions_car': Icons.directions_car_rounded,
    'favorite': Icons.favorite_rounded,
    'Flight': Icons.flight_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'school': Icons.school_rounded,
    'pets': Icons.pets_rounded,
    'work': Icons.work_rounded,
    'Attach_money': Icons.attach_money_rounded,
    'trending_up': Icons.trending_up_rounded,
    'redeem': Icons.redeem_rounded,
    'category': Icons.category_rounded,
  };

  static IconData fromKey(String key) {
    return icons[key] ?? Icons.category_rounded;
  }
}

class CategoryItem {
  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final TransactionType type;
  final double monthlyBudget;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.type,
    this.monthlyBudget = 0.0,
  });

  Color get color => Color(colorValue);
  IconData get icon => AppIconsCatalog.fromKey(iconKey);
  bool get hasBudget =>
      type == TransactionType.expense && monthlyBudget > 0.005;

  CategoryItem copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorValue,
    TransactionType? type,
    double? monthlyBudget,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      type: type ?? this.type,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'type': type.name,
        'monthlyBudget': monthlyBudget,
      };

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: (map['iconKey'] as String?) ?? 'category',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF059669,
      type: TransactionType.fromString(map['type'] as String?),
      monthlyBudget: (map['monthlyBudget'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static List<CategoryItem> defaultCategories() => const [
        // Despesas
        CategoryItem(
          id: 'cat_food',
          name: 'Alimentação & Mercado',
          iconKey: 'restaurant',
          colorValue: 0xFFF97316,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_home',
          name: 'Moradia & Contas',
          iconKey: 'home',
          colorValue: 0xFF3B82F6,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_transport',
          name: 'Transporte',
          iconKey: 'directions_car',
          colorValue: 0xFF06B6D4,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_health',
          name: 'Saúde & Farmácia',
          iconKey: 'favorite',
          colorValue: 0xFFF43F5E,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_leisure',
          name: 'Lazer & Restaurantes',
          iconKey: 'sports_esports',
          colorValue: 0xFF8B5CF6,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_shopping',
          name: 'Compras',
          iconKey: 'shopping_bag',
          colorValue: 0xFFF59E0B,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_subs',
          name: 'Assinaturas & Serviços',
          iconKey: 'subscriptions',
          colorValue: 0xFF6366F1,
          type: TransactionType.expense,
        ),
        CategoryItem(
          id: 'cat_other_exp',
          name: 'Outros Gastos',
          iconKey: 'category',
          colorValue: 0xFF64748B,
          type: TransactionType.expense,
        ),
        // Receitas
        CategoryItem(
          id: 'cat_salary',
          name: 'Salário',
          iconKey: 'work',
          colorValue: 0xFF059669,
          type: TransactionType.income,
        ),
        CategoryItem(
          id: 'cat_extra',
          name: 'Renda Extra',
          iconKey: 'Attach_money',
          colorValue: 0xFF10B981,
          type: TransactionType.income,
        ),
        CategoryItem(
          id: 'cat_invest_inc',
          name: 'Rendimentos',
          iconKey: 'trending_up',
          colorValue: 0xFF0D9488,
          type: TransactionType.income,
        ),
      ];
}

class CreditCardItem {
  final String id;
  final String name;
  final int colorValue;
  final int closingDay; // 1..31
  final int dueDay; // 1..31

  const CreditCardItem({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.closingDay,
    required this.dueDay,
  });

  Color get color => Color(colorValue);

  /// Sugere o mês da fatura ('YYYY-MM') com base na data da compra e no dia de fechamento.
  /// Se o dia da compra for maior ou igual ao dia de fechamento, cai na fatura do mês seguinte.
  String suggestInvoiceMonth(DateTime purchaseDate) {
    final baseYm = AppFormatters.yearMonthFromDate(purchaseDate);
    if (purchaseDate.day >= closingDay) {
      return AppFormatters.addMonths(baseYm, 1);
    }
    return baseYm;
  }

  CreditCardItem copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? closingDay,
    int? dueDay,
  }) {
    return CreditCardItem(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'closingDay': closingDay,
        'dueDay': dueDay,
      };

  factory CreditCardItem.fromMap(Map<String, dynamic> map) {
    return CreditCardItem(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF8B5CF6,
      closingDay: ((map['closingDay'] as num?)?.toInt() ?? 25).clamp(1, 31),
      dueDay: ((map['dueDay'] as num?)?.toInt() ?? 5).clamp(1, 31),
    );
  }

  static List<CreditCardItem> defaultCards() => const [
        CreditCardItem(
          id: 'card_default',
          name: 'Cartão Principal',
          colorValue: 0xFF8B5CF6,
          closingDay: 25,
          dueDay: 5,
        ),
      ];
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String competenceMonth; // 'YYYY-MM' (Mês em que conta no resumo / fatura)
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final String categoryId;
  final String? cardId;
  final String? groupId; // Compartilhado entre parcelas da mesma compra ou recorrências fixas
  final int installmentIndex;
  final int installmentTotal;
  final bool isRecurring;
  final bool isIgnored;
  final bool isInvoicePayment;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.competenceMonth,
    required this.type,
    required this.paymentMethod,
    required this.categoryId,
    this.cardId,
    this.groupId,
    this.installmentIndex = 1,
    this.installmentTotal = 1,
    this.isRecurring = false,
    this.isIgnored = false,
    this.isInvoicePayment = false,
  });

  bool get isInstallment => installmentTotal > 1;
  bool get isCreditCard =>
      type == TransactionType.expense &&
      paymentMethod == PaymentMethod.creditCard &&
      cardId != null;

  TransactionItem copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? competenceMonth,
    TransactionType? type,
    PaymentMethod? paymentMethod,
    String? categoryId,
    String? cardId,
    String? groupId,
    int? installmentIndex,
    int? installmentTotal,
    bool? isRecurring,
    bool? isIgnored,
    bool? isInvoicePayment,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      competenceMonth: competenceMonth ?? this.competenceMonth,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      categoryId: categoryId ?? this.categoryId,
      cardId: cardId ?? this.cardId,
      groupId: groupId ?? this.groupId,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
      isRecurring: isRecurring ?? this.isRecurring,
      isIgnored: isIgnored ?? this.isIgnored,
      isInvoicePayment: isInvoicePayment ?? this.isInvoicePayment,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'competenceMonth': competenceMonth,
        'type': type.name,
        'paymentMethod': paymentMethod.name,
        'categoryId': categoryId,
        'cardId': cardId,
        'groupId': groupId,
        'installmentIndex': installmentIndex,
        'installmentTotal': installmentTotal,
        'isRecurring': isRecurring ? 1 : 0,
        'isIgnored': isIgnored ? 1 : 0,
        'isInvoicePayment': isInvoicePayment ? 1 : 0,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    final parsedDate =
        DateTime.tryParse((map['date'] as String?) ?? '') ?? DateTime.now();
    final rawTitle = (map['title'] as String?) ?? '';
    final rawAmount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    final payment = PaymentMethod.fromString(map['paymentMethod'] as String?);
    final explicitInvPay =
        (map['isInvoicePayment'] == 1 || map['isInvoicePayment'] == true);
    final lowerTitle = rawTitle.toLowerCase();
    final autoInvPay = !explicitInvPay &&
        payment == PaymentMethod.creditCard &&
        (lowerTitle.contains('pagamento antecipado') ||
            lowerTitle.contains('adiantamento de fatura') ||
            lowerTitle.contains('pagamento da fatura'));
    final isInvPay = explicitInvPay || autoInvPay;

    return TransactionItem(
      id: map['id'] as String,
      title: rawTitle,
      amount: isInvPay ? rawAmount.abs() : rawAmount,
      date: parsedDate,
      competenceMonth: (map['competenceMonth'] as String?) ??
          AppFormatters.yearMonthFromDate(parsedDate),
      type: TransactionType.fromString(map['type'] as String?),
      paymentMethod: payment,
      categoryId: (map['categoryId'] as String?) ?? 'cat_other_exp',
      cardId: map['cardId'] as String?,
      groupId: map['groupId'] as String?,
      installmentIndex: (map['installmentIndex'] as num?)?.toInt() ?? 1,
      installmentTotal: (map['installmentTotal'] as num?)?.toInt() ?? 1,
      isRecurring: (map['isRecurring'] == 1 || map['isRecurring'] == true),
      isIgnored: (map['isIgnored'] == 1 || map['isIgnored'] == true),
      isInvoicePayment: isInvPay,
    );
  }
}

class CategoryExpenseSummary {
  final CategoryItem category;
  final double amount;
  final double percentage; // Fatia sobre o total de saídas do mês
  final int count;

  const CategoryExpenseSummary({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });

  bool get hasBudget => category.hasBudget;
  double get budget => category.monthlyBudget;
  double get budgetRatio =>
      hasBudget ? (amount / budget).clamp(0.0, 1.0) : percentage;
  double get rawBudgetPercent => hasBudget ? (amount / budget) * 100.0 : 0.0;
  double get remainingBudget => hasBudget ? (budget - amount) : 0.0;
  bool get isOverBudget => hasBudget && amount > budget + 0.005;
  bool get isWarningBudget =>
      hasBudget && !isOverBudget && (amount / budget) >= 0.80;
}
