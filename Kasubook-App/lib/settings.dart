// ─── settings.dart ──────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'models.dart';
import 'firebase_service.dart';

class Settings extends StatefulWidget {
  final UserSettings settings;

  const Settings({super.key, required this.settings});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late final _usernameController = TextEditingController(text: widget.settings.username);
  late final _cashController = TextEditingController(text: widget.settings.initialCash.toStringAsFixed(2));
  late final _upiController = TextEditingController(text: widget.settings.initialUpi.toStringAsFixed(2));

  bool _loading = false;
  String? _error;
  bool _success = false;

  final _fb = FirebaseService();

  @override
  void dispose() {
    _usernameController.dispose();
    _cashController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  // ── Derived ──────────────────────────────────────────────────────────────
  double get _cash => double.tryParse(_cashController.text) ?? 0;
  double get _upi => double.tryParse(_upiController.text) ?? 0;
  double get _totalInitial => _cash + _upi;

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Username cannot be empty');
      return;
    }

    setState(() {
      _error = null;
      _success = false;
      _loading = true;
    });

    try {
      await _fb.updateSettings(
        uid: uid,
        username: username,
        initialCash: _cash,
        initialUpi: _upi,
      );

      setState(() => _success = true);

      // Auto-dismiss success banner after 3 seconds (mirrors React setTimeout)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _success = false);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main settings card ─────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 24),

              // ── Username ─────────────────────────────────────────────────
              _labelWithIcon('Username', Icons.person_outline),
              TextFormField(
                controller: _usernameController,
                decoration: _inputDeco('Enter your name'),
              ),
              const SizedBox(height: 4),
              const Text(
                'This name will be displayed on your dashboard',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),

              // ── Initial Balance Breakdown ────────────────────────────────
              _labelWithIcon('Initial Balance Breakdown', Icons.currency_rupee),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Cash
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            const Text('Cash', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _cashController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDeco('0.00'),
                          onChanged: (_) => setState(() {}), // rebuild to update total
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // UPI
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.smartphone, size: 14, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            const Text('UPI', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _upiController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDeco('0.00'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total preview bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Initial Amount:', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                    Text(
                      '₹${_totalInitial.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set your starting Cash and UPI balance separately.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),

              // ── Error banner ────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14)),
                ),
                const SizedBox(height: 12),
              ],

              // ── Success banner ──────────────────────────────────────────
              if (_success) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Settings updated successfully!', style: TextStyle(color: Color(0xFF16A34A), fontSize: 14)),
                ),
                const SizedBox(height: 12),
              ],

              // ── Save button ──────────────────────────────────────────────
              SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF9333EA)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleSave,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: Text(
                      _loading ? 'Saving...' : 'Save Settings',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── About KasuBook ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About KasuBook', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 8),
              const Text(
                'KasuBook is your personal money management companion. '
                'Track your income and expenses, categorize transactions, '
                'and stay on top of your finances with ease.',
                style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _labelWithIcon(String text, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF374151)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
    ],
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
  );
}