import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_final/providers/user_provider.dart';

class Mapa extends StatefulWidget {
  const Mapa({super.key});

  @override
  State<Mapa> createState() => _MapaState();
}

class _MapaState extends State<Mapa> {
  @override
  Widget build(BuildContext context) {
    // Obtenemos la información del usuario desde el provider
    final user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: Text("Mapa")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("¡Bienvenido de nuevo!"),
            // Si el usuario no es nulo, muestra su nombre, si no, un texto vacío
            Text(
              user?.name ?? 'Usuario',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('UID: ${user?.uid ?? ''}'),
            Text('Email: ${user?.email ?? ''}'),
            Text('Rol: ${user?.role ?? ''}'),
          ],
        ),
      ),
    );
  }
}
