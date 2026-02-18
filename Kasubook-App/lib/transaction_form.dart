// ─── transaction_form.dart ──────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'dart:async';
import 'models.dart';
import 'firebase_service.dart';

// ── Dark Theme Color Palette ──────────────────────────────────────────────────
const _kBg        = Color(0xFF1A1B2E);
const _kCard      = Color(0xFF242535);
const _kCardBorder= Color(0xFF2E2F45);
const _kAccent    = Color(0xFF7C3AED);
const _kAccent2   = Color(0xFF8B5CF6);
const _kTextPrim  = Color(0xFFFFFFFF);
const _kTextSec   = Color(0xFFA0A3BD);
const _kInputBg   = Color(0xFF1E1F32);
const _kInputBorder= Color(0xFF3A3B52);
const _kGreen     = Color(0xFF22C55E);
const _kRed       = Color(0xFFEF4444);

const List<String> _DEFAULT_TAGS = [
  'Food', 'Snacks', 'Travel', 'Friends', 'Shopping',
  'Bills', 'Entertainment', 'Health', 'Others',
];

// Dark-adapted tag styles for dark background
const Map<String, _TagStyle> _TAG_STYLES = {
  'Food':          _TagStyle(bg: Color(0xFF3B2A0E), fg: Color(0xFFFBBF24)),
  'Snacks':        _TagStyle(bg: Color(0xFF332808), fg: Color(0xFFFCD34D)),
  'Travel':        _TagStyle(bg: Color(0xFF2D1B69), fg: Color(0xFFC4B5FD)),
  'Friends':       _TagStyle(bg: Color(0xFF3B0F24), fg: Color(0xFFF9A8D4)),
  'Shopping':      _TagStyle(bg: Color(0xFF1E2060), fg: Color(0xFFA5B4FC)),
  'Bills':         _TagStyle(bg: Color(0xFF3B0F0F), fg: Color(0xFFFCA5A5)),
  'Entertainment': _TagStyle(bg: Color(0xFF0F3B2E), fg: Color(0xFF6EE7B7)),
  'Health':        _TagStyle(bg: Color(0xFF0F2E1B), fg: Color(0xFF86EFAC)),
  'Others':        _TagStyle(bg: Color(0xFF252636), fg: Color(0xFF9CA3AF)),
};

class _TagStyle {
  final Color bg;
  final Color fg;
  const _TagStyle({required this.bg, required this.fg});
}

class TransactionForm extends StatefulWidget {
  final List<Transaction> transactions;
  final UserSettings? settings;

  const TransactionForm({super.key, required this.transactions, this.settings});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newTagController = TextEditingController();

  String _type = 'expense';
  String _selectedPayment = 'Cash';
  String _selectedTag = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isAddingTag = false;
  bool _loading = false;
  String? _error;
  Timer? _timer;

  final _fb = FirebaseService();

  @override
  void initState() {
    super.initState();
    _initSelectedPayment();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
              now.hour, now.minute, now.second);
        });
      }
    });
  }

  void _initSelectedPayment() {
    final accounts = widget.settings?.upiAccounts ?? [];
    if (accounts.isNotEmpty) {
      _selectedPayment = accounts.first.bankName;
    } else {
      _selectedPayment = 'Cash';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  List<String> get _allTags => [..._DEFAULT_TAGS, ...(widget.settings?.customTags ?? [])];

  List<_PaymentOption> get _paymentOptions {
    final options = <_PaymentOption>[const _PaymentOption(label: 'Cash', isUpi: false)];
    for (final acc in widget.settings?.upiAccounts ?? []) {
      options.add(_PaymentOption(label: acc.bankName, isUpi: true));
    }
    return options;
  }

  Map<String, double> _calculateStats() {
    final totalIncome = widget.transactions.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final totalExpense = widget.transactions.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
    final balance = (widget.settings?.initialAmount ?? 0) + totalIncome - totalExpense;
    final cashTx = widget.transactions.where((t) => t.method == 'Cash').fold(0.0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
    final cash = cashTx + (widget.settings?.initialCash ?? 0);
    final upiTx = widget.transactions.where((t) => t.method == 'UPI').fold(0.0, (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
    final upi = upiTx + (widget.settings?.totalUpi ?? 0);
    return {'balance': balance, 'upi': upi, 'cash': cash};
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;
    setState(() { _error = null; _loading = true; });
    try {
      // Pass _selectedPayment directly: 'Cash' or bank name (e.g. 'HDFC').
      // FirebaseService.addTransaction stores it as 'Cash' or 'UPI.HDFC'.
      await _fb.addTransaction(
        uid: uid, type: _type, amount: double.parse(_amountController.text.trim()),
        paymentMethod: _selectedPayment, tag: _selectedTag,
        transactionDate: _selectedDate.toIso8601String(), description: _descriptionController.text.trim(),
      );
      _formKey.currentState!.reset();
      _amountController.clear();
      _descriptionController.clear();
      setState(() { _selectedDate = DateTime.now(); _selectedTag = 'Food'; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction added'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddTag() async {
    final tag = _newTagController.text.trim();
    if (tag.isEmpty) return;
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;
    final formatted = tag[0].toUpperCase() + tag.substring(1);
    if (_allTags.contains(formatted)) {
      setState(() { _selectedTag = formatted; _newTagController.clear(); _isAddingTag = false; });
      return;
    }
    try {
      await _fb.addCustomTag(uid, formatted);
      setState(() { _selectedTag = formatted; _newTagController.clear(); _isAddingTag = false; });
    } catch (_) {
      setState(() => _error = 'Failed to add tag');
    }
  }

  Future<void> _handleDeleteTag(String tagToDelete) async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _kCardBorder)),
        title: const Text('Delete Tag', style: TextStyle(color: _kTextPrim)),
        content: Text('Delete "$tagToDelete"?', style: const TextStyle(color: _kTextSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _kTextSec))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _fb.removeCustomTag(uid, tagToDelete);
      if (_selectedTag == tagToDelete) setState(() => _selectedTag = _DEFAULT_TAGS[0]);
    } catch (_) {
      setState(() => _error = 'Failed to delete tag');
    }
  }

  Future<void> _pickDateOnly() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF7C3AED), surface: Color(0xFF242535)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day, _selectedDate.hour, _selectedDate.minute, _selectedDate.second);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextPrim)),
                const SizedBox(height: 20),

                // Income / Expense
                Row(children: [
                  Expanded(child: _typeButton('income', 'Income', _kGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _typeButton('expense', 'Expense', _kRed)),
                ]),
                const SizedBox(height: 18),

                // Amount
                _label('Amount'),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: _kTextPrim),
                  decoration: _inputDeco('0.00'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Amount is required';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Payment Method
                _label('Payment Method'),
                _buildPaymentMethodSelector(),
                const SizedBox(height: 18),

                // Tags
                _label('Tag'),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    ..._allTags.map((t) => _tagChip(t)),
                    if (_isAddingTag) _addTagInput() else _addTagButton(),
                  ],
                ),
                const SizedBox(height: 18),

                // Date & Time
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Date'),
                        GestureDetector(
                          onTap: _pickDateOnly,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _kInputBg,
                              border: Border.all(color: _kInputBorder),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(_formatDateOnly(_selectedDate), style: const TextStyle(fontSize: 14, color: _kTextPrim)),
                              const Icon(Icons.calendar_today, color: _kTextSec, size: 16),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Time'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _kInputBg,
                            border: Border.all(color: _kInputBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(_formatTimeOnly(_selectedDate), style: const TextStyle(fontSize: 14, color: _kTextSec)),
                            const Icon(Icons.access_time, color: _kTextSec, size: 16),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 18),

                // Description
                _label('Description'),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: _kTextPrim),
                  decoration: _inputDeco('Add a note...'),
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Description is required';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

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

                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _handleSubmit,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      label: Text(_loading ? 'Adding...' : 'Add Transaction',
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
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _paymentOptions.map((opt) {
        final isActive = _selectedPayment == opt.label;
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = opt.label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? (opt.isUpi ? _kAccent : const Color(0xFF166534))
                  : _kInputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? Colors.transparent : _kInputBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt.isUpi ? Icons.account_balance_outlined : Icons.currency_rupee,
                  size: 14, color: isActive ? Colors.white : _kTextSec,
                ),
                const SizedBox(width: 4),
                Text(
                  opt.isUpi ? 'UPI · ${opt.label}' : 'Cash',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : _kTextSec),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
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
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kRed)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kRed, width: 2)),
    errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
  );

  Widget _typeButton(String value, String label, Color activeColor) {
    final isActive = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(30) : _kInputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? activeColor : _kInputBorder, width: isActive ? 1.5 : 1),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: isActive ? activeColor : _kTextSec, fontSize: 15)),
      ),
    );
  }

  Widget _tagChip(String tag) {
    final isSelected = _selectedTag == tag;
    final style = _TAG_STYLES[tag] ?? const _TagStyle(bg: Color(0xFF252636), fg: Color(0xFF9CA3AF));
    final isCustom = !_DEFAULT_TAGS.contains(tag);

    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _kAccent2 : Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.fg)),
            if (isCustom) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _handleDeleteTag(tag),
                child: Icon(Icons.close, size: 14, color: style.fg.withAlpha(160)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _addTagButton() => GestureDetector(
    onTap: () => setState(() => _isAddingTag = true),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kInputBorder, width: 1.5),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add, size: 14, color: _kTextSec),
        SizedBox(width: 4),
        Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
      ]),
    ),
  );

  Widget _addTagInput() => Row(mainAxisSize: MainAxisSize.min, children: [
    SizedBox(
      width: 120,
      child: TextField(
        controller: _newTagController,
        autofocus: true,
        style: const TextStyle(color: _kTextPrim, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'New tag...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF5C5E7A)),
          filled: true,
          fillColor: _kInputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _kInputBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _kInputBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: _kAccent)),
        ),
        onSubmitted: (_) => _handleAddTag(),
      ),
    ),
    const SizedBox(width: 6),
    GestureDetector(
      onTap: _handleAddTag,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF14532D).withAlpha(180), shape: BoxShape.circle),
        child: const Icon(Icons.add, size: 16, color: _kGreen),
      ),
    ),
    const SizedBox(width: 4),
    GestureDetector(
      onTap: () => setState(() => _isAddingTag = false),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: Color(0xFF3B1919), shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 16, color: _kRed),
      ),
    ),
  ]);

  String _formatDateOnly(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _formatTimeOnly(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    final sec = d.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec $ampm';
  }
}

class _PaymentOption {
  final String label;
  final bool isUpi;
  const _PaymentOption({required this.label, required this.isUpi});
}