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
const _kOrange    = Color(0xFFF97316);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
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

    _initNotifications(uid);

    _fb.ensureSettingsDoc(uid, _fb.currentUser?.email).then((_) {
      _fb.migrateOldUpiRecords(uid).then((count) {
        if (count > 0) debugPrint('[Migration] Updated $count old UPI record(s)');
      }).catchError((e) => debugPrint('[Migration] Error: $e'));
    }).catchError((e) => debugPrint("Ensure settings error: $e"));

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _loading) setState(() => _loading = false);
    });

    _settingsSub = _fb.settingsStream(uid).listen((settings) {
      if (mounted) setState(() => _settings = settings);
    }, onError: (e) => debugPrint('Settings stream error: $e'));

    _transactionsSub = _fb.transactionsStream(uid).listen((txs) {
      if (mounted) {
        setState(() {
          _transactions = txs.cast<Transaction>();
          _loading = false;
        });
        _autoAssignUnassignedUpi(uid, txs.cast<Transaction>());
      }
    }, onError: (e) {
      debugPrint('Transactions stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _initNotifications(String uid) async {
    try {
      await _notificationService.init();
      await _notificationService.initFCM();
      await _notificationService.requestPermissions();
      _notificationService.startAdminNotificationListener(uid);
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  Future<void> _autoAssignUnassignedUpi(String uid, List<Transaction> txs) async {
    final accounts = _settings?.upiAccounts ?? [];
    if (accounts.isEmpty) return;
    final firstBank = accounts.first.bankName;
    final unassigned = txs.where((t) =>
        t.method == 'UPI' && (t.resolvedBank == null || t.resolvedBank!.isEmpty)).toList();
    if (unassigned.isEmpty) return;
    for (final tx in unassigned) {
      await _fb.reassignTransactionBank(
          uid: uid, transactionId: tx.id, bankName: firstBank);
    }
  }

  double _calculateCashBalance() {
    final net = _transactions
        .where((t) => t.method == 'Cash')
        .fold(0.0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
    return (_settings?.initialCash ?? 0) + net;
  }

  Map<String, double> _calculateUpiAccountBalances() {
    final accounts = _settings?.upiAccounts ?? [];
    final result = <String, double>{};
    for (final acc in accounts) {
      final net = _transactions
          .where((t) => t.method == 'UPI' && t.resolvedBank == acc.bankName)
          .fold(0.0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
      result[acc.bankName] = acc.initialBalance + net;
    }
    return result;
  }

  Map<String, double> _calculateMonthStats() {
    final now = DateTime.now();
    double income = 0, expense = 0;
    for (final t in _transactions) {
      try {
        final date = DateTime.tryParse(t.transactionDate);
        if (date != null && date.year == now.year && date.month == now.month) {
          if (t.type == 'income') income += t.amount;
          else if (t.type == 'expense') expense += t.amount;
        }
      } catch (_) {}
    }
    return {'income': income, 'expense': expense};
  }

  void _showTransferDialog() {
    if (_settings == null) return;
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    // Prepare account list
    final accounts = ['Cash'];
    if (_settings!.upiAccounts.isNotEmpty) {
      accounts.addAll(_settings!.upiAccounts.map((e) => e.bankName));
    }

    String from = 'Cash';
    String to = accounts.length > 1 ? accounts[1] : 'Cash';
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24, left: 24, right: 24
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Transfer Amount', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextPrim)),
                  const SizedBox(height: 20),
                  
                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: _kTextPrim),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: const TextStyle(color: _kTextSec),
                      prefixIcon: const Icon(Icons.currency_rupee, color: _kTextSec, size: 18),
                      filled: true,
                      fillColor: _kNavBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // From -> To
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('From', from, accounts, (v) => setModalState(() => from = v!))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        child: Icon(Icons.arrow_forward_rounded, color: _kTextSec),
                      ),
                      Expanded(child: _buildDropdown('To', to, accounts, (v) => setModalState(() => to = v!))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (formKey.currentState!.validate()) {
                          if (from == to) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Source and Destination cannot be same'), backgroundColor: _kRed)
                            );
                            return;
                          }
                          setModalState(() => isLoading = true);
                          try {
                            await _fb.transferFunds(
                              uid: uid,
                              amount: double.parse(amountCtrl.text),
                              fromMethod: from,
                              toMethod: to,
                              date: DateTime.now().toIso8601String(),
                            );
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            setModalState(() => isLoading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Transfer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _kTextSec, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kNavBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: _kNavBg,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: _kTextSec),
              style: const TextStyle(color: _kTextPrim),
              items: items.map((a) => DropdownMenuItem(
                value: a,
                child: Text(a, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _AnimatedLoadingScreen();

    final upiBalances = _calculateUpiAccountBalances();
    final monthStats  = _calculateMonthStats();
    final cashBalance = _calculateCashBalance();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          // 0. Home
          _buildHomeTab(cashBalance, upiBalances, monthStats),

          // 1. Add
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: TransactionForm(transactions: _transactions, settings: _settings),
            ),
          ),

          // 2. History
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: TransactionHistory(transactions: _transactions, settings: _settings),
            ),
          ),

          // 3. Analytics
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: _settings != null
                  ? AnalyticsPage(transactions: _transactions, settings: _settings!)
                  : const SizedBox(),
            ),
          ),

          // 4. Settings
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              child: _settings != null
                  ? Settings(settings: _settings!)
                  : const SizedBox(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _kNavBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: _kNavBg,
          selectedItemColor: _kAccent,
          unselectedItemColor: _kTextSec,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),  label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded),    label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded),  label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded),   label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HOME TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab(
    double cashBalance,
    Map<String, double> upiBalances,
    Map<String, double> monthStats,
  ) {
    final now       = DateTime.now();
    final monthName = _monthName(now.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_kAccent, Color(0xFF5B21B6)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text('KasuBook',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _kTextPrim)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Hello, ${_settings?.username ?? 'User'}! 👋',
                        style: const TextStyle(fontSize: 13, color: _kTextSec)),
                  ],
                ),
                IconButton(
                  onPressed: () => _fb.logout(),
                  icon: const Icon(Icons.logout_rounded,
                      color: _kTextSec, size: 20),
                  tooltip: 'Logout',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Cash Card ────────────────────────────────────────────────────
            _balanceCard(
              icon: Icons.money_rounded,
              iconColor: _kOrange,
              gradientColors: const [Color(0xFF2A1A0A), Color(0xFF1A1410), Color(0xFF16172A)],
              borderColor: _kOrange.withAlpha(60),
              glowColor: _kOrange.withAlpha(30),
              label: 'Cash',
              sublabel: 'Physical money',
              amount: cashBalance,
            ),
            const SizedBox(height: 12),

            // ── UPI / Bank Cards ─────────────────────────────────────────────
            if (upiBalances.isEmpty)
              _emptyAccountHint()
            else
              ...upiBalances.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _balanceCard(
                      icon: Icons.account_balance_rounded,
                      iconColor: _kAccent2,
                      gradientColors: const [
                        Color(0xFF1E1040),
                        Color(0xFF16172A),
                        Color(0xFF1A1B2E),
                      ],
                      borderColor: _kAccent.withAlpha(60),
                      glowColor: _kAccent.withAlpha(25),
                      label: e.key,
                      sublabel: 'UPI Account',
                      amount: e.value,
                    ),
                  )),

            const SizedBox(height: 16),

            // ── Transfer Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _showTransferDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  foregroundColor: _kAccent,
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transfer Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 24),

            // ── This Month ───────────────────────────────────────────────────
            _sectionLabel('📅 $monthName — This Month'),
            const SizedBox(height: 12),

            _monthStatsRow(monthStats['income']!, monthStats['expense']!),
            const SizedBox(height: 12),

            _netThisMonthCard(monthStats['income']!, monthStats['expense']!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Big Balance Card (Cash / Bank) ────────────────────────────────────────
  Widget _balanceCard({
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color glowColor,
    required String label,
    required String sublabel,
    required double amount,
  }) {
    final isNegative = amount < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withAlpha(60)),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),

          // Label + sublabel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _kTextPrim,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sublabel,
                    style: const TextStyle(color: _kTextSec, fontSize: 12)),
              ],
            ),
          ),

          // Amount + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isNegative ? '-' : ''}₹${_formatAmount(amount.abs())}',
                style: TextStyle(
                    color: isNegative ? _kRed : _kTextPrim,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isNegative ? _kRed : _kGreen).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: (isNegative ? _kRed : _kGreen).withAlpha(80)),
                ),
                child: Text(
                  isNegative ? 'Overdrawn' : 'Available',
                  style: TextStyle(
                      color: isNegative ? _kRed : _kGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: _kTextPrim));

  // ── Month Stats Row ───────────────────────────────────────────────────────
  Widget _monthStatsRow(double income, double expense) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.arrow_downward_rounded,
            iconColor: _kGreen,
            label: 'Income',
            amount: income,
            color: _kGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            icon: Icons.arrow_upward_rounded,
            iconColor: _kRed,
            label: 'Expense',
            amount: expense,
            color: _kRed,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: _kTextSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Net This Month ────────────────────────────────────────────────────────
  Widget _netThisMonthCard(double income, double expense) {
    final net      = income - expense;
    final isProfit = net >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: (isProfit ? _kGreen : _kRed).withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: (isProfit ? _kGreen : _kRed).withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isProfit
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: isProfit ? _kGreen : _kRed,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                isProfit ? 'Net Savings this month' : 'Net Loss this month',
                style: const TextStyle(
                    color: _kTextSec,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            '${isProfit ? '+' : '-'}₹${_formatAmount(net.abs())}',
            style: TextStyle(
                color: isProfit ? _kGreen : _kRed,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Empty UPI hint ────────────────────────────────────────────────────────
  Widget _emptyAccountHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: _kTextSec.withAlpha(120), size: 18),
          const SizedBox(width: 10),
          const Text(
            'No UPI accounts added yet.\nGo to Settings to add one.',
            style: TextStyle(color: _kTextSec, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _monthName(int month) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return names[month - 1];
  }
}

// ─── Animated Loading Screen ────────────────────────────────────────────────
class _AnimatedLoadingScreen extends StatefulWidget {
  const _AnimatedLoadingScreen();
  @override
  State<_AnimatedLoadingScreen> createState() => _AnimatedLoadingScreenState();
}

class _AnimatedLoadingScreenState extends State<_AnimatedLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _dotsCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _rotate;
  late final Animation<double> _fade;
  late final Animation<double> _dots;

  @override
  void initState() {
    super.initState();
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulse      = Tween(begin: 0.85, end: 1.08).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _rotate     = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));
    _fadeCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade       = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _dotsCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _dots       = Tween(begin: 0.0, end: 3.0).animate(_dotsCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose(); _rotateCtrl.dispose();
    _fadeCtrl.dispose();  _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            Positioned(top: -80, left: -60,
                child: _blob(180, const Color(0xFF7C3AED).withAlpha(40))),
            Positioned(bottom: -60, right: -40,
                child: _blob(200, const Color(0xFF8B5CF6).withAlpha(30))),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120, height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _rotate,
                          builder: (_, __) => Transform.rotate(
                            angle: _rotate.value * 2 * 3.14159,
                            child: Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(colors: [
                                  const Color(0xFF7C3AED).withAlpha(0),
                                  const Color(0xFF7C3AED),
                                  const Color(0xFFA78BFA),
                                  const Color(0xFF7C3AED).withAlpha(0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 90, height: 90,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _kBg),
                        ),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) => Transform.scale(
                            scale: _pulse.value,
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF7C3AED).withAlpha(120),
                                      blurRadius: 24, spreadRadius: 4)
                                ],
                              ),
                              child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white, size: 34),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text('KasuBook',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _kTextPrim,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (_, __) {
                      final dots = '.' * (_dots.value.floor() + 1);
                      return Text('Loading$dots',
                          style: const TextStyle(
                              fontSize: 15, color: _kTextSec));
                    },
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 160,
                    child: AnimatedBuilder(
                      animation: _rotateCtrl,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: _kCard,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(const Color(0xFF7C3AED),
                                const Color(0xFFA78BFA), _pulseCtrl.value)!,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 60, spreadRadius: 20)
          ],
        ),
      );
}