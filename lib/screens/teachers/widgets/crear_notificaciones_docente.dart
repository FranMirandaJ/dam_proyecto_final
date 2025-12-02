import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrearNotificacionScreen extends StatefulWidget {

  final String claseIdSeleccionada;

  const CrearNotificacionScreen({Key? key, required this.claseIdSeleccionada}) : super(key: key);

  @override
  _CrearNotificacionScreenState createState() => _CrearNotificacionScreenState();
}

class _CrearNotificacionScreenState extends State<CrearNotificacionScreen> {

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _cuerpoController = TextEditingController();

  bool _estaEnviando = false;

  Future<void> _enviarNotificacion() async {
    if (_tituloController.text.isEmpty || _cuerpoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Por favor llena todos los campos")));
      return;
    }

    setState(() {
      _estaEnviando = true;
    });

    try {
      User? usuarioActual = FirebaseAuth.instance.currentUser;

      if (usuarioActual != null) {
        DocumentReference refClase = FirebaseFirestore.instance.collection('clase').doc(widget.claseIdSeleccionada);
        DocumentReference refDocente = FirebaseFirestore.instance.collection('usuario').doc(usuarioActual.uid);

        await FirebaseFirestore.instance.collection('notificaciones').add({
          'titulo': _tituloController.text.trim(),
          'cuerpo': _cuerpoController.text.trim(),
          'fecha': FieldValue.serverTimestamp(), // Usa la hora del servidor
          'claseId': refClase, // Se guarda como Reference
          'docenteId': refDocente, // Se guarda como Reference
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Notificación enviada con éxito")));
        Navigator.pop(context); // Regresar a la pantalla anterior
      }
    } catch (e) {
      print("Error al enviar: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al enviar")));
    } finally {
      setState(() {
        _estaEnviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nueva Notificación")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _tituloController,
              decoration: InputDecoration(
                labelText: 'Título',
                hintText: 'Ej: Examen Mañana',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            SizedBox(height: 16),

            TextField(
              controller: _cuerpoController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Escribe aquí el contenido de la notificación...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _estaEnviando ? null : _enviarNotificacion,
                child: _estaEnviando
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("ENVIAR NOTIFICACIÓN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}