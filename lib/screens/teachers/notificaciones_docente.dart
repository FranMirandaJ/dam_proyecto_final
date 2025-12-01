import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl: ^0.18.0

class TeacherNotificationScreen extends StatefulWidget {
  const TeacherNotificationScreen({Key? key}) : super(key: key);

  @override
  State<TeacherNotificationScreen> createState() => _TeacherNotificationScreenState();
}

class _TeacherNotificationScreenState extends State<TeacherNotificationScreen> {
  // Colores del tema
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF1F222E);
  final Color textGrey = const Color(0xFF757575);
  final Color bgLight = const Color(0xFFF5F6FA);

  // Controladores
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _cuerpoController = TextEditingController();

  // Lógica de selección
  bool isAllSelected = false;
  List<String> selectedGroupIds = [];
  bool _isSending = false;

  // NUEVO: Diccionario para guardar ID -> "Nombre Materia"
  Map<String, String> nombresClases = {};

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Cargamos los nombres de las materias al iniciar
    _cargarNombresClases();
  }

  // NUEVO: Función para obtener los nombres reales de las clases del profe
  void _cargarNombresClases() async {
    if (currentUser == null) return;

    try {
      // Referencia del profe actual
      DocumentReference refProfe = FirebaseFirestore.instance
          .collection('usuario')
          .doc(currentUser!.uid);

      // Buscamos las clases donde él es el profesor
      // (Ajusta 'profesor' o 'docenteId' según como se llame EXACTAMENTE en tu BD 'clase')
      // Según tu imagen anterior, el campo en la colección 'clase' se llama 'profesor' o 'docenteId'
      // Voy a asumir que usas 'profesor' o 'docenteId'. Si no carga, revisa ese nombre.
      final snapshot = await FirebaseFirestore.instance
          .collection('clase')
          .where('profesor', isEqualTo: refProfe)
          .get();

      Map<String, String> tempMap = {};

      for (var doc in snapshot.docs) {
        String nombre = doc['nombre'] ?? 'Materia';
        String grupo = doc['grupo'] ?? ''; // Opcional: traer el grupo también

        // Guardamos: "Sistemas Programables 5A"
        tempMap[doc.id] = "$nombre $grupo".trim();
      }

      if (mounted) {
        setState(() {
          nombresClases = tempMap;
        });
      }
    } catch (e) {
      print("Error cargando nombres de clases: $e");
    }
  }

  // Método para enviar
  Future<void> _enviarNotificacion(List<QueryDocumentSnapshot> allGroups) async {
    if (_tituloController.text.isEmpty || _cuerpoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe un título y un mensaje")));
      return;
    }

    if (!isAllSelected && selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona al menos un grupo")));
      return;
    }

    setState(() => _isSending = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection('notificaciones');

      List<String> targetIds = [];
      if (isAllSelected) {
        targetIds = allGroups.map((doc) => doc.id).toList();
      } else {
        targetIds = selectedGroupIds;
      }

      DocumentReference docRef = FirebaseFirestore.instance.collection('usuario').doc(currentUser!.uid);

      for (var claseId in targetIds) {
        var newDocRef = collectionRef.doc();
        DocumentReference claseRef = FirebaseFirestore.instance.collection('clase').doc(claseId);

        batch.set(newDocRef, {
          'titulo': _tituloController.text.trim(),
          'cuerpo': _cuerpoController.text.trim(),
          'fecha': FieldValue.serverTimestamp(),
          'claseId': claseRef,
          'docenteId': docRef,
        });
      }

      await batch.commit();

      _tituloController.clear();
      _cuerpoController.clear();
      setState(() {
        selectedGroupIds.clear();
        isAllSelected = false;
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notificaciones enviadas con éxito")));

    } catch (e) {
      print(e);
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Notificaciones Docente", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN 1: FORMULARIO ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Nueva Notificación", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  Text("Seleccionar grupo", style: TextStyle(color: textGrey, fontSize: 14)),
                  const SizedBox(height: 10),

                  // Chips de Grupos
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('clase')
                          .where('profesor', isEqualTo: FirebaseFirestore.instance.collection('usuario').doc(currentUser?.uid))
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        final docs = snapshot.data!.docs;

                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            FilterChip(
                              label: const Text("Todos"),
                              selected: isAllSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  isAllSelected = selected;
                                  if (selected) selectedGroupIds.clear();
                                });
                              },
                              backgroundColor: bgLight,
                              selectedColor: primaryGreen.withOpacity(0.15),
                              labelStyle: TextStyle(color: isAllSelected ? primaryGreen : textGrey, fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal),
                              checkmarkColor: primaryGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isAllSelected ? primaryGreen : Colors.transparent)),
                            ),
                            ...docs.map((doc) {
                              String nombreGrupo = (doc.data() as Map)['nombre'] ?? 'Sin nombre';
                              String grupoLetra = (doc.data() as Map)['grupo'] ?? '';
                              String labelCompleto = "$nombreGrupo $grupoLetra".trim(); // Ej: Sistemas 5A

                              String idGrupo = doc.id;
                              bool isSelected = isAllSelected ? true : selectedGroupIds.contains(idGrupo);
                              bool isDisabled = isAllSelected;

                              return FilterChip(
                                label: Text(labelCompleto),
                                selected: isSelected,
                                onSelected: isDisabled ? null : (bool selected) {
                                  setState(() {
                                    if (selected) selectedGroupIds.add(idGrupo);
                                    else selectedGroupIds.remove(idGrupo);
                                  });
                                },
                                backgroundColor: bgLight,
                                disabledColor: Colors.grey.shade100,
                                selectedColor: primaryGreen.withOpacity(0.15),
                                labelStyle: TextStyle(color: isSelected ? primaryGreen : (isDisabled ? Colors.grey.shade400 : textGrey), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                checkmarkColor: primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected && !isDisabled ? primaryGreen : Colors.transparent)),
                              );
                            }).toList(),
                          ],
                        );
                      }
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: _tituloController,
                    decoration: InputDecoration(
                      hintText: "Título (Ej: Aviso Importante)",
                      hintStyle: TextStyle(color: textGrey.withOpacity(0.5)),
                      filled: true, fillColor: bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cuerpoController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Escribe tu mensaje aquí...",
                      hintStyle: TextStyle(color: textGrey.withOpacity(0.5)),
                      filled: true, fillColor: bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('clase').where('profesor', isEqualTo: FirebaseFirestore.instance.collection('usuario').doc(currentUser?.uid)).snapshots(),
                      builder: (context, snapshot) {
                        return SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton.icon(
                            onPressed: (_isSending || !snapshot.hasData) ? null : () => _enviarNotificacion(snapshot.data!.docs),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            icon: _isSending ? Container(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 20),
                            label: Text(_isSending ? "ENVIANDO..." : "Enviar Notificación", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SECCIÓN 2: HISTORIAL (MODIFICADA) ---
            Text("Enviadas Recientemente", style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notificaciones')
                    .where('docenteId', isEqualTo: FirebaseFirestore.instance.collection('usuario').doc(currentUser?.uid))
                    .orderBy('fecha', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return Text("No has enviado notificaciones aún.", style: TextStyle(color: textGrey));

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      String fechaStr = "Reciente";
                      if (data['fecha'] != null) {
                        Timestamp t = data['fecha'];
                        fechaStr = DateFormat('dd MMM, HH:mm').format(t.toDate());
                      }

                      // --- AQUÍ OBTENEMOS EL NOMBRE REAL ---
                      String nombreMateria = "Cargando...";
                      if (data['claseId'] != null && data['claseId'] is DocumentReference) {
                        String idClase = (data['claseId'] as DocumentReference).id;
                        // Buscamos en nuestro diccionario
                        nombreMateria = nombresClases[idClase] ?? "Grupo desconocido";
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['titulo'] != null)
                              Text(data['titulo'], style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                            if (data['titulo'] != null) const SizedBox(height: 4),

                            Text(data['cuerpo'] ?? '', style: TextStyle(color: textDark.withOpacity(0.8), fontSize: 14, height: 1.4)),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // --- ESTA ES LA PARTE QUE CAMBIAMOS ---
                                Row(
                                  children: [
                                    Icon(Icons.people_outline, size: 16, color: textGrey),
                                    const SizedBox(width: 4),
                                    // Antes decía "Ver grupo", ahora muestra el nombre real
                                    Text(
                                      nombreMateria,
                                      style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: textGrey),
                                    const SizedBox(width: 4),
                                    Text(fechaStr, style: TextStyle(color: textGrey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  );
                }
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}