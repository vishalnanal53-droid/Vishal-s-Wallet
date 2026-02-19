// ─── transaction_history.dart ───────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'models.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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
const _kDivider   = Color(0xFF2A2B40);

// Dark-adapted tag styles
const Map<String, _HistTagStyle> _TAG_STYLES_HIST = {
  'Food':          _HistTagStyle(bg: Color(0xFF3B2A0E), fg: Color(0xFFFBBF24)),
  'Snacks':        _HistTagStyle(bg: Color(0xFF332808), fg: Color(0xFFFCD34D)),
  'Travel':        _HistTagStyle(bg: Color(0xFF2D1B69), fg: Color(0xFFC4B5FD)),
  'Friends':       _HistTagStyle(bg: Color(0xFF3B0F24), fg: Color(0xFFF9A8D4)),
  'Shopping':      _HistTagStyle(bg: Color(0xFF1E2060), fg: Color(0xFFA5B4FC)),
  'Bills':         _HistTagStyle(bg: Color(0xFF3B0F0F), fg: Color(0xFFFCA5A5)),
  'Entertainment': _HistTagStyle(bg: Color(0xFF0F3B2E), fg: Color(0xFF6EE7B7)),
  'Health':        _HistTagStyle(bg: Color(0xFF0F2E1B), fg: Color(0xFF86EFAC)),
  'Others':        _HistTagStyle(bg: Color(0xFF252636), fg: Color(0xFF9CA3AF)),
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
  String _typeFilter = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;

  List<Transaction> _getBaseFiltered() {
    var list = widget.transactions.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) => t.description.toLowerCase().contains(q) || t.tag.toLowerCase().contains(q)).toList();
    }
    if (_tagFilter != 'all') {
      list = list.where((t) => t.tag == _tagFilter).toList();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_timeFilter) {
      case _TimeFilter.today:
        list = list.where((t) { final d = _txDate(t); return d.isAfter(today) || d.isAtSameMomentAs(today); }).toList();
        break;
      case _TimeFilter.week:
        final weekStart = today.subtract(const Duration(days: 7));
        list = list.where((t) { final d = _txDate(t); return d.isAfter(weekStart) || d.isAtSameMomentAs(weekStart); }).toList();
        break;
      case _TimeFilter.month:
        final monthStart = DateTime(now.year, now.month - 1, now.day);
        list = list.where((t) { final d = _txDate(t); return d.isAfter(monthStart) || d.isAtSameMomentAs(monthStart); }).toList();
        break;
      case _TimeFilter.year:
        final yearStart = DateTime(now.year - 1, now.month, now.day);
        list = list.where((t) { final d = _txDate(t); return d.isAfter(yearStart) || d.isAtSameMomentAs(yearStart); }).toList();
        break;
      case _TimeFilter.custom:
        if (_customStart != null && _customEnd != null) {
          final start = _customStart!;
          final end = _customEnd!.add(const Duration(days: 1));
          list = list.where((t) { final d = _txDate(t); return (d.isAfter(start) || d.isAtSameMomentAs(start)) && (d.isBefore(end) || d.isAtSameMomentAs(end)); }).toList();
        }
        break;
      case _TimeFilter.all:
        break;
    }
    return list;
  }

  List<Transaction> get _filtered {
    var list = _getBaseFiltered();
    if (_typeFilter != 'all') {
      list = list.where((t) => t.type == _typeFilter).toList();
    }
    list.sort((a, b) => _txDate(b).compareTo(_txDate(a)));
    return list;
  }

  DateTime _txDate(Transaction t) => DateTime.tryParse(t.transactionDate) ?? DateTime(2020);

  List<String> get _uniqueTags {
    final tags = <String>{'all'};
    tags.addAll(_TAG_STYLES_HIST.keys);
    if (widget.settings != null) tags.addAll(widget.settings!.customTags);
    tags.addAll(widget.transactions.map((t) => t.tag));
    return tags.toList()..sort();
  }

  Map<String, Map<String, double>> _calculateRunningBalances() {
    final sorted = List<Transaction>.from(widget.transactions);
    sorted.sort((a, b) => _txDate(a).compareTo(_txDate(b)));
    double cash = widget.settings?.initialCash ?? 0;
    double upi = widget.settings?.initialUpi ?? 0;
    final Map<String, Map<String, double>> balances = {};
    for (var t in sorted) {
      if (t.type == 'income') {
        if (t.method == 'Cash') cash += t.amount; else upi += t.amount;
      } else {
        if (t.method == 'Cash') cash -= t.amount; else upi -= t.amount;
      }
      balances[t.id] = {'cash': cash, 'upi': upi};
    }
    return balances;
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _kCardBorder),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF22C55E)),
              title: const Text('Export as Excel (.xlsx)', style: TextStyle(color: _kTextPrim)),
              onTap: () { Navigator.pop(context); _generateExcel(); },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
              title: const Text('Export as PDF', style: TextStyle(color: _kTextPrim)),
              onTap: () { Navigator.pop(context); _generatePdf(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([
      TextCellValue('Sno'), TextCellValue('Date'), TextCellValue('Time'),
      TextCellValue('Description'), TextCellValue('Amount'), TextCellValue('Credit'),
      TextCellValue('Debit'), TextCellValue('Cash Balance'), TextCellValue('UPI Balance'),
    ]);
    final filtered = _filtered;
    final balances = _calculateRunningBalances();
    double totalCredit = 0, totalDebit = 0;
    for (var i = 0; i < filtered.length; i++) {
      final t = filtered[i];
      final b = balances[t.id] ?? {'cash': 0.0, 'upi': 0.0};
      final isIncome = t.type == 'income';
      if (isIncome) totalCredit += t.amount; else totalDebit += t.amount;
      sheet.appendRow([
        IntCellValue(i + 1), TextCellValue(_formatDateOnly(_txDate(t))), TextCellValue(_formatTimeOnly(_txDate(t))),
        TextCellValue('${t.tag} ${t.description.isNotEmpty ? "- ${t.description}" : ""}'),
        DoubleCellValue(t.amount), DoubleCellValue(isIncome ? t.amount : 0),
        DoubleCellValue(!isIncome ? t.amount : 0), DoubleCellValue(b['cash']!), DoubleCellValue(b['upi']!),
      ]);
    }
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('SUMMARY OF STATEMENT')]);
    sheet.appendRow([TextCellValue('Total Credit'), DoubleCellValue(totalCredit)]);
    sheet.appendRow([TextCellValue('Total Debit'), DoubleCellValue(totalDebit)]);
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Kasubook_Statement_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path)..createSync(recursive: true);
      await file.writeAsBytes(fileBytes);
      await OpenFilex.open(path);
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final filtered = _filtered;
    final balances = _calculateRunningBalances();
    double totalCredit = 0, totalDebit = 0;
    for (var t in filtered) {
      if (t.type == 'income') totalCredit += t.amount; else totalDebit += t.amount;
    }
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
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
          pw.TableHelper.fromTextArray(
            headers: ['Sno', 'Date', 'Time', 'Description', 'Credit', 'Debit', 'Cash Bal', 'UPI Bal'],
            columnWidths: {
              0: const pw.FixedColumnWidth(30), 1: const pw.FixedColumnWidth(60), 2: const pw.FixedColumnWidth(50),
              3: const pw.FlexColumnWidth(), 4: const pw.FixedColumnWidth(50), 5: const pw.FixedColumnWidth(50),
              6: const pw.FixedColumnWidth(60), 7: const pw.FixedColumnWidth(60),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            data: List<List<dynamic>>.generate(filtered.length, (index) {
              final t = filtered[index];
              final b = balances[t.id] ?? {'cash': 0.0, 'upi': 0.0};
              final isIncome = t.type == 'income';
              return [
                index + 1, _formatDateOnly(_txDate(t)), _formatTimeOnly(_txDate(t)),
                '${t.tag}\n${t.description}', isIncome ? t.amount.toStringAsFixed(2) : '-',
                !isIncome ? t.amount.toStringAsFixed(2) : '-',
                b['cash']!.toStringAsFixed(2), b['upi']!.toStringAsFixed(2),
              ];
            }),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Summary of Statement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Divider(),
              pw.Text('Total Credit:   + ${totalCredit.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.green700)),
              pw.Text('Total Debit:    - ${totalDebit.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red700)),
            ]),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _customStart : _customEnd) ?? DateTime.now(),
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
      setState(() { if (isStart) _customStart = picked; else _customEnd = picked; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseList = _getBaseFiltered();
    final totalIncome = baseList.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = baseList.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
    final filtered = _filtered;
    
    const int displayLimit = 50;
    final bool hasMore = filtered.length > displayLimit;
    final List<Transaction> displayList = hasMore ? filtered.take(displayLimit).toList() : filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter card
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaction History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kTextPrim)),
                  IconButton(
                    onPressed: _showExportOptions,
                    icon: const Icon(Icons.download_rounded, color: _kAccent2),
                    tooltip: 'Download Statement',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: _kTextPrim),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(color: Color(0xFF5C5E7A)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF5C5E7A)),
                  filled: true,
                  fillColor: _kInputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.calendar_month, size: 14, color: _kTextSec),
                        SizedBox(width: 4),
                        Text('Time Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
                      ]),
                      const SizedBox(height: 6),
                      _dropdown<_TimeFilter>(
                        value: _timeFilter,
                        items: {
                          _TimeFilter.all: 'All Time', _TimeFilter.today: 'Today',
                          _TimeFilter.week: 'Last 7 Days', _TimeFilter.month: 'Last 30 Days',
                          _TimeFilter.year: 'Last Year', _TimeFilter.custom: 'Custom Range',
                        },
                        onChanged: (v) => setState(() => _timeFilter = v),
                      ),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.filter_alt_outlined, size: 14, color: _kTextSec),
                        SizedBox(width: 4),
                        Text('Tag Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
                      ]),
                      const SizedBox(height: 6),
                      _dropdown<String>(
                        value: _tagFilter,
                        items: {for (final t in _uniqueTags) t: t == 'all' ? 'All Tags' : t},
                        onChanged: (v) => setState(() => _tagFilter = v),
                      ),
                    ],
                  )),
                ],
              ),
              if (_timeFilter == _TimeFilter.custom) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _datePicker('Start Date', _customStart, isStart: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _datePicker('End Date', _customEnd, isStart: false)),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Summary cards
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _typeFilter = _typeFilter == 'income' ? 'all' : 'income'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _typeFilter == 'income' ? _kGreen.withAlpha(40) : _kGreen.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _typeFilter == 'income' ? _kGreen : _kGreen.withAlpha(60), width: _typeFilter == 'income' ? 1.5 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('₹${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGreen)),
                ),
              ]),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _typeFilter = _typeFilter == 'expense' ? 'all' : 'expense'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _typeFilter == 'expense' ? _kRed.withAlpha(40) : _kRed.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _typeFilter == 'expense' ? _kRed : _kRed.withAlpha(60), width: _typeFilter == 'expense' ? 1.5 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kRed)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kRed)),
                ),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 14),

        // Transaction list
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: displayList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(children: [
                    Icon(Icons.search_off, size: 40, color: Color(0xFF5C5E7A)),
                    SizedBox(height: 10),
                    Text('No transactions found', style: TextStyle(color: _kTextSec, fontSize: 15)),
                  ]),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayList.length + (hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _kDivider),
                  itemBuilder: (context, i) {
                    if (hasMore && i == displayList.length) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Text('Showing last 50 transactions', style: TextStyle(color: _kTextSec, fontSize: 12)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _showExportOptions,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _kAccent.withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _kAccent.withAlpha(50)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download_rounded, size: 16, color: _kAccent2),
                                    SizedBox(width: 6),
                                    Text('Download to see more', style: TextStyle(color: _kAccent2, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _TransactionRow(
                      tx: displayList[i],
                      upiAccountNames: widget.settings?.upiAccounts.map((a) => a.bankName).toList() ?? [],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({required T value, required Map<T, String> items, required void Function(T) onChanged}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kInputBg,
        border: Border.all(color: _kInputBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: _kCard,
          style: const TextStyle(fontSize: 13, color: _kTextPrim),
          icon: const Icon(Icons.keyboard_arrow_down, color: _kTextSec, size: 18),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, {required bool isStart}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () => _pickCustomDate(isStart: isStart),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kInputBg,
            border: Border.all(color: _kInputBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              value != null ? '${value.day}/${value.month}/${value.year}' : 'Pick date',
              style: TextStyle(fontSize: 13, color: value != null ? _kTextPrim : const Color(0xFF5C5E7A)),
            ),
            const Icon(Icons.calendar_today, size: 16, color: _kTextSec),
          ]),
        ),
      ),
    ]);
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

class _TransactionRow extends StatelessWidget {
  final Transaction tx;
  final List<String> upiAccountNames;

  const _TransactionRow({required this.tx, required this.upiAccountNames});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? _kGreen : _kRed;
    final style = _TAG_STYLES_HIST[tx.tag] ?? const _HistTagStyle(bg: Color(0xFF252636), fg: Color(0xFF9CA3AF));

    final date = DateTime.tryParse(tx.transactionDate) ?? DateTime(2020);
    final dateStr = _formatDateTime(date);

    // Use model helpers: tx.paymentLabel gives 'UPI · HDFC' or 'Cash'
    final paymentLabel = tx.paymentLabel;
    final paymentColor = tx.method == 'Cash' ? const Color(0xFF22C55E) : const Color(0xFF60A5FA);
    final paymentBg = tx.method == 'Cash' ? const Color(0xFF0F2E1B) : const Color(0xFF0F1F3B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(20)),
                    child: Text(tx.tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: style.fg)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: paymentBg, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        tx.method == 'Cash' ? Icons.currency_rupee : Icons.account_balance_outlined,
                        size: 11, color: paymentColor,
                      ),
                      const SizedBox(width: 3),
                      Text(paymentLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: paymentColor)),
                    ]),
                  ),
                ]),
                if (tx.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(tx.description, style: const TextStyle(fontSize: 13, color: _kTextPrim)),
                ],
                const SizedBox(height: 3),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF5C5E7A))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}