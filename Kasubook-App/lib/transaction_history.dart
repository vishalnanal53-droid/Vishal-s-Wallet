// ─── transaction_history.dart ───────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'models.dart'; // re-exports _TAG_STYLES via the const map
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Pull the same tag-style map used by TransactionForm so chips are consistent.
// (If you move TAG_STYLES to its own file later, import from there instead.)
const Map<String, _HistTagStyle> _TAG_STYLES_HIST = {
  'Food':          _HistTagStyle(bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E)),
  'Snacks':        _HistTagStyle(bg: Color(0xFFFDE68A), fg: Color(0xFF92400E)),
  'Travel':        _HistTagStyle(bg: Color(0xFFDDD6FE), fg: Color(0xFF5B21B6)),
  'Friends':       _HistTagStyle(bg: Color(0xFFFCE7F3), fg: Color(0xFF9D174D)),
  'Shopping':      _HistTagStyle(bg: Color(0xFFE0E7FF), fg: Color(0xFF3730A3)),
  'Bills':         _HistTagStyle(bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B)),
  'Entertainment': _HistTagStyle(bg: Color(0xFFECFDF5), fg: Color(0xFF065F46)),
  'Health':        _HistTagStyle(bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
  'Others':        _HistTagStyle(bg: Color(0xFFF3F4F6), fg: Color(0xFF374151)),
};

class _HistTagStyle {
  final Color bg;
  final Color fg;
  const _HistTagStyle({required this.bg, required this.fg});
}

enum _TimeFilter { all, today, week, month, year, custom }

class TransactionHistory extends StatefulWidget {
  final List<Transaction> transactions;
  final UserSettings? settings;

  const TransactionHistory({super.key, required this.transactions, this.settings});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  String _searchQuery = '';
  _TimeFilter _timeFilter = _TimeFilter.all;
  String _tagFilter = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;

  // ── Filtering logic (mirrors the React filterTransactions) ──────────────
  List<Transaction> get _filtered {
    var list = widget.transactions.toList();

    // search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
        t.description.toLowerCase().contains(q) ||
        t.tag.toLowerCase().contains(q),
      ).toList();
    }

    // tag
    if (_tagFilter != 'all') {
      list = list.where((t) => t.tag == _tagFilter).toList();
    }

    // time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_timeFilter) {
      case _TimeFilter.today:
        list = list.where((t) {
          final d = _txDate(t);
          return d.isAfter(today) || d.isAtSameMomentAs(today);
        }).toList();
        break;

      case _TimeFilter.week:
        final weekStart = today.subtract(const Duration(days: 7));
        list = list.where((t) {
          final d = _txDate(t);
          return d.isAfter(weekStart) || d.isAtSameMomentAs(weekStart);
        }).toList();
        break;

      case _TimeFilter.month:
        final monthStart = DateTime(now.year, now.month - 1, now.day);
        list = list.where((t) {
          final d = _txDate(t);
          return d.isAfter(monthStart) || d.isAtSameMomentAs(monthStart);
        }).toList();
        break;

      case _TimeFilter.year:
        final yearStart = DateTime(now.year - 1, now.month, now.day);
        list = list.where((t) {
          final d = _txDate(t);
          return d.isAfter(yearStart) || d.isAtSameMomentAs(yearStart);
        }).toList();
        break;

      case _TimeFilter.custom:
        if (_customStart != null && _customEnd != null) {
          final start = _customStart!;
          final end = _customEnd!.add(const Duration(days: 1));

          list = list.where((t) {
            final d = _txDate(t);
            return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
                  (d.isBefore(end) || d.isAtSameMomentAs(end));
          }).toList();
        }
        break;

      case _TimeFilter.all:
        break;
    }

    // Ensure sorted by Date descending (Newest first)
    list.sort((a, b) => _txDate(b).compareTo(_txDate(a)));

    return list;
  }

  DateTime _txDate(Transaction t) {
    return DateTime.tryParse(t.transactionDate) ?? DateTime(2020);
  }

  List<String> get _uniqueTags {
    final tags = <String>{'all'};

    // Add default tags
    tags.addAll(_TAG_STYLES_HIST.keys);

    // Add custom tags from settings
    if (widget.settings != null) {
      tags.addAll(widget.settings!.customTags);
    }

    // Add tags from transactions (fallback)
    tags.addAll(widget.transactions.map((t) => t.tag));

    return tags.toList()..sort();
  }

  // ── Export Logic ─────────────────────────────────────────────────────────

  /// Calculates running balances for ALL transactions to ensure accuracy,
  /// then returns a map of { txId: { 'cash': val, 'upi': val } }.
  Map<String, Map<String, double>> _calculateRunningBalances() {
    // 1. Sort all transactions chronologically
    final sorted = List<Transaction>.from(widget.transactions);
    sorted.sort((a, b) => _txDate(a).compareTo(_txDate(b)));

    // 2. Initialize with starting balances
    double cash = widget.settings?.initialCash ?? 0;
    double upi = widget.settings?.initialUpi ?? 0;

    final Map<String, Map<String, double>> balances = {};

    // 3. Iterate and update
    for (var t in sorted) {
      if (t.type == 'income') {
        if (t.paymentMethod == 'Cash') cash += t.amount; else upi += t.amount;
      } else {
        if (t.paymentMethod == 'Cash') cash -= t.amount; else upi -= t.amount;
      }
      balances[t.id] = {'cash': cash, 'upi': upi};
    }
    return balances;
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF1D6F42)),
              title: const Text('Export as Excel (.xlsx)'),
              onTap: () {
                Navigator.pop(context);
                _generateExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFF40F02)),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _generatePdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // 1. Headers
    sheet.appendRow([
      TextCellValue('Sno'),
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Description'),
      TextCellValue('Amount'),
      TextCellValue('Credit'),
      TextCellValue('Debit'),
      TextCellValue('Cash Balance'),
      TextCellValue('UPI Balance'),
    ]);

    // 2. Data
    final filtered = _filtered;
    final balances = _calculateRunningBalances();
    double totalCredit = 0;
    double totalDebit = 0;

    for (var i = 0; i < filtered.length; i++) {
      final t = filtered[i];
      final b = balances[t.id] ?? {'cash': 0.0, 'upi': 0.0};
      final isIncome = t.type == 'income';
      
      if (isIncome) totalCredit += t.amount; else totalDebit += t.amount;

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(_formatDateOnly(_txDate(t))),
        TextCellValue(_formatTimeOnly(_txDate(t))),
        TextCellValue('${t.tag} ${t.description.isNotEmpty ? "- ${t.description}" : ""}'),
        DoubleCellValue(t.amount),
        DoubleCellValue(isIncome ? t.amount : 0),
        DoubleCellValue(!isIncome ? t.amount : 0),
        DoubleCellValue(b['cash']!),
        DoubleCellValue(b['upi']!),
      ]);
    }

    // 3. Summary Footer
    sheet.appendRow([TextCellValue('')]); // Spacer
    sheet.appendRow([TextCellValue('SUMMARY OF STATEMENT')]);
    sheet.appendRow([TextCellValue('Total Credit'), DoubleCellValue(totalCredit)]);
    sheet.appendRow([TextCellValue('Total Debit'), DoubleCellValue(totalDebit)]);
    
    // Save
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Kasubook_Statement_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path)..createSync(recursive: true);
      await file.writeAsBytes(fileBytes);
      await OpenFile.open(path);
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final filtered = _filtered;
    final balances = _calculateRunningBalances();

    // Calculate totals
    double totalCredit = 0;
    double totalDebit = 0;
    for (var t in filtered) {
      if (t.type == 'income') totalCredit += t.amount; else totalDebit += t.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('KasuBook Statement', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Table
            pw.TableHelper.fromTextArray(
              headers: ['Sno', 'Date', 'Time', 'Description', 'Credit', 'Debit', 'Cash Bal', 'UPI Bal'],
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // Sno
                1: const pw.FixedColumnWidth(60), // Date
                2: const pw.FixedColumnWidth(50), // Time
                3: const pw.FlexColumnWidth(),    // Desc
                4: const pw.FixedColumnWidth(50), // Credit
                5: const pw.FixedColumnWidth(50), // Debit
                6: const pw.FixedColumnWidth(60), // Cash Bal
                7: const pw.FixedColumnWidth(60), // UPI Bal
              },
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
              },
              data: List<List<dynamic>>.generate(filtered.length, (index) {
                final t = filtered[index];
                final b = balances[t.id] ?? {'cash': 0.0, 'upi': 0.0};
                final isIncome = t.type == 'income';
                return [
                  index + 1,
                  _formatDateOnly(_txDate(t)),
                  _formatTimeOnly(_txDate(t)),
                  '${t.tag}\n${t.description}',
                  isIncome ? t.amount.toStringAsFixed(2) : '-',
                  !isIncome ? t.amount.toStringAsFixed(2) : '-',
                  b['cash']!.toStringAsFixed(2),
                  b['upi']!.toStringAsFixed(2),
                ];
              }),
            ),
            
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Summary of Statement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Divider(),
                  pw.Text('Total Credit:   + ${totalCredit.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.green700)),
                  pw.Text('Total Debit:    - ${totalDebit.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red700)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── Date pickers ─────────────────────────────────────────────────────────
  Future<void> _pickCustomDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _customStart : _customEnd) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _customStart = picked; else _customEnd = picked;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    final totalIncome = filtered
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = filtered
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Filter card ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaction History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  IconButton(
                    onPressed: _showExportOptions,
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF6366F1)),
                    tooltip: 'Download Statement',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Search bar
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Time Period + Tag Filter (side by side)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month, size: 16, color: Color(0xFF374151)),
                            SizedBox(width: 4),
                            Text('Time Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _dropdown<_TimeFilter>(
                          value: _timeFilter,
                          items: {
                            _TimeFilter.all: 'All Time',
                            _TimeFilter.today: 'Today',
                            _TimeFilter.week: 'Last 7 Days',
                            _TimeFilter.month: 'Last 30 Days',
                            _TimeFilter.year: 'Last Year',
                            _TimeFilter.custom: 'Custom Range',
                          },
                          onChanged: (v) => setState(() => _timeFilter = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF374151)),
                            SizedBox(width: 4),
                            Text('Tag Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _dropdown<String>(
                          value: _tagFilter,
                          items: {for (final t in _uniqueTags) t: t == 'all' ? 'All Tags' : t},
                          onChanged: (v) => setState(() => _tagFilter = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Custom date range pickers (shown only when custom is selected)
              if (_timeFilter == _TimeFilter.custom) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _datePicker('Start Date', _customStart, isStart: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _datePicker('End Date', _customEnd, isStart: false)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Income / Expense summary ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Income', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                    const SizedBox(height: 4),
                    Text('₹${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    const SizedBox(height: 4),
                    Text('₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Transaction list ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 40, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 10),
                      Text('No transactions found', style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, i) => _TransactionRow(tx: filtered[i]),
                ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _dropdown<T>({required T value, required Map<T, String> items, required void Function(T) onChanged}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, {required bool isStart}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _pickCustomDate(isStart: isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null ? '${value.day}/${value.month}/${value.year}' : 'Pick date',
                  style: TextStyle(fontSize: 14, color: value != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                ),
                const Icon(Icons.calendar_today, size: 17, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime d) {
  final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final min = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} • $hour:$min $ampm';
}

String _formatDateOnly(DateTime d) {
  final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _formatTimeOnly(DateTime d) {
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final min = d.minute.toString().padLeft(2, '0');
  return '$hour:$min $ampm';
}

// ─── Single transaction row ─────────────────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  // ignore: unused_element_parameter
  const _TransactionRow({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final style = _TAG_STYLES_HIST[tx.tag] ?? const _HistTagStyle(bg: Color(0xFFF3F4F6), fg: Color(0xFF374151));

    final date = DateTime.tryParse(tx.transactionDate) ?? DateTime(2020);
    final dateStr = _formatDateTime(date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: tag chip + meta ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Tag chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(tx.tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.fg)),
                    ),
                    const SizedBox(width: 8),
                    // Payment method label
                    Text(tx.paymentMethod, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
                if (tx.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tx.description, style: const TextStyle(fontSize: 14, color: Color(0xFF374151))),
                ],
                const SizedBox(height: 3),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),

          // ── Right: amount ──
          Text(
            '${isIncome ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: amountColor),
          ),
        ],
      ),
    );
  }
}