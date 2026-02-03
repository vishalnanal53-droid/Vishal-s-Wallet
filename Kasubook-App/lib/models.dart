// ─── models.dart ────────────────────────────────────────────────────────────

class Transaction {
  final String id;
  final String type; // 'income' | 'expense'
  final double amount;
  final String paymentMethod; // 'UPI' | 'Cash'
  final String transactionDate; // ISO-8601 date string
  final String tag;
  final String description;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.transactionDate,
    required this.tag,
    this.description = '',
  });

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    return Transaction(
      id: id,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      transactionDate: map['transaction_date'] as String,
      tag: map['tag'] as String,
      description: (map['description'] as String?) ?? '',
    );
  }
}

class UserSettings {
  final String id;
  final String username;
  final double initialAmount;
  final double initialCash;
  final double initialUpi;
  final List<String> customTags;
  final String createdAt;
  final String updatedAt;

  const UserSettings({
    required this.id,
    required this.username,
    this.initialAmount = 0,
    this.initialCash = 0,
    this.initialUpi = 0,
    this.customTags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as String,
      username: map['username'] as String,
      initialAmount: (map['initial_amount'] as num).toDouble(),
      initialCash: (map['initial_cash'] as num).toDouble(),
      initialUpi: (map['initial_upi'] as num).toDouble(),
      customTags: (map['custom_tags'] as List<dynamic>).cast<String>(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}