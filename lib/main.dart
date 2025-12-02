import 'package:flutter/material.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.notification!.title ?? 'Nueva Notificación',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(message.notification!.body ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: LoginRegister(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}