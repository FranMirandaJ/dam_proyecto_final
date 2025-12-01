import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManagePeriodoModal extends StatefulWidget {
  final String? periodoId;
  final String? currentName;
  final DateTime? currentInicio;
  final DateTime? currentFin;

  const ManagePeriodoModal({
    Key? key,
    this.periodoId,
    this.currentName,
    this.currentInicio,
    this.currentFin,
  }) : super(key: key);

  @override
  State<ManagePeriodoModal> createState() => _ManagePeriodoModalState();
}

class _ManagePeriodoModalState extends State<ManagePeriodoModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName ?? '');
    _fechaInicio = widget.currentInicio;
    _fechaFin = widget.currentFin;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_fechaInicio ?? DateTime.now())
          : (_fechaFin ?? DateTime.now().add(const Duration(days: 90))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaInicio == null || _fechaFin == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Define ambas fechas")));
      return;
    }

    if (_fechaFin!.isBefore(_fechaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La fecha fin debe ser posterior al inicio"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'periodo': _nameController.text.trim(),
        // Nombre del periodo (Ej: ENE-JUN 2025)
        'inicio': Timestamp.fromDate(_fechaInicio!),
        'fin': Timestamp.fromDate(_fechaFin!),
      };

      if (widget.periodoId == null) {
        // CREAR
        await FirebaseFirestore.instance.collection('periodos').add(data);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Periodo creado"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // EDITAR
        await FirebaseFirestore.instance
            .collection('periodos')
            .doc(widget.periodoId)
            .update(data);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Periodo actualizado"),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('dd/MM/yyyy');

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
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  widget.periodoId == null
                      ? "Nuevo Periodo Escolar"
                      : "Editar Periodo",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
                const SizedBox(height: 20),

                // NOMBRE
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Nombre (Ej: ENE-JUN 2025)",
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 16),

                // FECHAS ROW
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: "Fecha Inicio",
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _fechaInicio != null
                                ? dateFormat.format(_fechaInicio!)
                                : "Seleccionar",
                            style: TextStyle(
                              color: _fechaInicio != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: "Fecha Fin",
                            prefixIcon: const Icon(Icons.event),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _fechaFin != null
                                ? dateFormat.format(_fechaFin!)
                                : "Seleccionar",
                            style: TextStyle(
                              color: _fechaFin != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.periodoId == null
                                ? "CREAR PERIODO"
                                : "GUARDAR CAMBIOS",
                            style: const TextStyle(
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
}
