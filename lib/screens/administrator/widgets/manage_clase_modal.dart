import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageClaseModal extends StatefulWidget {
  final String? claseId;
  final Map<String, dynamic>? data;

  const ManageClaseModal({Key? key, this.claseId, this.data}) : super(key: key);

  @override
  State<ManageClaseModal> createState() => _ManageClaseModalState();
}

class _ManageClaseModalState extends State<ManageClaseModal> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controladores de Texto
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  // Variables para selección (Referencias)
  String? _selectedProfesorId;
  String? _selectedAulaId;
  String? _selectedPeriodoId;

  // Horarios
  TimeOfDay _horaInicio = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 8, minute: 0);

  // Días (1 = Lunes, ..., 6 = Sábado)
  List<int> _diasSeleccionados = [];

  // Alumnos
  List<String> _alumnosSeleccionadosIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _cargarDatosExistentes();
    }
  }

  void _cargarDatosExistentes() {
    final d = widget.data!;
    _nombreController.text = d['nombre'] ?? '';
    _grupoController.text = d['grupo'] ?? '';

    if (d['hora'] != null) _horaInicio = _parseTime(d['hora']);
    if (d['horaFin'] != null) _horaFin = _parseTime(d['horaFin']);

    if (d['profesor'] is DocumentReference)
      _selectedProfesorId = (d['profesor'] as DocumentReference).id;
    if (d['aula'] is DocumentReference)
      _selectedAulaId = (d['aula'] as DocumentReference).id;
    if (d['periodo'] is DocumentReference)
      _selectedPeriodoId = (d['periodo'] as DocumentReference).id;

    if (d['diasClase'] != null) {
      _diasSeleccionados = List<int>.from(d['diasClase']);
    }

    if (d['alumnos'] != null) {
      _alumnosSeleccionadosIds = (d['alumnos'] as List)
          .map((ref) => (ref as DocumentReference).id)
          .toList();
    }
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(":");
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Future<void> _selectTime(bool isInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isInicio ? _horaInicio : _horaFin,
    );
    if (picked != null) {
      setState(() {
        if (isInicio)
          _horaInicio = picked;
        else
          _horaFin = picked;
      });
    }
  }

  void _mostrarSelectorAlumnos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparente para ver bordes
      builder: (ctx) => _AlumnosSelector(
        seleccionadosIniciales: _alumnosSeleccionadosIds,
        onConfirm: (nuevosSeleccionados) {
          setState(() {
            _alumnosSeleccionadosIds = nuevosSeleccionados;
          });
        },
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfesorId == null ||
        _selectedAulaId == null ||
        _selectedPeriodoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona Profesor, Aula y Periodo")),
      );
      return;
    }
    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un día")),
      );
      return;
    }

    // Validación básica de horas
    final double inicio = _horaInicio.hour + _horaInicio.minute / 60.0;
    final double fin = _horaFin.hour + _horaFin.minute / 60.0;
    if (fin <= inicio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La hora de fin debe ser después del inicio"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;

      final data = {
        'nombre': _nombreController.text.trim(),
        'grupo': _grupoController.text.trim(),
        'hora': _formatTime(_horaInicio),
        'horaFin': _formatTime(_horaFin),
        'profesor': db.collection('usuario').doc(_selectedProfesorId),
        'aula': db.collection('aulas').doc(_selectedAulaId),
        'periodo': db.collection('periodos').doc(_selectedPeriodoId),
        'diasClase': _diasSeleccionados,
        'alumnos': _alumnosSeleccionadosIds
            .map((id) => db.collection('usuario').doc(id))
            .toList(),
        if (widget.claseId == null) 'totalClasesDictadas': 0,
      };

      if (widget.claseId == null) {
        await db.collection('clase').add(data);
      } else {
        await db.collection('clase').doc(widget.claseId).update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Clase guardada"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  widget.claseId == null ? "Nueva Clase" : "Editar Clase",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),

                const SizedBox(height: 20),

                // 1. NOMBRE Y GRUPO (Sin iconos)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nombreController,
                        decoration: _inputDeco("Materia"),
                        validator: (v) => v!.isEmpty ? "Requerido" : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _grupoController,
                        decoration: _inputDeco("Grupo"),
                        validator: (v) => v!.isEmpty ? "Requerido" : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. SELECTORES (Sin iconos, Docente sin email)
                _buildDropdownStream(
                  "Docente",
                  'usuario',
                  _selectedProfesorId,
                  (val) => setState(() => _selectedProfesorId = val),
                  filtroRol: 'docente',
                ),
                const SizedBox(height: 12),

                _buildDropdownStream(
                  "Aula",
                  'aulas',
                  _selectedAulaId,
                  (val) => setState(() => _selectedAulaId = val),
                  campoNombre: 'aula',
                ),
                const SizedBox(height: 12),

                _buildDropdownStream(
                  "Periodo",
                  'periodos',
                  _selectedPeriodoId,
                  (val) => setState(() => _selectedPeriodoId = val),
                  campoNombre: 'periodo',
                ),

                const SizedBox(height: 20),

                // 3. HORARIOS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selectTime(true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Inicio: ${_formatTime(_horaInicio)}",
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selectTime(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Fin: ${_formatTime(_horaFin)}",
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 4. DÍAS DE LA SEMANA (Incluye Sábado)
                const Text(
                  "Días de clase:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(6, (index) {
                    // Aumentado a 6 para incluir Sábado
                    int dia = index + 1; // 1=Lunes ... 6=Sábado
                    bool isSelected = _diasSeleccionados.contains(dia);
                    final diasNombres = ["L", "M", "M", "J", "V", "S"];

                    return ChoiceChip(
                      label: Text(
                        diasNombres[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF3F51B5),
                      backgroundColor: Colors.grey[100],
                      onSelected: (selected) {
                        setState(() {
                          if (selected)
                            _diasSeleccionados.add(dia);
                          else
                            _diasSeleccionados.remove(dia);
                          _diasSeleccionados.sort();
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // 5. ALUMNOS
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "${_alumnosSeleccionadosIds.length} Alumnos seleccionados",
                  ),
                  subtitle: const Text(
                    "Toca para añadir/quitar alumnos",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _mostrarSelectorAlumnos,
                ),

                const SizedBox(height: 24),

                // BOTÓN GUARDAR
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "GUARDAR CLASE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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

  // Helper limpio para Inputs (Sin iconos)
  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ), // Padding más cómodo
    );
  }

  // Helper para Dropdowns conectados a Firebase (Solo nombre, sin iconos)
  Widget _buildDropdownStream(
    String label,
    String collection,
    String? currentValue,
    Function(String?) onChanged, {
    String? filtroRol,
    String campoNombre = 'nombre',
  }) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (filtroRol != null) query = query.where('rol', isEqualTo: filtroRol);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SizedBox(
            height: 55,
            child: Center(child: LinearProgressIndicator()),
          );

        List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // CORRECCIÓN: Solo el nombre, sin email ni paréntesis extra
          String texto = data[campoNombre] ?? '---';

          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(texto, overflow: TextOverflow.ellipsis),
          );
        }).toList();

        return DropdownButtonFormField<String>(
          value: currentValue,
          items: items,
          onChanged: onChanged,
          decoration: _inputDeco(label),
          // Usa la decoración sin iconos
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down,
          ), // Flecha discreta a la derecha
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET INTERNO: SELECTOR DE ALUMNOS (SE MANTIENE IGUAL DE FUNCIONAL)
// ----------------------------------------------------------------------
class _AlumnosSelector extends StatefulWidget {
  final List<String> seleccionadosIniciales;
  final Function(List<String>) onConfirm;

  const _AlumnosSelector({
    Key? key,
    required this.seleccionadosIniciales,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<_AlumnosSelector> createState() => _AlumnosSelectorState();
}

class _AlumnosSelectorState extends State<_AlumnosSelector> {
  List<String> _tempSeleccionados = [];
  String _busqueda = "";

  @override
  void initState() {
    super.initState();
    _tempSeleccionados = List.from(widget.seleccionadosIniciales);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Seleccionar Alumnos",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: "Buscar por nombre...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _busqueda = val.toLowerCase()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuario')
                  .where('rol', isEqualTo: 'alumno')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nombre.contains(_busqueda);
                }).toList();

                if (docs.isEmpty)
                  return const Center(
                    child: Text("No hay alumnos que coincidan"),
                  );

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _tempSeleccionados.contains(doc.id);

                    return CheckboxListTile(
                      title: Text(data['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(
                        data['email'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF3F51B5),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _tempSeleccionados.add(doc.id);
                          } else {
                            _tempSeleccionados.remove(doc.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_tempSeleccionados);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "CONFIRMAR (${_tempSeleccionados.length})",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
