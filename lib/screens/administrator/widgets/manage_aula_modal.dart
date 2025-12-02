import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Asegúrate de importar latlong2 para usar LatLng en el helper
import 'package:latlong2/latlong.dart';
import 'selector_aula_mapa.dart'; // Importa la pantalla nueva

class ManageAulaModal extends StatefulWidget {
  final String? aulaId;
  final String? currentName;
  final GeoPoint? currentCoords;

  const ManageAulaModal({
    Key? key,
    this.aulaId,
    this.currentName,
    this.currentCoords,
  }) : super(key: key);

  @override
  State<ManageAulaModal> createState() => _ManageAulaModalState();
}

class _ManageAulaModalState extends State<ManageAulaModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _aulaController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _aulaController = TextEditingController(text: widget.currentName ?? '');
    _latController = TextEditingController(
      text: widget.currentCoords != null
          ? widget.currentCoords!.latitude.toString()
          : '',
    );
    _lngController = TextEditingController(
      text: widget.currentCoords != null
          ? widget.currentCoords!.longitude.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _aulaController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN PARA ABRIR EL MAPA ---
  Future<void> _pickLocation() async {
    // Si ya hay coordenadas escritas, las usamos como iniciales
    LatLng? initialPos;
    double? lat = double.tryParse(_latController.text);
    double? lng = double.tryParse(_lngController.text);

    if (lat != null && lng != null) {
      initialPos = LatLng(lat, lng);
    }

    // Navegamos al selector
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialPosition: initialPos),
      ),
    );

    // Si el usuario confirmó, actualizamos los campos de texto
    if (result != null) {
      setState(() {
        _latController.text = result.latitude.toStringAsFixed(6);
        _lngController.text = result.longitude.toStringAsFixed(6);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String nombre = _aulaController.text.trim();
      final double lat = double.parse(_latController.text.trim());
      final double lng = double.parse(_lngController.text.trim());

      final Map<String, dynamic> data = {
        'aula': nombre,
        'coordenadas': GeoPoint(lat, lng),
      };

      if (widget.aulaId == null) {
        await FirebaseFirestore.instance.collection('aulas').add(data);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula creada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('aulas')
            .doc(widget.aulaId)
            .update(data);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula actualizada'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.aulaId != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? "Editar Aula" : "Nueva Aula",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
                const SizedBox(height: 20),

                // Nombre Aula
                TextFormField(
                  controller: _aulaController,
                  decoration: InputDecoration(
                    labelText: "Nombre del Aula (Ej: K-12)",
                    prefixIcon: const Icon(Icons.meeting_room_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) => val!.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 16),

                // --- BOTÓN SELECCIONAR EN MAPA ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map),
                    label: const Text("SELECCIONAR UBICACIÓN EN EL MAPA"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF3F51B5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Coordenadas (Manuales o Autocompletadas)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        // readOnly: true, // Puedes hacerlo solo lectura si quieres forzar el mapa
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Latitud",
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (val) => double.tryParse(val ?? '') == null
                            ? "Inválido"
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        // readOnly: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: "Longitud",
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (val) => double.tryParse(val ?? '') == null
                            ? "Inválido"
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox()
                        : Icon(
                      isEditing ? Icons.save : Icons.add,
                      color: Colors.white,
                    ),
                    label: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      isEditing ? "GUARDAR CAMBIOS" : "CREAR AULA",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}