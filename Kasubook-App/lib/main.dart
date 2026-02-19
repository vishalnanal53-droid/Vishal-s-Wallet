// ─── main.dart ───────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_service.dart';
import 'LoginPage.dart';
import 'DashboardPage.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(
            apiKey: 'AIzaSyDvSwVUFKiQOUJNEqFuHp4O_o2mthRdCGM',
            authDomain: 'kasubook.firebaseapp.com',
            projectId: 'kasubook',
            storageBucket: 'kasubook.firebasestorage.app',
            messagingSenderId: '654865930698',
            appId: '1:654865930698:web:38f4cf7b65c3f7f56fd733',
            measurementId: 'G-G9HXP92JSD',
          )
        : null, // Android reads from google-services.json automatically
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const KasuBookApp());
}

class KasuBookApp extends StatefulWidget {
  const KasuBookApp({super.key});

  @override
  State<KasuBookApp> createState() => _KasuBookAppState();
}

class _KasuBookAppState extends State<KasuBookApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KasuBook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1B2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF242535),
        ),
      ),
      home: StreamBuilder(
        stream: FirebaseService().authStateStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: const Color(0xFF1A1B2E),
              body: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const DashboardPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1B2E), Color(0xFF16172A), Color(0xFF1E1040)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7C3AED).withAlpha(100), blurRadius: 30, offset: const Offset(0, 12)),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('KasuBook', style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 0.5,
            )),
            const SizedBox(height: 6),
            const Text('Your Personal Money Manager', style: TextStyle(color: Color(0xFFA0A3BD), fontSize: 14)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFF7C3AED),
                strokeWidth: 3,
              ), 
            ),
          ],
        ),
      ),
    );
  }
}