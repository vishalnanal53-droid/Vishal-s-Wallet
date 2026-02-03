// ─── dashboard_page.dart ────────────────────────────────────────────────────
//
// Main screen after login.  Subscribes to Firestore via FirebaseService
// and hosts the three tab views: TransactionForm, TransactionHistory, Settings.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'models.dart';
import 'firebase_service.dart';
import 'transaction_form.dart';
import 'transaction_history.dart';
import 'settings.dart';

enum _View { dashboard, history, settings }

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

  // ── Subscriptions ──────────────────────────────────────────────────────
  // Stored so we can cancel them on dispose.
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
    super.dispose();
  }

  Future<void> _startListening() async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    // Ensure the settings doc exists (creates default if first login)
    await _fb.ensureSettingsDoc(uid, _fb.currentUser?.email);

    // ── Settings stream ──
    _settingsSub = _fb.settingsStream(uid).listen((settings) {
      if (mounted) setState(() => _settings = settings);
    }, onError: (e) {
      debugPrint('Settings stream error: $e');
    });

    // ── Transactions stream ──
    _transactionsSub = _fb.transactionsStream(uid).listen((txs) {
      if (mounted) {
        setState(() {
          _transactions = txs.cast<Transaction>();
          _loading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Transactions stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── Calculations (same math as React Dashboard) ─────────────────────────
  double _calculateBalance() {
    final totalIncome = _transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = _transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    return (_settings?.initialAmount ?? 0) + totalIncome - totalExpense;
  }

  Map<String, double> _calculateBreakdown() {
    final upi = _transactions
        .where((t) => t.paymentMethod == 'UPI')
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    final cash = _transactions
        .where((t) => t.paymentMethod == 'Cash')
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    return {
      'upi': upi + (_settings?.initialUpi ?? 0),
      'cash': cash + (_settings?.initialCash ?? 0),
    };
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingScreen();

    final breakdown = _calculateBreakdown();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _header(breakdown),
          _navBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: TransactionForm(transactions: _transactions, settings: _settings),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: TransactionHistory(transactions: _transactions),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _settings != null ? Settings(settings: _settings!) : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient Header ────────────────────────────────────────────────────
  Widget _header(Map<String, double> breakdown) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row: logo + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KasuBook', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(
                            'Hello, ${_settings?.username ?? 'User'}!',
                            style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Logout
                  GestureDetector(
                    onTap: () => _fb.logout(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Balance card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Balance', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200))),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_calculateBalance().toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.white.withAlpha(60), height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('UPI Amount', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(200))),
                              const SizedBox(height: 2),
                              Text('₹${breakdown['upi']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cash Amount', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(200))),
                              const SizedBox(height: 2),
                              Text('₹${breakdown['cash']!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nav Bar ──────────────────────────────────────────────────────────────
  Widget _navBar() {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Row(
            children: [
              _navButton(0, 'Dashboard', Icons.account_balance_wallet_rounded),
              _navButton(1, 'History', Icons.history_rounded),
              _navButton(2, 'Settings', Icons.settings_rounded),

            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double page = 0;
                if (_pageController.hasClients && _pageController.page != null) {
                  page = _pageController.page!;
                }

                return Align(
                  alignment: Alignment(-1 + (page * 1), 0), // moves from -1 → 1
                  child: FractionallySizedBox(
                    widthFactor: 1 / 3,
                    child: Container(
                      height: 3,
                      color: const Color(0xFF6366F1),
                    ),
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
        onTap: () => _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double page = 0;
            if (_pageController.hasClients && _pageController.page != null) {
              page = _pageController.page!;
            }

            // Distance from this tab
            double diff = (page - index).abs().clamp(0.0, 1.0);

            // 0 = active, 1 = inactive
            Color activeColor = const Color(0xFF4F46E5);
            Color inactiveColor = const Color(0xFF6B7280);

            Color color = Color.lerp(activeColor, inactiveColor, diff)!;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  // ── Loading screen ─────────────────────────────────────────────────────
  Widget _loadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}