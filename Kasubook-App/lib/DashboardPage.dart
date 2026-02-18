// ─── dashboard_page.dart ────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction, Settings;
import 'models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'transaction_form.dart';
import 'transaction_history.dart';
import 'settings.dart';
import 'analytics_page.dart';

// ── Dark Theme Color Palette ──────────────────────────────────────────────────
const _kBg        = Color(0xFF1A1B2E);
const _kCard      = Color(0xFF242535);
const _kCardBorder= Color(0xFF2E2F45);
const _kAccent    = Color(0xFF7C3AED);
const _kAccent2   = Color(0xFF8B5CF6);
const _kTextPrim  = Color(0xFFFFFFFF);
const _kTextSec   = Color(0xFFA0A3BD);
const _kNavBg     = Color(0xFF1E1F32);
const _kNavBorder = Color(0xFF2A2B40);
const _kGreen     = Color(0xFF22C55E);
const _kRed       = Color(0xFFEF4444);

enum _View { dashboard, history, analytics, settings }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _View _view = _View.dashboard;
  final PageController _pageController = PageController();
  List<Transaction> _transactions = [];
  UserSettings? _settings;
  bool _loading = true;

  final _fb = FirebaseService();
  final _notificationService = NotificationService();

  dynamic _settingsSub;
  dynamic _transactionsSub;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _settingsSub?.cancel();
    _transactionsSub?.cancel();
    _notificationService.stopAdminNotificationListener();
    _notificationService.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    await _notificationService.init();
    await _notificationService.initFCM();
    await _notificationService.requestPermissions();
    _notificationService.startAdminNotificationListener(uid);

    await _fb.ensureSettingsDoc(uid, _fb.currentUser?.email);

    // Migrate old UPI records (payment_method:"UPI" → "UPI.BankName") silently on login
    _fb.migrateOldUpiRecords(uid).then((count) {
      if (count > 0) debugPrint('[Migration] Updated $count old UPI record(s) to new format');
    }).catchError((e) => debugPrint('[Migration] Error: $e'));

    _settingsSub = _fb.settingsStream(uid).listen((settings) {
      if (mounted) setState(() => _settings = settings);
    }, onError: (e) => debugPrint('Settings stream error: $e'));

    _transactionsSub = _fb.transactionsStream(uid).listen((txs) {
      if (mounted) {
        setState(() { _transactions = txs.cast<Transaction>(); _loading = false; });
        _autoAssignUnassignedUpi(uid, txs.cast<Transaction>());
      }
    }, onError: (e) {
      debugPrint('Transactions stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _autoAssignUnassignedUpi(String uid, List<Transaction> txs) async {
    final accounts = _settings?.upiAccounts ?? [];
    if (accounts.isEmpty) return;
    final firstBank = accounts.first.bankName;
    final unassigned = txs.where((t) => t.method == 'UPI' && (t.resolvedBank == null || t.resolvedBank!.isEmpty)).toList();
    if (unassigned.isEmpty) return;
    for (final tx in unassigned) {
      await _fb.reassignTransactionBank(uid: uid, transactionId: tx.id, bankName: firstBank);
    }
  }

  double _calculateBalance() {
    final totalIncome = _transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = _transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    return (_settings?.initialAmount ?? 0) + totalIncome - totalExpense;
  }

  Map<String, double> _calculateBreakdown() {
    final cash = _transactions.where((t) => t.method == 'Cash').fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    final upi = _transactions.where((t) => t.method == 'UPI').fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    return {
      'cash': cash + (_settings?.initialCash ?? 0),
      'upi': upi + (_settings?.totalUpi ?? 0),
    };
  }

  Map<String, double> _calculateUpiAccountBalances() {
    final accounts = _settings?.upiAccounts ?? [];
    final result = <String, double>{};
    for (final acc in accounts) {
      final net = _transactions
          .where((t) => t.method == 'UPI' && t.resolvedBank == acc.bankName)
          .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
      result[acc.bankName] = acc.initialBalance + net;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingScreen();

    final breakdown = _calculateBreakdown();
    final upiAccountBalances = _calculateUpiAccountBalances();

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final headerH = constraints.maxHeight * 0.30;
          final contentH = constraints.maxHeight * 0.70;

          return Column(
            children: [
              SizedBox(height: headerH, child: _header(breakdown, upiAccountBalances)),
              SizedBox(
                height: contentH,
                child: Column(
                  children: [
                    _navBar(),
                    Expanded(
                      child: Container(
                        color: _kBg,
                        child: PageView(
                          controller: _pageController,
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: TransactionForm(transactions: _transactions, settings: _settings),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: TransactionHistory(transactions: _transactions, settings: _settings),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _settings != null ? Settings(settings: _settings!) : const SizedBox(),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _settings != null
                                  ? AnalyticsPage(transactions: _transactions, settings: _settings!)
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Map<String, double> breakdown, Map<String, double> upiAccountBalances) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A1B2E), Color(0xFF1E1040)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(80), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KasuBook', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kTextPrim)),
                          Text('Hello, ${_settings?.username ?? 'User'}!', style: const TextStyle(fontSize: 12, color: _kTextSec)),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _fb.logout(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: _kTextSec, size: 16),
                          SizedBox(width: 5),
                          Text('Logout', style: TextStyle(color: _kTextSec, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Accounts List
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _accountCard(label: 'Cash', amount: breakdown['cash']!, icon: Icons.currency_rupee),
                        ...upiAccountBalances.entries.map((e) => _accountCard(label: e.key, amount: e.value, icon: Icons.account_balance_outlined)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountCard({required String label, required double amount, required IconData icon}) {
    final isPositive = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 12)],
      ),
      constraints: const BoxConstraints(minWidth: 145),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kAccent2, size: 15),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: _kTextSec, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(color: isPositive ? _kTextPrim : _kRed, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _navBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _kNavBg,
        border: Border(
          top: BorderSide(color: _kNavBorder),
          bottom: BorderSide(color: _kNavBorder),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              _navButton(0, 'Dashboard', Icons.account_balance_wallet_rounded),
              _navButton(1, 'History', Icons.history_rounded),
              _navButton(2, 'Analytics', Icons.analytics_rounded),
              _navButton(3, 'Settings', Icons.settings_rounded),
            ],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double page = 0;
                if (_pageController.hasClients && _pageController.page != null) {
                  page = _pageController.page!;
                }
                return Align(
                  alignment: Alignment(-1 + (page * (2 / 3)), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 4,
                    child: Container(height: 3, decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(2),
                    )),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(int index, String label, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double page = 0;
            if (_pageController.hasClients && _pageController.page != null) page = _pageController.page!;
            double diff = (page - index).abs().clamp(0.0, 1.0);
            Color color = Color.lerp(_kAccent2, _kTextSec, diff)!;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _loadingScreen() {
    return Container(
      color: _kBg,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED)),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: _kTextSec, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}