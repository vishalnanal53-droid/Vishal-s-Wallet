// ─── transaction_form.dart ──────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'models.dart';
import 'firebase_service.dart';

/// Default tags that ship with every account and cannot be deleted.
const List<String> _DEFAULT_TAGS = [
  'Food', 'Snacks', 'Travel', 'Friends', 'Shopping',
  'Bills', 'Entertainment', 'Health', 'Others',
];

/// Colour palette for tag chips (mirrors TAG_COLORS in the React types).
const Map<String, _TagStyle> _TAG_STYLES = {
  'Food':          _TagStyle(bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E)),
  'Snacks':        _TagStyle(bg: Color(0xFFFDE68A), fg: Color(0xFF92400E)),
  'Travel':        _TagStyle(bg: Color(0xFFDDD6FE), fg: Color(0xFF5B21B6)),
  'Friends':       _TagStyle(bg: Color(0xFFFCE7F3), fg: Color(0xFF9D174D)),
  'Shopping':      _TagStyle(bg: Color(0xFFE0E7FF), fg: Color(0xFF3730A3)),
  'Bills':         _TagStyle(bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B)),
  'Entertainment': _TagStyle(bg: Color(0xFFECFDF5), fg: Color(0xFF065F46)),
  'Health':        _TagStyle(bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
  'Others':        _TagStyle(bg: Color(0xFFF3F4F6), fg: Color(0xFF374151)),
};

class _TagStyle {
  final Color bg;
  final Color fg;
  const _TagStyle({required this.bg, required this.fg});
}

class TransactionForm extends StatefulWidget {
  final List<Transaction> transactions;
  final UserSettings? settings;

  const TransactionForm({
    super.key,
    required this.transactions,
    this.settings,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newTagController = TextEditingController();

  String _type = 'expense';
  String _paymentMethod = 'UPI';
  String _selectedTag = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isAddingTag = false;
  bool _loading = false;
  String? _error;

  final _fb = FirebaseService();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  // ── Derived ──────────────────────────────────────────────────────────────
  List<String> get _allTags => [..._DEFAULT_TAGS, ...(widget.settings?.customTags ?? [])];

  Map<String, double> _calculateStats() {
    final totalIncome = widget.transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = widget.transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    final balance = (widget.settings?.initialAmount ?? 0) + totalIncome - totalExpense;

    final upi = widget.transactions
        .where((t) => t.paymentMethod == 'UPI')
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    final cash = widget.transactions
        .where((t) => t.paymentMethod == 'Cash')
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));

    return {
      'balance': balance,
      'upi': upi + (widget.settings?.initialUpi ?? 0),
      'cash': cash + (widget.settings?.initialCash ?? 0),
    };
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await _fb.addTransaction(
        uid: uid,
        type: _type,
        amount: double.parse(_amountController.text.trim()),
        paymentMethod: _paymentMethod,
        tag: _selectedTag,
        transactionDate: _selectedDate.toIso8601String(),
        description: _descriptionController.text.trim(),
      );

      _formKey.currentState!.reset();
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedTag = 'Food';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added'), backgroundColor: Color(0xFF10B981)),
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
      setState(() {
        _selectedTag = formatted;
        _newTagController.clear();
        _isAddingTag = false;
      });
      return;
    }

    try {
      await _fb.addCustomTag(uid, formatted);
      setState(() {
        _selectedTag = formatted;
        _newTagController.clear();
        _isAddingTag = false;
      });
    } catch (e) {
      setState(() => _error = 'Failed to add tag');
    }
  }

  Future<void> _handleDeleteTag(String tagToDelete) async {
    final uid = _fb.currentUser?.uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Are you sure you want to delete "$tagToDelete"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _fb.removeCustomTag(uid, tagToDelete);
      if (_selectedTag == tagToDelete) setState(() => _selectedTag = _DEFAULT_TAGS[0]);
    } catch (e) {
      setState(() => _error = 'Failed to delete tag');
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      // After picking date, pick time
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
          ),
          child: child!,
        ),
      );

      setState(() {
        final time = pickedTime ?? TimeOfDay.fromDateTime(_selectedDate);
        _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, time.hour, time.minute);
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Add Transaction Card ─────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Transaction', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 20),

                // Income / Expense
                Row(
                  children: [
                    Expanded(child: _typeButton('income', 'Income', const Color(0xFF22C55E))),
                    const SizedBox(width: 10),
                    Expanded(child: _typeButton('expense', 'Expense', const Color(0xFFEF4444))),
                  ],
                ),
                const SizedBox(height: 18),

                // Amount
                _label('Amount'),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                Row(
                  children: [
                    Expanded(child: _paymentButton('UPI')),
                    const SizedBox(width: 10),
                    Expanded(child: _paymentButton('Cash')),
                  ],
                ),
                const SizedBox(height: 18),

                // Tag Chips
                _label('Tag'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._allTags.map((t) => _tagChip(t)),
                    if (_isAddingTag) _addTagInput() else _addTagButton(),
                  ],
                ),
                const SizedBox(height: 18),

                // Date
                _label('Date'),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDateDisplay(_selectedDate),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                        ),
                        const Icon(Icons.calendar_today, color: Color(0xFF6B7280), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Description
                _label('Description'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDeco('Add a note...'),
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Description is required';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Submit
                SizedBox(
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF9333EA)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _handleSubmit,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      label: Text(
                        _loading ? 'Adding...' : 'Add Transaction',
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
        ),
      ],
    );
  }

  // ── Small builders ───────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2)),
  );

  Widget _typeButton(String value, String label, Color activeColor) {
    final isActive = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF6B7280), fontSize: 15),
        ),
      ),
    );
  }

  Widget _paymentButton(String value) {
    final isActive = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    final isSelected = _selectedTag == tag;
    final style = _TAG_STYLES[tag] ?? const _TagStyle(bg: Color(0xFFF3F4F6), fg: Color(0xFF374151));
    final isCustom = !_DEFAULT_TAGS.contains(tag);

    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: style.fg)),
            if (isCustom) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _handleDeleteTag(tag),
                child: Icon(Icons.close, size: 15, color: style.fg.withAlpha(140)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _addTagButton() {
    return GestureDetector(
      onTap: () => setState(() => _isAddingTag = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF9CA3AF), width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: Color(0xFF6B7280)),
            SizedBox(width: 4),
            Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _addTagInput() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _newTagController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'New tag...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF6366F1))),
            ),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (_) => _handleAddTag(),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _handleAddTag,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 16, color: Color(0xFF16A34A)),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() => _isAddingTag = false),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, double value, List<Color> gradient, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200))),
              const SizedBox(height: 4),
              Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          Icon(icon, size: 36, color: Colors.white.withAlpha(180)),
        ],
      ),
    );
  }

  String _formatDateDisplay(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  $hour:$min $ampm';
  }
}