// ─── settings.dart ──────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'models.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

// ── Dark Theme Color Palette ──────────────────────────────────────────────────
const _kBg         = Color(0xFF1A1B2E);
const _kCard       = Color(0xFF242535);
const _kCardBorder = Color(0xFF2E2F45);
const _kAccent     = Color(0xFF7C3AED);
const _kAccent2    = Color(0xFF8B5CF6);
const _kTextPrim   = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFFA0A3BD);
const _kInputBg    = Color(0xFF1E1F32);
const _kInputBorder= Color(0xFF3A3B52);
const _kGreen      = Color(0xFF22C55E);
const _kRed        = Color(0xFFEF4444);

class Settings extends StatefulWidget {
  final UserSettings settings;
  const Settings({super.key, required this.settings});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late final _usernameController = TextEditingController(text: widget.settings.username);
  late final _cashController = TextEditingController(text: widget.settings.initialCash.toStringAsFixed(2));
  late List<_UpiEntry> _upiEntries;

  bool _loading = false;
  String? _error;
  bool _success = false;
  bool _notificationsEnabled = false;

  final _notificationService = NotificationService();
  final _fb = FirebaseService();

  @override
  void initState() {
    super.initState();
    _upiEntries = widget.settings.upiAccounts.map((a) => _UpiEntry(
      bankNameController: TextEditingController(text: a.bankName),
      balanceController: TextEditingController(text: a.initialBalance.toStringAsFixed(2)),
      id: a.id,
    )).toList();
    _notificationService.init();
    _checkNotificationPermissions();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _cashController.dispose();
    for (final e in _upiEntries) {
      e.bankNameController.dispose();
      e.balanceController.dispose();
    }
    super.dispose();
  }

  Future<void> _checkNotificationPermissions() async {
    final granted = await _notificationService.requestPermissions();
    if (mounted) setState(() => _notificationsEnabled = granted);
  }

  void _addUpiAccount() {
    setState(() {
      _upiEntries.add(_UpiEntry(
        bankNameController: TextEditingController(),
        balanceController: TextEditingController(text: '0.00'),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        isNew: true, // newly added this session — editable even when locked
      ));
    });
  }

  void _removeUpiAccount(int index) {
    setState(() {
      _upiEntries[index].bankNameController.dispose();
      _upiEntries[index].balanceController.dispose();
      _upiEntries.removeAt(index);
    });
  }

  double get _totalUpi => _upiEntries.fold(0, (s, e) => s + (double.tryParse(e.balanceController.text) ?? 0));
  double get _cash => double.tryParse(_cashController.text) ?? 0;

  Future<void> _handleSave() async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;
    final username = _usernameController.text.trim();
    if (username.isEmpty) { setState(() => _error = 'Username cannot be empty'); return; }
    for (int i = 0; i < _upiEntries.length; i++) {
      if (_upiEntries[i].bankNameController.text.trim().isEmpty) {
        setState(() => _error = 'Bank name for UPI account ${i + 1} cannot be empty');
        return;
      }
    }
    setState(() { _error = null; _success = false; _loading = true; });
    final shouldLock = !widget.settings.initialAmountLocked;
    try {
      final upiAccounts = _upiEntries.map((e) => UpiAccount(
        id: e.id,
        bankName: e.bankNameController.text.trim(),
        initialBalance: double.tryParse(e.balanceController.text) ?? 0,
      )).toList();
      await _fb.updateSettings(
        uid: uid, username: username, initialCash: _cash,
        upiAccounts: upiAccounts, lockInitialAmount: shouldLock,
      );
      setState(() => _success = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _success = false);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.settings.initialAmountLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main settings card
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextPrim)),
              const SizedBox(height: 24),

              // Username
              _labelWithIcon('Username', Icons.person_outline),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: _kTextPrim),
                decoration: _inputDeco('Enter your name'),
              ),
              const SizedBox(height: 4),
              const Text('This name will be displayed on your dashboard', style: TextStyle(fontSize: 12, color: _kTextSec)),
              const SizedBox(height: 24),

              // Initial Balance header
              Row(children: [
                _labelWithIcon('Initial Balance Breakdown', Icons.currency_rupee),
                if (isLocked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B2A0E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24).withAlpha(60)),
                    ),
                    child: const Text('Locked', style: TextStyle(fontSize: 12, color: Color(0xFFFBBF24), fontWeight: FontWeight.w500)),
                  ),
                ],
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAccent.withAlpha(50)),
                ),
                child: const Text(
                  "Enter the amount you currently have at the start. Once saved, this will be fixed.",
                  style: TextStyle(fontSize: 13, color: Color(0xFFC4B5FD), height: 1.4),
                ),
              ),
              const SizedBox(height: 16),

              // Cash row
              _labelSmall('Cash'),
              TextFormField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _kTextPrim),
                decoration: _inputDeco('0.00'),
                enabled: !isLocked,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // UPI Accounts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _labelWithIcon('UPI Accounts', Icons.account_balance_wallet_outlined),
                  // Always show Add UPI — even when locked, new accounts can be added
                  TextButton.icon(
                    onPressed: _addUpiAccount,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add UPI'),
                    style: TextButton.styleFrom(foregroundColor: _kAccent2),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_upiEntries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kInputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kInputBorder),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF5C5E7A)),
                    SizedBox(width: 8),
                    Text('No UPI accounts added yet', style: TextStyle(fontSize: 13, color: _kTextSec)),
                  ]),
                ),

              ..._upiEntries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kAccent.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kAccent.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Text('UPI Account ${i + 1}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kAccent2)),
                            if (isLocked && !e.isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B2A0E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Locked', style: TextStyle(fontSize: 10, color: Color(0xFFFBBF24))),
                              ),
                            ],
                          ]),
                          // Show delete only for new accounts (isNew) or when unlocked
                          if (!isLocked || e.isNew)
                            GestureDetector(
                              onTap: () => _removeUpiAccount(i),
                              child: const Icon(Icons.delete_outline, size: 18, color: _kRed),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(flex: 3, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelSmall('Bank Name'),
                            TextFormField(
                              controller: e.bankNameController,
                              style: TextStyle(color: (isLocked && !e.isNew) ? _kTextSec : _kTextPrim),
                              decoration: _inputDeco('e.g. HDFC, SBI'),
                              // Existing entries blocked when locked; new entries always editable
                              enabled: !isLocked || e.isNew,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelSmall('Balance'),
                            TextFormField(
                              controller: e.balanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: _kTextPrim),
                              decoration: _inputDeco('0.00'),
                              enabled: !isLocked || e.isNew,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        )),
                      ]),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
              // Total summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _kGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGreen.withAlpha(60)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total Initial Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGreen)),
                  Text('₹${(_cash + _totalUpi).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGreen)),
                ]),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Cash: ₹${_cash.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: _kTextSec)),
                Text('UPI: ₹${_totalUpi.toStringAsFixed(2)} (${_upiEntries.length} accounts)',
                    style: const TextStyle(fontSize: 12, color: _kTextSec)),
              ]),
              const SizedBox(height: 24),

              // Notifications
              _labelWithIcon('Notifications', Icons.notifications_outlined),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kInputBorder),
                ),
                child: Row(children: [
                  Icon(
                    _notificationsEnabled ? Icons.check_circle : Icons.info_outline,
                    color: _notificationsEnabled ? _kGreen : _kTextSec, size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _notificationsEnabled ? 'Notifications Enabled ✓' : 'Enable Notifications',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextPrim),
                      ),
                      const SizedBox(height: 2),
                      const Text('You will receive admin notifications automatically',
                          style: TextStyle(fontSize: 12, color: _kTextSec)),
                    ],
                  )),
                  if (!_notificationsEnabled)
                    TextButton(
                      onPressed: () async {
                        final granted = await _notificationService.requestPermissions();
                        if (mounted) {
                          setState(() => _notificationsEnabled = granted);
                          if (granted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✓ Notifications enabled!'),
                                backgroundColor: _kGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Enable', style: TextStyle(color: _kAccent2)),
                    ),
                ]),
              ),
              const SizedBox(height: 24),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1919),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7F1D1D).withAlpha(100)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              if (_success) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGreen.withAlpha(60)),
                  ),
                  child: const Text('Settings updated successfully!', style: TextStyle(color: _kGreen, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleSave,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: Text(_loading ? 'Saving...' : 'Save Settings',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // About card
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
          ),
          padding: const EdgeInsets.all(18),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About KasuBook', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kTextPrim)),
            SizedBox(height: 8),
            Text(
              'KasuBook is your personal money management companion. '
              'Track your income and expenses, categorize transactions, '
              'and stay on top of your finances with ease.',
              style: TextStyle(fontSize: 13, color: _kTextSec, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Terms card
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder),
          ),
          padding: const EdgeInsets.all(18),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Terms and Conditions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kTextPrim)),
            SizedBox(height: 8),
            Text(
              'By using KasuBook, you agree to track your expenses responsibly. '
              'Data is stored securely on Firebase. We are not responsible for any financial discrepancies or data loss.',
              style: TextStyle(fontSize: 13, color: _kTextSec, height: 1.5),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _labelWithIcon(String text, IconData icon) => Row(children: [
    Icon(icon, size: 16, color: _kTextSec),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
  ]);

  Widget _labelSmall(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextSec)),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF5C5E7A)),
    filled: true,
    fillColor: _kInputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent, width: 2)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kInputBorder.withAlpha(100))),
  );
}

class _UpiEntry {
  final String id;
  final TextEditingController bankNameController;
  final TextEditingController balanceController;
  /// true = added this session (not yet saved), always editable even when locked
  final bool isNew;
  _UpiEntry({required this.id, required this.bankNameController, required this.balanceController, this.isNew = false});
}