// ─── admin_notification_app.dart ────────────────────────────────────────────
//
// ADMIN APP - Send Notifications to Users
// This app allows admins to send notifications that will be picked up by user apps
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Firebase Configuration ───────────────────────────────────────────────────
class _FirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvSwVUFKiQOUJNEqFuHp4O_o2mthRdCGM',
    authDomain: 'kasubook.firebaseapp.com',
    projectId: 'kasubook',
    storageBucket: 'kasubook.firebasestorage.app',
    messagingSenderId: '654865930698',
    appId: '1:654865930698:web:38f4cf7b65c3f7f56fd733',
    measurementId: 'G-G9HXP92JSD',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _FirebaseOptions.currentPlatform);
  runApp(const AdminNotificationApp());
}

class AdminNotificationApp extends StatelessWidget {
  const AdminNotificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasuBook Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AdminHomePage(),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _sending = false;
  List<Map<String, dynamic>> _sentNotifications = [];
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _loadSentNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Load previously sent notifications
  Future<void> _loadSentNotifications() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Notification')
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      setState(() {
        _sentNotifications = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _scheduledTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // Send notification to Firebase
  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    try {
      final Map<String, dynamic> notificationData = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'Notification_send': true,
        'created_at': DateTime.now().toIso8601String(),
        'delivered_at': null,
      };

      if (_scheduledTime != null) {
        notificationData['scheduled_at'] = _scheduledTime!.toIso8601String();
      }

      // Create notification document in Firebase
      await FirebaseFirestore.instance.collection('Notification').add(notificationData);

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() => _scheduledTime = null);

      // Reload notifications list
      await _loadSentNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Resend a notification
  Future<void> _resendNotification(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('Notification')
          .doc(id)
          .update({
        'Notification_send': true,
        'delivered_at': null,
        'resent_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Notification resent!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KasuBook Admin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Send Notifications to Users',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Send Notification Form
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '📨 Send New Notification',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Title
                                  TextFormField(
                                    controller: _titleController,
                                    decoration: InputDecoration(
                                      labelText: 'Notification Title',
                                      hintText: 'e.g., Update your expenses!',
                                      prefixIcon: const Icon(Icons.title),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Title is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Message
                                  TextFormField(
                                    controller: _messageController,
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      labelText: 'Message',
                                      hintText: 'Enter your notification message here...',
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 60),
                                        child: Icon(Icons.message),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Message is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Schedule Time Picker
                                  InkWell(
                                    onTap: _pickDateTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              color: Colors.grey),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _scheduledTime == null
                                                  ? 'Schedule for later (Optional)'
                                                  : 'Scheduled: ${_scheduledTime.toString().split('.')[0]}',
                                              style: TextStyle(
                                                color: _scheduledTime == null
                                                    ? Colors.grey.shade600
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                          if (_scheduledTime != null)
                                            IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () => setState(() => _scheduledTime = null),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Send Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _sending ? null : _sendNotification,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _sending
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Send Notification',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Recent Notifications
                        const Text(
                          '📋 Recent Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_sentNotifications.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No notifications sent yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          )
                        else
                          ..._sentNotifications.map((notif) {
                            final isSent = notif['Notification_send'] == true;
                            final deliveredAt = notif['delivered_at'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSent
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                                  child: Icon(
                                    isSent
                                        ? Icons.schedule_send
                                        : Icons.check_circle,
                                    color: isSent ? Colors.orange : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  notif['title'] ?? 'Untitled',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notif['message'] ?? ''),
                                    const SizedBox(height: 4),
                                    Text(
                                      deliveredAt != null
                                          ? '✅ Delivered'
                                          : '⏳ Pending',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: deliveredAt != null
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: !isSent
                                    ? IconButton(
                                        icon: const Icon(Icons.refresh),
                                        onPressed: () =>
                                            _resendNotification(notif['id']),
                                        tooltip: 'Resend',
                                      )
                                    : null,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSentNotifications,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}