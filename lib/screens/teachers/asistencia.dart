import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AsistenciasPage extends StatefulWidget {
  @override
  _AsistenciasPageState createState() => _AsistenciasPageState();
}

class _AsistenciasPageState extends State<AsistenciasPage> {
  DateTime? selectedDate;
  String? selectedMateria;
  TextEditingController searchController = TextEditingController();

  final materias = [
    "Programación Avanzada",
    "Base de Datos",
    "Cálculo",
    "Redes",
  ];

  final alumnosMock = [
    {"nombre": "Juan Pérez", "id": "00001", "asistio": true},
    {"nombre": "María García", "id": "00002", "asistio": true},
    {"nombre": "Carlos López", "id": "00003", "asistio": false},
    {"nombre": "Ana Torres", "id": "00004", "asistio": true},
    {"nombre": "Pedro Sánchez", "id": "00005", "asistio": false},
    {"nombre": "Lucía Méndez", "id": "00006", "asistio": true},
    {"nombre": "Jorge Ramírez", "id": "00007", "asistio": true},
    {"nombre": "Sofía Castro", "id": "00008", "asistio": false},
    {"nombre": "Miguel Ángel", "id": "00009", "asistio": true},
    {"nombre": "Valentina R.", "id": "00010", "asistio": true},
    {"nombre": "Roberto Gómez", "id": "00011", "asistio": true},
    {"nombre": "Elena White", "id": "00012", "asistio": false},
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alumnosFiltrados = alumnosMock.where((alumno) {
      final nombre = alumno["nombre"].toString().toLowerCase();
      final busqueda = searchController.text.toLowerCase();
      return nombre.contains(busqueda);
    }).toList();

    return Scaffold(
      backgroundColor: Color(0xfff7f8fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Asistencias", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: Icon(Icons.arrow_back, color: Colors.black),
      ),
      body: Column(
        children: [
          /// --- ZONA FIJA SUPERIOR ---
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: Color(0xfff7f8fa),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Configuración de clase",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),

                // Selectores
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      initialDate: DateTime.now(),
                    );
                    if (date != null) setState(() => selectedDate = date);
                  },
                  child: _selectorBox(
                    icon: Icons.calendar_month,
                    label: selectedDate == null
                        ? "Seleccionar fecha"
                        : DateFormat("dd MMM yyyy").format(selectedDate!),
                  ),
                ),
                SizedBox(height: 12),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: _boxDecoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMateria,
                      isExpanded: true,
                      hint: Text("Seleccionar materia"),
                      items: materias
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedMateria = val),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Resumen
                Row(
                  children: [
                    _buildSummaryCard("9", "Asistieron", Colors.green),
                    _buildSummaryCard("1", "Faltas", Colors.red),
                    _buildSummaryCard("90%", "Asistencia", Colors.blue),
                  ],
                ),
                SizedBox(height: 20),

                // Buscador
                Text(
                  "Lista de alumnos (${alumnosFiltrados.length})",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),

                Container(
                  decoration: _boxDecoration(),
                  child: TextField(
                    controller: searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),

          /// --- ZONA SCROLLEABLE ---
          Expanded(
            child: alumnosFiltrados.isEmpty
                ? Center(
                    child: Text(
                      "No se encontraron alumnos",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    // --- ARREGLO AQUÍ ---
                    // Agregamos 80px de padding abajo:
                    // 60px (altura del navbar) + 20px (espacio visual)
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom:
                          85, // <--- ESTO EVITA QUE LA NAV BAR TAPE EL FINAL
                    ),
                    itemCount: alumnosFiltrados.length,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemBuilder: (context, index) {
                      final alumno = alumnosFiltrados[index];
                      return _alumnoCard(
                        alumno["nombre"] as String,
                        alumno["id"] as String,
                        alumno["asistio"] as bool,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// --- WIDGETS AUXILIARES ---
  Widget _buildSummaryCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    );
  }

  Widget _selectorBox({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 16)),
          Spacer(),
          Icon(Icons.arrow_drop_down, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _alumnoCard(String nombre, String id, bool asistio) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 22,
                child: Text(
                  nombre[0],
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "ID: $id",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Icon(
            asistio ? Icons.check_circle : Icons.cancel,
            color: asistio ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }
}
