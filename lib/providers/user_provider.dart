
import 'package:flutter/material.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });
}

class UserProvider with ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;

  void setUser(Map<String, dynamic> userData) {
    _user = UserModel(
      uid: userData['uid'],
      name: userData['nombre'],
      email: userData['email'],
      role: userData['rol'],
    );
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();// Notifica a los widgets que el usuario ha cambiado (a null)
  }
}
