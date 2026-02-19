// analytics_page.dart — Dark Theme
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models.dart';

// ── Dark Theme Color Palette ──────────────────────────────────────────────────
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
const _kGridLine  = Color(0xFF2A2B40);

const List<String> _DEFAULT_TAGS = [
  'Food', 'Snacks', 'Travel', 'Friends', 'Shopping',
  'Bills', 'Entertainment', 'Health', 'Others',
];

class AnalyticsPage extends StatefulWidget {
  final List<Transaction> transactions;
  final UserSettings settings;

  const AnalyticsPage({super.key, required this.transactions, required this.settings});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _timeFilter = 'All';
  Set<String> _selectedTags = {};
  int _pieTouchedIndex = -1;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _selectedTags = {};
  }

  List<String> get _allTags => [..._DEFAULT_TAGS, ...widget.settings.customTags];

  List<Transaction> get _filtered {
    final now = DateTime.now();
    return widget.transactions.where((t) {
      final d = DateTime.tryParse(t.transactionDate) ?? now;
      if (_timeFilter == 'Today') {
        if (!(d.day == now.day && d.month == now.month && d.year == now.year)) return false;
      } else if (_timeFilter == 'Week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        if (d.isBefore(weekAgo)) return false;
      } else if (_timeFilter == 'Month') {
        if (!(d.month == now.month && d.year == now.year)) return false;
      }
      else if (_timeFilter == 'Custom') {
        if (_customStart != null) {
          final start = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
          if (d.isBefore(start)) return false;
        }
        if (_customEnd != null) {
          final end = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
          if (d.isAfter(end)) return false;
        }
      }
      if (_selectedTags.isNotEmpty && !_selectedTags.contains(t.tag)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final expenses = filtered.where((t) => t.type == 'expense').toList();

    final Map<String, double> tagMap = {};
    for (final tx in expenses) {
      tagMap[tx.tag] = (tagMap[tx.tag] ?? 0) + tx.amount;
    }

    double cashExp = filtered.where((t) => t.method == 'Cash' && t.type == 'expense').fold(0, (s, t) => s + t.amount);
    double cashInc = filtered.where((t) => t.method == 'Cash' && t.type == 'income').fold(0, (s, t) => s + t.amount);
    double upiExp = filtered.where((t) => t.method == 'UPI' && t.type == 'expense').fold(0, (s, t) => s + t.amount);
    double upiInc = filtered.where((t) => t.method == 'UPI' && t.type == 'income').fold(0, (s, t) => s + t.amount);

    final Map<String, double> upiAccountExp = {};
    for (final tx in filtered.where((t) => t.method == 'UPI' && t.type == 'expense')) {
      final key = tx.resolvedBank ?? 'UPI';
      upiAccountExp[key] = (upiAccountExp[key] ?? 0) + tx.amount;
    }

    final totalExp = filtered.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
    final totalInc = filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextPrim)),
          const SizedBox(height: 4),
          const Text('Track your spending patterns', style: TextStyle(fontSize: 13, color: _kTextSec)),
          const SizedBox(height: 16),

          _buildTimeFilter(),
          const SizedBox(height: 14),

          _buildTagFilter(),
          const SizedBox(height: 14),

          // Summary Cards
          Row(children: [
            Expanded(child: _summaryCard('Income', totalInc, _kGreen, Icons.arrow_upward)),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Expense', totalExp, _kRed, Icons.arrow_downward)),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Net', totalInc - totalExp,
                (totalInc - totalExp) >= 0 ? _kAccent2 : _kRed, Icons.balance)),
          ]),
          const SizedBox(height: 16),

          // Pie Chart
          _darkCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.pie_chart_outline, size: 18, color: _kAccent2),
                const SizedBox(width: 8),
                const Text('Expenses by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kTextPrim)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _kInputBg, borderRadius: BorderRadius.circular(12)),
                  child: const Text('% Share', style: TextStyle(fontSize: 11, color: _kTextSec)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Showing ${_timeFilter == "All" ? "all time" : _timeFilter.toLowerCase()} data',
                  style: const TextStyle(fontSize: 12, color: _kTextSec)),
              const SizedBox(height: 20),
              tagMap.isEmpty ? _emptyState('No expense data for this period') : _buildPieChart(tagMap, totalExp),
            ],
          )),
          const SizedBox(height: 14),

          // Bar Chart
          _darkCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.bar_chart, size: 18, color: _kGreen),
                const SizedBox(width: 8),
                const Text('Cash vs UPI Spending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kTextPrim)),
              ]),
              const SizedBox(height: 4),
              const Text('Expense & Income split by payment method', style: TextStyle(fontSize: 12, color: _kTextSec)),
              const SizedBox(height: 16),
              _buildLegend(),
              const SizedBox(height: 16),
              (cashExp == 0 && cashInc == 0 && upiExp == 0 && upiInc == 0)
                  ? _emptyState('No transaction data for this period')
                  : _buildBarChart(cashExp, cashInc, upiExp, upiInc),
            ],
          )),
          const SizedBox(height: 14),

          // UPI Breakdown
          if (upiAccountExp.isNotEmpty) ...[
            _darkCard(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  const Text('UPI Account Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kTextPrim)),
                ]),
                const SizedBox(height: 4),
                const Text('Expenses per UPI account', style: TextStyle(fontSize: 12, color: _kTextSec)),
                const SizedBox(height: 16),
                ...upiAccountExp.entries.map((e) => _upiAccountRow(e.key, e.value, totalExp)),
              ],
            )),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _darkCard(Widget child) => Container(
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kCardBorder),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    padding: const EdgeInsets.all(20),
    child: child,
  );

  Widget _buildTimeFilter() {
    return _darkCard(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Time Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
        const SizedBox(height: 10),
        Row(
          children: ['All', 'Today', 'Week', 'Month', 'Custom'].map((f) {
            final isSelected = _timeFilter == f;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _timeFilter = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)])
                        : null,
                    color: isSelected ? null : _kInputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.transparent : _kInputBorder),
                  ),
                  child: Text(f, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _kTextSec)),
                ),
              ),
            );
          }).toList(),
        ),
        if (_timeFilter == 'Custom') ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _datePicker('Start Date', _customStart, isStart: true)),
            const SizedBox(width: 12),
            Expanded(child: _datePicker('End Date', _customEnd, isStart: false)),
          ]),
        ],
      ],
    ));
  }

  Widget _buildTagFilter() {
    return _darkCard(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Filter by Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
          GestureDetector(
            onTap: () => setState(() => _selectedTags = {}),
            child: Text(
              _selectedTags.isEmpty ? 'All selected' : 'Clear (${_selectedTags.length})',
              style: TextStyle(fontSize: 12, color: _selectedTags.isEmpty ? const Color(0xFF5C5E7A) : _kAccent2),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _allTags.map((tag) {
            final isSelected = _selectedTags.isEmpty || _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedTags.isEmpty) {
                    _selectedTags = Set.from(_allTags)..remove(tag);
                  } else if (_selectedTags.contains(tag)) {
                    _selectedTags = Set.from(_selectedTags)..remove(tag);
                  } else {
                    _selectedTags = Set.from(_selectedTags)..add(tag);
                    if (_selectedTags.length == _allTags.length) _selectedTags = {};
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? _kAccent.withAlpha(25) : _kInputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? _kAccent2 : _kInputBorder, width: 1.5),
                ),
                child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: isSelected ? _kTextPrim : _kTextSec)),
              ),
            );
          }).toList(),
        ),
      ],
    ));
  }

  Widget _buildPieChart(Map<String, double> data, double total) {
    final keys = data.keys.toList();
    final sections = keys.asMap().entries.map((entry) {
      final i = entry.key;
      final tag = entry.value;
      final value = data[tag]!;
      final pct = total > 0 ? (value / total * 100) : 0.0;
      final isTouched = _pieTouchedIndex == i;
      return PieChartSectionData(
        value: value,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 72.0 : 56.0,
        color: _tagColor(i),
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Column(children: [
      SizedBox(
        height: 220,
        child: PieChart(PieChartData(
          sections: sections,
          pieTouchData: PieTouchData(touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                _pieTouchedIndex = -1; return;
              }
              _pieTouchedIndex = response.touchedSection!.touchedSectionIndex;
            });
          }),
          centerSpaceRadius: 42.0,
          sectionsSpace: 2.0,
        )),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12, runSpacing: 8, alignment: WrapAlignment.center,
        children: keys.asMap().entries.map((entry) {
          final i = entry.key;
          final tag = entry.value;
          final value = data[tag]!;
          final pct = total > 0 ? (value / total * 100) : 0.0;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: _tagColor(i), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('$tag (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: _kTextSec)),
          ]);
        }).toList(),
      ),
    ]);
  }

  Widget _buildLegend() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _legendDot(_kRed, 'Expense'), const SizedBox(width: 14),
      _legendDot(_kGreen, 'Income'), const SizedBox(width: 14),
      _legendDot(_kTextSec, 'Cash'), const SizedBox(width: 8),
      _legendDot(_kAccent2, 'UPI'),
    ]);
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: _kTextSec)),
  ]);

  Widget _buildBarChart(double cashExp, double cashInc, double upiExp, double upiInc) {
    final maxY = [cashExp, cashInc, upiExp, upiInc].reduce((a, b) => a > b ? a : b);
    final yMax = maxY > 0 ? maxY * 1.3 : 100.0;

    return SizedBox(
      height: 220,
      child: BarChart(BarChartData(
        maxY: yMax,
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: cashExp, color: _kRed, width: 20.0, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: cashInc, color: _kGreen, width: 20.0, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ], barsSpace: 4.0),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: upiExp, color: _kRed.withAlpha(180), width: 20.0, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: upiInc, color: _kGreen.withAlpha(180), width: 20.0, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ], barsSpace: 4.0),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(v == 0 ? 'Cash' : 'UPI',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextSec)),
            ),
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 50.0,
            getTitlesWidget: (v, _) => Text('₹${_formatK(v)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF5C5E7A))),
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: _kGridLine, strokeWidth: 1.0),
        ),
        borderData: FlBorderData(show: false),
      )),
    );
  }

  Widget _upiAccountRow(String bankName, double expense, double totalExp) {
    final pct = totalExp > 0 ? (expense / totalExp * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Row(children: [
              const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFF60A5FA)),
              const SizedBox(width: 6),
              Flexible(child: Text(bankName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrim))),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text('₹${expense.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kRed))),
            Text('${pct.toStringAsFixed(1)}% of total', style: const TextStyle(fontSize: 11, color: _kTextSec)),
          ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).toDouble(),
            backgroundColor: _kInputBg,
            color: _kAccent2,
            minHeight: 6.0,
          ),
        ),
      ]),
    );
  }

  Widget _summaryCard(String label, double value, Color color, IconData icon) => Container(
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(60)),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('₹${_formatK(value.abs())}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: _kTextSec)),
    ]),
  );

  Widget _emptyState(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        const Icon(Icons.bar_chart, size: 40, color: Color(0xFF3A3B52)),
        const SizedBox(height: 8),
        Text(msg, style: const TextStyle(color: _kTextSec, fontSize: 14)),
      ]),
    ),
  );

  Color _tagColor(int index) {
    const colors = [
      Color(0xFF8B5CF6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444),
      Color(0xFF60A5FA), Color(0xFFF472B6), Color(0xFF2DD4BF), Color(0xFFEC4899),
      Color(0xFFFB923C), Color(0xFFA3E635),
    ];
    return colors[index % colors.length];
  }

  String _formatK(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
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