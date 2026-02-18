// ─── admin_main.dart ─────────────────────────────────────────────────────────
// KasuBook Admin — Notification Manager
// Features:
//   • Send immediate or scheduled notifications
//   • Auto-retry: custom count + interval
//   • Per-notification received count (receipts subcollection)
//   • Real-time history with status, retry info, received/total
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Firebase Config ───────────────────────────────────────────────────────────
class _FB {
  static FirebaseOptions get opts => const FirebaseOptions(
    apiKey: 'AIzaSyDvSwVUFKiQOUJNEqFuHp4O_o2mthRdCGM',
    authDomain: 'kasubook.firebaseapp.com',
    projectId: 'kasubook',
    storageBucket: 'kasubook.firebasestorage.app',
    messagingSenderId: '654865930698',
    appId: '1:654865930698:web:38f4cf7b65c3f7f56fd733',
    measurementId: 'G-G9HXP92JSD',
  );
}

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0F1117);
const _surface = Color(0xFF1A1D27);
const _card    = Color(0xFF21253A);
const _border  = Color(0xFF2E3150);
const _accent  = Color(0xFF6C63FF);
const _accent2 = Color(0xFF9D96FF);
const _green   = Color(0xFF22C55E);
const _orange  = Color(0xFFF59E0B);
const _red     = Color(0xFFEF4444);
const _text    = Color(0xFFE8EAF6);
const _textSec = Color(0xFF8B90B8);
const _inputBg = Color(0xFF161929);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _FB.opts);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'KasuBook Admin',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _accent, surface: _surface),
    ),
    home: const AdminPage(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  final _retryCtrl = TextEditingController(text: '3');
  final _intrvCtrl = TextEditingController(text: '6');

  bool      _sending    = false;
  DateTime? _scheduledDt;
  int       _userCount  = 0;

  final _stream = FirebaseFirestore.instance
      .collection('Notification')
      .orderBy('created_at', descending: true)
      .limit(30)
      .snapshots();

  @override
  void initState() { super.initState(); _loadUserCount(); }

  @override
  void dispose() {
    _titleCtrl.dispose(); _msgCtrl.dispose();
    _retryCtrl.dispose(); _intrvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserCount() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').count().get();
      if (mounted) setState(() => _userCount = snap.count ?? 0);
    } catch (_) {}
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100),
      builder: (ctx, child) => _darkPicker(ctx, child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.now(),
      builder: (ctx, child) => _darkPicker(ctx, child!),
    );
    if (time == null) return;
    setState(() => _scheduledDt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget _darkPicker(BuildContext ctx, Widget child) => Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(primary: _accent, onPrimary: Colors.white, surface: _card),
      dialogTheme: const DialogThemeData(backgroundColor: _surface),
    ),
    child: child,
  );

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final isImmediate = _scheduledDt == null;

    final data = <String, dynamic>{
      'title':                _titleCtrl.text.trim(),
      'message':              _msgCtrl.text.trim(),
      'Notification_send':    isImmediate,
      'max_retries':          int.tryParse(_retryCtrl.text.trim()) ?? 3,
      'retry_interval_hours': int.tryParse(_intrvCtrl.text.trim()) ?? 6,
      'retry_count':          0,
      'next_retry_at':        null,
      'received_count':       0,
      'created_at':           DateTime.now().toIso8601String(),
      'delivered_at':         null,
    };

    if (_scheduledDt != null) {
      final d = _scheduledDt!;
      final y  = d.year.toString().padLeft(4, '0');
      final mo = d.month.toString().padLeft(2, '0');
      final dy = d.day.toString().padLeft(2, '0');
      final h  = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      data['date'] = '$y-$mo-$dy';
      data['time'] = '$h:$mi';
    }

    try {
      await FirebaseFirestore.instance
          .collection('Notification')
          .add(data)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      _titleCtrl.clear();
      _msgCtrl.clear();
      setState(() { _scheduledDt = null; _sending = false; });
      _snack(isImmediate ? '✅ Sent to all users!' : '🕐 Scheduled!', _green);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final msg = e.toString().split('\n').first;
      _snack('❌ $msg', _red);
    }
  }

  Future<void> _resend(String id) async {
    await FirebaseFirestore.instance.collection('Notification').doc(id).update({
      'Notification_send': true, 'delivered_at': null,
      'retry_count': 0, 'next_retry_at': null,
      'resent_at': DateTime.now().toIso8601String(),
    });
    _snack('🔄 Resent!', _accent);
  }

  Future<void> _delete(String id) async =>
      FirebaseFirestore.instance.collection('Notification').doc(id).delete();

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Row(children: [
          // Left panel — compose form
          SizedBox(
            width: 420,
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                border: Border(right: BorderSide(color: _border)),
              ),
              child: Column(children: [
                _panelHeader(),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _composeForm(),
                )),
              ]),
            ),
          ),
          // Right panel — history
          Expanded(child: Column(children: [
            _historyHeader(),
            Expanded(child: _historyList()),
          ])),
        ]),
      ),
    );
  }

  // ── Left Panel Header ──────────────────────────────────────────────────────
  Widget _panelHeader() => Container(
    padding: const EdgeInsets.all(22),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _accent.withAlpha(30), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withAlpha(80)),
        ),
        child: const Icon(Icons.campaign_outlined, color: _accent, size: 22),
      ),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('KasuBook Admin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
        Text('Notification Manager', style: TextStyle(fontSize: 12, color: _textSec)),
      ]),
    ]),
  );

  // ── Compose Form ───────────────────────────────────────────────────────────
  Widget _composeForm() => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Stats
      Row(children: [
        _chip(Icons.people_outline, '$_userCount Users', _accent),
        const SizedBox(width: 8),
        _chip(Icons.send_outlined, 'Will receive', _green),
      ]),
      const SizedBox(height: 22),

      _label('Title'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _titleCtrl,
        style: const TextStyle(color: _text, fontSize: 14),
        decoration: _inp('Notification title', Icons.title_outlined),
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
      ),
      const SizedBox(height: 14),

      _label('Message'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _msgCtrl, maxLines: 4,
        style: const TextStyle(color: _text, fontSize: 14),
        decoration: _inp('Notification message', Icons.message_outlined),
        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
      ),
      const SizedBox(height: 14),

      // Schedule picker
      _label('Schedule (Optional)'),
      const SizedBox(height: 8),
      _schedulePicker(),
      const SizedBox(height: 14),

      // Retry settings
      _label('Auto-Retry Settings'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inputBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Resend to users who haven\'t received yet',
              style: TextStyle(fontSize: 12, color: _textSec)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Retry Times', style: TextStyle(fontSize: 11, color: _textSec)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _retryCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _text, fontSize: 14),
                decoration: _inp('3', Icons.replay_outlined),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Interval (hours)', style: TextStyle(fontSize: 11, color: _textSec)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _intrvCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _text, fontSize: 14),
                decoration: _inp('6', Icons.timer_outlined),
              ),
            ])),
          ]),
        ]),
      ),
      const SizedBox(height: 24),

      // Send button
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent, foregroundColor: Colors.white,
            disabledBackgroundColor: _accent.withAlpha(80),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _sending
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_scheduledDt == null ? Icons.send : Icons.schedule_send, size: 18),
                  const SizedBox(width: 8),
                  Text(_scheduledDt == null ? 'Send Now' : 'Schedule Notification',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
        ),
      ),
    ]),
  );

  Widget _schedulePicker() => GestureDetector(
    onTap: _pickDateTime,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _inputBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheduledDt != null ? _accent.withAlpha(120) : _border),
      ),
      child: Row(children: [
        Icon(
          _scheduledDt != null ? Icons.event_available : Icons.calendar_today_outlined,
          size: 18, color: _scheduledDt != null ? _accent2 : _textSec,
        ),
        const SizedBox(width: 12),
        Expanded(child: _scheduledDt == null
            ? const Text('Tap to schedule for later',
                style: TextStyle(color: _textSec, fontSize: 13))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Scheduled', style: TextStyle(fontSize: 11, color: _textSec)),
                const SizedBox(height: 2),
                Text(_fmtDt(_scheduledDt!),
                    style: const TextStyle(fontSize: 14, color: _text, fontWeight: FontWeight.w600)),
              ])),
        if (_scheduledDt != null)
          GestureDetector(
            onTap: () => setState(() => _scheduledDt = null),
            child: const Icon(Icons.close, size: 16, color: _textSec),
          ),
      ]),
    ),
  );

  // ── Right Panel ────────────────────────────────────────────────────────────
  Widget _historyHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: const BoxDecoration(
      color: _surface, border: Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(children: [
      const Text('Sent Notifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
      const Spacer(),
      StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (ctx, snap) {
          if (!snap.hasData) return const SizedBox();
          final docs = snap.data!.docs;
          final delivered = docs.where((d) => (d.data() as Map)['delivered_at'] != null).length;
          final pending   = docs.length - delivered;
          return Row(children: [
            _badge('$delivered Delivered', _green),
            if (pending > 0) ...[const SizedBox(width: 8), _badge('$pending Pending', _orange)],
          ]);
        },
      ),
    ]),
  );

  Widget _historyList() => StreamBuilder<QuerySnapshot>(
    stream: _stream,
    builder: (ctx, snap) {
      if (snap.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator(color: _accent));
      if (!snap.hasData || snap.data!.docs.isEmpty)
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.notifications_none, size: 48, color: _textSec.withAlpha(80)),
          const SizedBox(height: 12),
          const Text('No notifications yet', style: TextStyle(color: _textSec)),
        ]));

      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: snap.data!.docs.length,
        itemBuilder: (ctx, i) {
          final doc  = snap.data!.docs[i];
          final data = doc.data() as Map<String, dynamic>;
          return _notifCard(doc.id, data);
        },
      );
    },
  );

  Widget _notifCard(String id, Map<String, dynamic> data) {
    final title         = data['title']        as String? ?? 'Untitled';
    final message       = data['message']      as String? ?? '';
    final deliveredAt   = data['delivered_at'];
    final date          = data['date']         as String?;
    final time          = data['time']         as String?;
    final createdAt     = data['created_at']   as String?;
    final retryCount    = data['retry_count']  as int? ?? 0;
    final maxRetries    = data['max_retries']  as int? ?? 3;
    final nextRetryAt   = data['next_retry_at'] as String?;
    final receivedCount = data['received_count'] as int? ?? 0;
    final isDelivered   = deliveredAt != null;
    final isScheduled   = !isDelivered && date != null && time != null && retryCount == 0;
    final isRetrying    = !isDelivered && retryCount > 0 && retryCount < maxRetries;

    Color statusColor = isDelivered ? _green : isScheduled ? _orange : isRetrying ? _accent2 : _textSec;
    String statusLabel = isDelivered
        ? '✓ Delivered'
        : isScheduled ? '⏰ Scheduled'
        : isRetrying  ? '🔄 Retrying ($retryCount/$maxRetries)'
        : '⏳ Pending';
    IconData statusIcon = isDelivered
        ? Icons.check_circle_outline
        : isScheduled ? Icons.schedule
        : isRetrying  ? Icons.replay
        : Icons.hourglass_empty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDelivered ? _green.withAlpha(40) : _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Title row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, size: 15, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text),
              overflow: TextOverflow.ellipsis)),
          _badge(statusLabel, statusColor),
          const SizedBox(width: 6),
          if (isDelivered) _iconBtn(Icons.refresh, _accent2, () => _resend(id)),
          _iconBtn(Icons.delete_outline, _red.withAlpha(180), () => _delete(id)),
        ]),

        const SizedBox(height: 10),

        // Message preview
        Text(message,
            style: const TextStyle(fontSize: 13, color: _textSec, height: 1.4),
            maxLines: 2, overflow: TextOverflow.ellipsis),

        const SizedBox(height: 12),

        // Info chips row
        Wrap(spacing: 10, runSpacing: 6, children: [
          // Received count
          _infoChip(
            Icons.people_outline,
            '$receivedCount / $_userCount received',
            receivedCount >= _userCount ? _green : _orange,
          ),
          if (date != null) _infoChip(Icons.calendar_today, date, _accent2),
          if (time != null) _infoChip(Icons.access_time, time, _accent2),
          if (retryCount > 0)
            _infoChip(Icons.replay, '$retryCount retries (max $maxRetries)', _accent2),
          if (nextRetryAt != null && !isDelivered)
            _infoChip(Icons.schedule, 'Next: ${_fmtTs(nextRetryAt)}', _orange),
          if (createdAt != null)
            _infoChip(Icons.access_time_outlined, _fmtTs(createdAt), _textSec),
        ]),
      ]),
    );
  }

  // ── Small Widgets ──────────────────────────────────────────────────────────
  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withAlpha(20), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withAlpha(60)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(25), borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _infoChip(IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]);

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20), borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSec));

  InputDecoration _inp(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _textSec, fontSize: 13),
    prefixIcon: Icon(icon, size: 18, color: _textSec),
    filled: true, fillColor: _inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border:             OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
    enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
    focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent)),
    errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red)),
  );

  String _fmtDt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day}, ${dt.year}  '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  String _fmtTs(String iso) {
    try { return _fmtDt(DateTime.parse(iso)); } catch (_) { return iso; }
  }
}