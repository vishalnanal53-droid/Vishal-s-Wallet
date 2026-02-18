// models.dart

class UpiAccount {
  final String id;
  final String bankName;
  final double initialBalance;

  UpiAccount({required this.id, required this.bankName, required this.initialBalance});

  Map<String, dynamic> toMap() => {
        'id': id,
        'bankName': bankName,
        'initialBalance': initialBalance,
      };

  factory UpiAccount.fromMap(Map<String, dynamic> map) => UpiAccount(
        id: map['id'] ?? '',
        bankName: map['bankName'] ?? 'Unknown Bank',
        initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0.0,
      );
}

class Transaction {
  final String id;
  final String type;
  final double amount;

  /// Stored as 'Cash' or 'UPI.BankName' (e.g. 'UPI.HDFC') in Firestore.
  /// Legacy records may still have 'UPI' with a separate bank_name field.
  final String paymentMethod;

  /// Legacy fallback: separate bank_name field from old records
  final String? bankName;

  /// 'Cash' or 'UPI'
  String get method => paymentMethod.startsWith('UPI') ? 'UPI' : 'Cash';

  /// Resolved bank name: from 'UPI.HDFC' → 'HDFC', or legacy bank_name field
  String? get resolvedBank {
    if (!paymentMethod.startsWith('UPI')) return null;
    if (paymentMethod.contains('.')) {
      return paymentMethod.substring(paymentMethod.indexOf('.') + 1);
    }
    return bankName; // legacy fallback
  }

  /// Full display label e.g. 'UPI · HDFC' or 'Cash'
  String get paymentLabel {
    if (method == 'Cash') return 'Cash';
    final bank = resolvedBank;
    return (bank != null && bank.isNotEmpty) ? 'UPI · $bank' : 'UPI';
  }

  final String transactionDate;
  final String tag;
  final String description;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    this.bankName,
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
      bankName: map['bank_name'] as String?,
      transactionDate: map['transaction_date'] as String,
      tag: map['tag'] as String,
      description: (map['description'] as String?) ?? '',
    );
  }
}

class UserSettings {
  final String id;
  final String username;
  final double initialCash;
  final List<UpiAccount> upiAccounts;
  final List<String> customTags;
  final bool initialAmountLocked;

  const UserSettings({
    required this.id,
    required this.username,
    required this.initialCash,
    required this.upiAccounts,
    this.customTags = const [],
    this.initialAmountLocked = false,
  });

  double get totalUpi => upiAccounts.fold(0.0, (sum, a) => sum + a.initialBalance);
  double get initialAmount => initialCash + totalUpi;
  double get initialUpi => totalUpi;

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    List<UpiAccount> upiAccounts;
    if (map['upi_accounts'] != null) {
      upiAccounts = (map['upi_accounts'] as List)
          .map((b) => UpiAccount.fromMap(b as Map<String, dynamic>))
          .toList();
    } else {
      final legacyUpi = (map['initial_upi'] as num?)?.toDouble() ?? 0.0;
      upiAccounts = legacyUpi > 0
          ? [UpiAccount(id: 'legacy', bankName: 'UPI', initialBalance: legacyUpi)]
          : [];
    }
    return UserSettings(
      id: map['id'] as String,
      username: map['username'] as String,
      initialCash: (map['initial_cash'] as num?)?.toDouble() ?? 0.0,
      upiAccounts: upiAccounts,
      customTags: (map['custom_tags'] as List?)?.cast<String>() ?? [],
      initialAmountLocked: (map['initial_amount_locked'] as bool?) ?? false,
    );
  }
}