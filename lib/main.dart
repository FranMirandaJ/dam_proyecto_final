import 'package:flutter/material.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: MaterialApp(
        home: LoginRegister(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
