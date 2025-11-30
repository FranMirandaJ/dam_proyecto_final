import 'package:flutter/material.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
// 1. NUEVO: Importamos la librería de mensajería
import 'package:firebase_messaging/firebase_messaging.dart';

// 2. NUEVO: Definimos la Llave Global (fuera del main)
// Esto nos permite mandar mensajes a la pantalla desde aquí
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 3. NUEVO: Configuramos el "Escuchador Global"
  // Esto detecta los mensajes aunque estés en el Login o en otra pantalla
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
        // 4. NUEVO: Conectamos la llave global a tu App
        scaffoldMessengerKey: messengerKey,

        home: LoginRegister(), // Esto se mantiene intacto
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}