// ─── firebase_service.dart ──────────────────────────────────────────────────
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  factory FirebaseService() => _instance;
  const FirebaseService._();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  User? get currentUser => auth.currentUser;
  Stream<User?> get authStateStream => auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String username) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    await firestore.collection('users').doc(uid).set({
      'id': uid,
      'username': username,
      'initial_cash': 0,
      'upi_accounts': [],
      'custom_tags': [],
      'initial_amount_locked': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> logout() async => await auth.signOut();

  Stream<UserSettings> settingsStream(String uid) {
    return firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) return UserSettings.fromMap(snap.data()!);
      throw Exception('Settings doc missing for uid=$uid');
    });
  }

  Future<void> ensureSettingsDoc(String uid, String? email) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await firestore.collection('users').doc(uid).set({
        'id': uid,
        'username': email?.split('@')[0] ?? 'User',
        'initial_cash': 0,
        'upi_accounts': [],
        'custom_tags': [],
        'initial_amount_locked': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateSettings({
    required String uid,
    required String username,
    required double initialCash,
    required List<UpiAccount> upiAccounts,
    bool? lockInitialAmount,
  }) async {
    final data = <String, dynamic>{
      'username': username,
      'initial_cash': initialCash,
      'upi_accounts': upiAccounts.map((a) => a.toMap()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (lockInitialAmount == true) data['initial_amount_locked'] = true;
    await firestore.collection('users').doc(uid).update(data);
  }

  Future<void> addCustomTag(String uid, String tag) async {
    await firestore.collection('users').doc(uid).update({
      'custom_tags': FieldValue.arrayUnion([tag]),
    });
  }

  Future<void> removeCustomTag(String uid, String tag) async {
    await firestore.collection('users').doc(uid).update({
      'custom_tags': FieldValue.arrayRemove([tag]),
    });
  }

  Stream<List<Transaction>> transactionsStream(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('transaction_date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Transaction.fromMap(d.id, d.data())).toList());
  }

  Future<void> addTransaction({
    required String uid,
    required String type,
    required double amount,
    required String paymentMethod, // 'Cash' or bank name (e.g. 'HDFC')
    String? bankName,              // legacy param, ignored when paymentMethod != 'Cash'
    required String tag,
    required String transactionDate,
    String? description,
  }) async {
    // Store payment_method as 'Cash' or 'UPI.BankName' (e.g. 'UPI.HDFC')
    final isCash = paymentMethod == 'Cash';
    final storedPaymentMethod = isCash ? 'Cash' : 'UPI.$paymentMethod';
    final storedBankName = isCash ? null : paymentMethod; // also keep bank_name for compat

    await firestore.collection('users').doc(uid).collection('transactions').add({
      'user_id': uid,
      'type': type,
      'amount': amount,
      'payment_method': storedPaymentMethod, // 'Cash' or 'UPI.HDFC'
      'bank_name': storedBankName,           // 'HDFC' or null (for easy querying)
      'tag': tag,
      'description': description ?? '',
      'transaction_date': transactionDate,
    });
  }

  /// Reassign an old UPI transaction (bankName == null) to a specific bank
  Future<void> reassignTransactionBank({
    required String uid,
    required String transactionId,
    required String bankName,
  }) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transactionId)
        .update({'bank_name': bankName});
  }

  /// One-time migration: converts old records from
  ///   payment_method: "UPI"  +  bank_name: "CUB"
  /// to new format:
  ///   payment_method: "UPI.CUB"  +  bank_name: "CUB"
  ///
  /// Safe to call on every app start — skips records already in new format.
  /// Returns the number of records updated.
  /// One-time migration for old UPI records.
  /// Priority:
  ///   1. Record has its own bank_name  → use it  (e.g. "UPI.CUB")
  ///   2. bank_name missing/empty       → use user's first UPI account name
  ///   3. No UPI accounts at all        → leave as "UPI" (cannot determine)
  Future<int> migrateOldUpiRecords(String uid) async {
    // Fetch old-format records: payment_method == "UPI"
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('payment_method', isEqualTo: 'UPI')
        .get();

    if (snap.docs.isEmpty) return 0;

    // Get user's first UPI account as fallback
    final userDoc = await firestore.collection('users').doc(uid).get();
    String? firstBankName;
    if (userDoc.exists) {
      final upiAccounts = userDoc.data()?['upi_accounts'] as List?;
      if (upiAccounts != null && upiAccounts.isNotEmpty) {
        firstBankName = (upiAccounts.first as Map<String, dynamic>)['bankName'] as String?;
      }
    }

    WriteBatch batch = firestore.batch();
    int count = 0;
    int batchSize = 0;
    final batches = <WriteBatch>[];

    for (final doc in snap.docs) {
      // Use record's own bank_name first, else fall back to first UPI account
      final bankName = (doc.data()['bank_name'] as String?)?.trim();
      final resolvedBank = (bankName != null && bankName.isNotEmpty)
          ? bankName
          : firstBankName;

      // If still no bank name available, skip — cannot safely migrate
      if (resolvedBank == null || resolvedBank.isEmpty) continue;

      batch.update(doc.reference, {
        'payment_method': 'UPI.$resolvedBank',
        'bank_name': resolvedBank, // ensure bank_name is also set
      });
      count++;
      batchSize++;

      if (batchSize == 499) {
        batches.add(batch);
        batch = firestore.batch();
        batchSize = 0;
      }
    }

    if (batchSize > 0) batches.add(batch);
    for (final b in batches) await b.commit();

    return count;
  }
}