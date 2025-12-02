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

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  String? _selectedProfesorId;
  String? _selectedAulaId;
  String? _selectedPeriodoId;

  TimeOfDay _horaInicio = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 8, minute: 0);

  List<int> _diasSeleccionados = [];
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

  int _timeToMinutes(TimeOfDay t) {
    return t.hour * 60 + t.minute;
  }

  int _stringTimeToMinutes(String timeString) {
    try {
      final parts = timeString.split(":");
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  // --- NUEVA FUNCIÓN DE VALIDACIÓN DE CRUCES ---
  Future<String?> _validarCruceDeHorarioYAlumnos() async {
    if (_diasSeleccionados.isEmpty || _alumnosSeleccionadosIds.isEmpty) return null;

    final newStart = _timeToMinutes(_horaInicio);
    final newEnd = _timeToMinutes(_horaFin);

    // 1. Buscamos TODAS las clases que ocurran en los días seleccionados
    // (Firestore permite 'array-contains-any' hasta 10 valores, días son máx 6, así que funciona)
    final query = await FirebaseFirestore.instance
        .collection('clase')
        .where('diasClase', arrayContainsAny: _diasSeleccionados)
        .get();

    for (var doc in query.docs) {
      // Si estamos editando, nos saltamos a nosotros mismos
      if (widget.claseId != null && doc.id == widget.claseId) continue;

      final data = doc.data();

      // 2. Verificamos si hay traslape de HORAS
      final String existingStartStr = data['hora'] ?? "00:00";
      final String existingEndStr = data['horaFin'] ?? "00:00"; // Asegúrate de que tus clases viejas tengan horaFin o esto fallará (usará 00:00)

      // Fallback si horaFin no existe en registros viejos: +1 hora
      int existingStart = _stringTimeToMinutes(existingStartStr);
      int existingEnd = _stringTimeToMinutes(existingEndStr);
      if (existingEnd == 0) existingEnd = existingStart + 60;

      // Lógica de Cruce: (InicioA < FinB) Y (InicioB < FinA)
      bool seCruzanHoras = (newStart < existingEnd) && (existingStart < newEnd);

      if (seCruzanHoras) {
        // 3. Verificamos si hay traslape de ALUMNOS
        final List<dynamic> alumnosRef = data['alumnos'] ?? [];
        final List<String> alumnosIdsClase = alumnosRef.map((ref) => (ref as DocumentReference).id).toList();

        // Intersección de conjuntos
        final Set<String> interseccion = _alumnosSeleccionadosIds.toSet().intersection(alumnosIdsClase.toSet());

        if (interseccion.isNotEmpty) {
          String nombreMateria = data['nombre'] ?? 'Materia desconocida';
          String grupoMateria = data['grupo'] ?? '';
          return "Conflicto con '$nombreMateria $grupoMateria'.\n\nHay ${interseccion.length} alumno(s) que ya tienen clase en ese horario.";
        }
      }
    }
    return null; // Todo limpio
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
      backgroundColor: Colors.transparent,
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
    if (_selectedProfesorId == null || _selectedAulaId == null || _selectedPeriodoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona Profesor, Aula y Periodo")));
      return;
    }
    if (_diasSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona al menos un día")));
      return;
    }

    // Validación básica de horas
    final double inicio = _horaInicio.hour + _horaInicio.minute / 60.0;
    final double fin = _horaFin.hour + _horaFin.minute / 60.0;
    if (fin <= inicio) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La hora de fin debe ser después del inicio")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- VALIDACIÓN DE CRUCES DE ALUMNOS ---
      String? errorCruce = await _validarCruceDeHorarioYAlumnos();
      if (errorCruce != null) {
        // Detenemos y mostramos alerta
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(children: const [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 10), Text("Cruce de Horario")]),
              content: Text(errorCruce),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Entendido"))
              ],
            ),
          );
        }
        return;
      }

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
        'alumnos': _alumnosSeleccionadosIds.map((id) => db.collection('usuario').doc(id)).toList(),
        if (widget.claseId == null) 'totalClasesDictadas': 0,
      };

      if (widget.claseId == null) {
        await db.collection('clase').add(data);
      } else {
        await db.collection('clase').doc(widget.claseId).update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clase guardada"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ... (El resto de tu diseño de UI se mantiene idéntico)
                // Solo incluiré las partes clave para ahorrar espacio,
                // pero en tu archivo final deja todo el build() como estaba.
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                Text(widget.claseId == null ? "Nueva Clase" : "Editar Clase", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))),

                const SizedBox(height: 20),

                Row(children: [Expanded(flex: 2, child: TextFormField(controller: _nombreController, decoration: _inputDeco("Materia"), validator: (v) => v!.isEmpty ? "Requerido" : null)), const SizedBox(width: 12), Expanded(flex: 1, child: TextFormField(controller: _grupoController, decoration: _inputDeco("Grupo"), validator: (v) => v!.isEmpty ? "Requerido" : null))]),

                const SizedBox(height: 16),

                _buildDropdownStream("Docente", 'usuario', _selectedProfesorId, (val) => setState(() => _selectedProfesorId = val), filtroRol: 'docente'),
                const SizedBox(height: 12),
                _buildDropdownStream("Aula", 'aulas', _selectedAulaId, (val) => setState(() => _selectedAulaId = val), campoNombre: 'aula'),
                const SizedBox(height: 12),
                _buildDropdownStream("Periodo", 'periodos', _selectedPeriodoId, (val) => setState(() => _selectedPeriodoId = val), campoNombre: 'periodo'),

                const SizedBox(height: 20),

                Row(children: [Expanded(child: OutlinedButton(onPressed: () => _selectTime(true), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text("Inicio: ${_formatTime(_horaInicio)}", style: const TextStyle(color: Colors.black87)))), const SizedBox(width: 12), Expanded(child: OutlinedButton(onPressed: () => _selectTime(false), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text("Fin: ${_formatTime(_horaFin)}", style: const TextStyle(color: Colors.black87))))]),

                const SizedBox(height: 20),

                const Text("Días de clase:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(6, (index) {
                    int dia = index + 1;
                    bool isSelected = _diasSeleccionados.contains(dia);
                    final diasNombres = ["L", "M", "M", "J", "V", "S"];
                    return ChoiceChip(
                      label: Text(diasNombres[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF3F51B5),
                      backgroundColor: Colors.grey[100],
                      onSelected: (selected) {
                        setState(() {
                          if (selected) _diasSeleccionados.add(dia);
                          else _diasSeleccionados.remove(dia);
                          _diasSeleccionados.sort();
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 20),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${_alumnosSeleccionadosIds.length} Alumnos seleccionados"),
                  subtitle: const Text("Toca para añadir/quitar alumnos", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _mostrarSelectorAlumnos,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("GUARDAR CLASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ... (Helpers _inputDeco y _buildDropdownStream se mantienen igual)
  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildDropdownStream(String label, String collection, String? currentValue, Function(String?) onChanged, {String? filtroRol, String campoNombre = 'nombre'}) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (filtroRol != null) query = query.where('rol', isEqualTo: filtroRol);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 55, child: Center(child: LinearProgressIndicator()));

        List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String texto = data[campoNombre] ?? '---';
          return DropdownMenuItem<String>(value: doc.id, child: Text(texto, overflow: TextOverflow.ellipsis));
        }).toList();

        return DropdownButtonFormField<String>(
          value: currentValue,
          items: items,
          onChanged: onChanged,
          decoration: _inputDeco(label),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
        );
      },
    );
  }
}

// ... (Clase _AlumnosSelector se mantiene igual)
class _AlumnosSelector extends StatefulWidget {
  final List<String> seleccionadosIniciales;
  final Function(List<String>) onConfirm;

  const _AlumnosSelector({Key? key, required this.seleccionadosIniciales, required this.onConfirm}) : super(key: key);

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
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Seleccionar Alumnos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: "Buscar por nombre...", prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _busqueda = val.toLowerCase()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuario').where('rol', isEqualTo: 'alumno').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(_busqueda);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("No hay alumnos que coincidan"));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _tempSeleccionados.contains(doc.id);

                    return CheckboxListTile(
                      title: Text(data['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(data['email'] ?? '', style: const TextStyle(fontSize: 12)),
                      value: isSelected,
                      activeColor: const Color(0xFF3F51B5),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) _tempSeleccionados.add(doc.id);
                          else _tempSeleccionados.remove(doc.id);
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () { widget.onConfirm(_tempSeleccionados); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text("CONFIRMAR (${_tempSeleccionados.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}