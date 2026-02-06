// ─── firebase_service.dart ──────────────────────────────────────────────────
//
// Single source of truth for Firebase config, Auth, and Firestore.
// Mirrors the React AuthContext + lib/firebase.ts combined.
//
// pubspec.yaml deps required:
//   firebase_core: ^2.x
//   firebase_auth: ^4.x
//   cloud_firestore: ^4.x
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'models.dart';

class FirebaseService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final FirebaseService _instance = FirebaseService._();
  factory FirebaseService() => _instance;
  const FirebaseService._();

  // ── Core refs ────────────────────────────────────────────────────────────
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Currently signed-in user (null when logged out).
  User? get currentUser => auth.currentUser;

  // ── Auth stream (mirrors onAuthStateChanged) ────────────────────────────
  Stream<User?> get authStateStream => auth.authStateChanges();

  // ── Sign In ──────────────────────────────────────────────────────────────
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ── Sign Up ──────────────────────────────────────────────────────────────
  /// Creates user, then writes the default settings doc (mirrors React signUp).
  Future<void> signUp(String email, String password, String username) async {
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    await firestore.collection('users').doc(uid).set({
      'id': uid,
      'username': username,
      'initial_amount': 0,
      'initial_cash': 0,
      'initial_upi': 0,
      'custom_tags': [],
      'initial_amount_locked': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await auth.signOut();
  }

  // ── Settings listeners / writers ─────────────────────────────────────────

  /// Real-time stream of the current user's settings doc.
  Stream<UserSettings> settingsStream(String uid) {
    return firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) {
        return UserSettings.fromMap(snap.data()!);
      }
      // Should not normally happen; signUp creates the doc.
      throw Exception('Settings doc missing for uid=$uid');
    });
  }

  /// Ensures the settings doc exists; creates default if missing.
  Future<void> ensureSettingsDoc(String uid, String? email) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await firestore.collection('users').doc(uid).set({
        'id': uid,
        'username': email?.split('@')[0] ?? 'User',
        'initial_amount': 0,
        'initial_cash': 0,
        'initial_upi': 0,
        'custom_tags': [],
        'initial_amount_locked': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Update username + initial balances (mirrors React Settings handleSubmit).
  Future<void> updateSettings({
    required String uid,
    required String username,
    required double initialCash,
    required double initialUpi,
    bool? lockInitialAmount,
  }) async {
    final total = initialCash + initialUpi;
    final data = <String, dynamic>{
      'username': username,
      'initial_amount': total,
      'initial_cash': initialCash,
      'initial_upi': initialUpi,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (lockInitialAmount == true) {
      data['initial_amount_locked'] = true;
    }

    await firestore.collection('users').doc(uid).update(data);
  }

  /// Add a custom tag (arrayUnion).
  Future<void> addCustomTag(String uid, String tag) async {
    await firestore.collection('users').doc(uid).update({
      'custom_tags': FieldValue.arrayUnion([tag]),
    });
  }

  /// Remove a custom tag (arrayRemove).
  Future<void> removeCustomTag(String uid, String tag) async {
    await firestore.collection('users').doc(uid).update({
      'custom_tags': FieldValue.arrayRemove([tag]),
    });
  }

  // ── Transaction listeners / writers ──────────────────────────────────────

  /// Real-time stream of transactions ordered by date desc.
  Stream<List<Transaction>> transactionsStream(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('transaction_date', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => Transaction.fromMap(d.id, d.data()))
              .toList();
        });
  }

  /// Add a new transaction doc (mirrors React handleSubmit in TransactionForm).
  Future<void> addTransaction({
    required String uid,
    required String type,
    required double amount,
    required String paymentMethod,
    required String tag,
    required String transactionDate,
    String? description,
  }) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
          'user_id': uid,
          'type': type,
          'amount': amount,
          'payment_method': paymentMethod,
          'tag': tag,
          'description': description ?? '',
          'transaction_date': transactionDate,
        });
  }
}