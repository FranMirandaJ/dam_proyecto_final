import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proyecto_final/services/auth.dart';
import 'package:proyecto_final/screens/students/home_alumno.dart';
import 'package:proyecto_final/screens/teachers/home_docente.dart';

class LoginRegister extends StatefulWidget {
  const LoginRegister({super.key});

  @override
  State<LoginRegister> createState() => _LoginRegisterState();
}

class _LoginRegisterState extends State<LoginRegister> {
  final userController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final Auth _auth = Auth();

  bool _isLogin = true;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  void handlerSubmit() async {
    // Clear previous error messages
    setState(() {
      _errorMessage = null;
    });

    // Hide keyboard
    FocusScope.of(context).unfocus();

    try {
      if (_isLogin) {
        Map<String, dynamic> userData = await _auth.signInWithEmailAndPassword(
          email: userController.text,
          password: passwordController.text,
        );

        // ============= DATOS DEL USUARIO LOGEADO ==============
        String rol = userData['rol'];
        String nombre = userData['nombre'];
        String email = userData['email'];
        String uid = userData['uid'];
        // =======================================================

        if (rol == 'alumno') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
          );
          print("rol de alumno");
        } else if (rol == 'docente') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TeacherHomeScreen()),
          );
          print("rol de docente");
        } else {
          print("rol de admin");
        }

      } else {
        await _auth.createUserWithEmailAndPassword(
          email: userController.text,
          password: passwordController.text,
          fullName: fullNameController.text,
        );

        // Clear fields
        fullNameController.clear();
        userController.clear();
        passwordController.clear();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "¡Cuenta creada con éxito! Por favor, inicia sesión.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Switch to login form
        setState(() {
          _isLogin = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF2C69F0), const Color(0xff49a09d)],
            stops: const [0, 1],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            Image.asset(
              "assets/qr_icon.png",
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "CheckTec",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "¡Bienvenido de nuevo!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 30),
                    if (!_isLogin) ...[
                      const Text(
                        "Nombre completo",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        controller: fullNameController,
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      "Correo electrónico",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      controller: userController,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Contraseña",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      controller: passwordController,
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          handlerSubmit();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2C69F0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          _isLogin ? "Iniciar sesión" : "Registrarse",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? "¿No tienes una cuenta?"
                              : "¿Ya tienes una cuenta?",
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                          child: Text(
                            _isLogin ? "Regístrate" : "Inicia sesión",
                            style: const TextStyle(
                              color: Color(0xFF2C69F0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
