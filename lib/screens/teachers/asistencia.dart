import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:proyecto_final/services/queriesFirestore/docenteQueries.dart';
import 'package:intl/date_symbol_data_local.dart';

class AsistenciasPage extends StatefulWidget {
  @override
  _AsistenciasPageState createState() => _AsistenciasPageState();
}

class _AsistenciasPageState extends State<AsistenciasPage> {
  DateTime? selectedDate;
  String? selectedMateriaId;
  TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> clasesConPeriodo = [];
  List<Map<String, dynamic>> clasesDelDia = [];
  List<Map<String, dynamic>> listaAlumnos = [];

  bool isLoading = true;
  bool isLoadingAlumnos = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting(null, null).then((_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cargarDatosIniciales();
        });
      }
    });
  }

  Future<void> _cargarDatosIniciales() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;

    if (user == null || user.uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final resultado = await DocenteQueries.obtenerClasesConPeriodos(
        user.uid!,
      );
      if (!mounted) return;
      setState(() {
        clasesConPeriodo = resultado;
        isLoading = false;
      });
    } catch (e) {
      print("Error cargando datos: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _cargarAlumnos() async {
    if (selectedDate == null || selectedMateriaId == null) return;
    setState(() => isLoadingAlumnos = true);

    try {
      // Usamos la nueva función que te di anteriormente que cruza datos
      final resultado = await DocenteQueries.obtenerAsistenciaPorFecha(
        selectedMateriaId!,
        selectedDate!,
      );
      if (mounted) {
        setState(() {
          listaAlumnos = resultado;
          isLoadingAlumnos = false;
        });
      }
    } catch (e) {
      print("Error cargando alumnos: $e");
      if (mounted) setState(() => isLoadingAlumnos = false);
    }
  }

  /// -----------------------------------------------------------
  /// LÓGICA DE VALIDACIÓN (ACTUALIZADA: BLOQUEO FUTURO)
  /// -----------------------------------------------------------

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _esDiaSeleccionable(DateTime day) {
    final diaNormalizado = _normalizeDate(day);
    final hoyNormalizado = _normalizeDate(DateTime.now());

    // 1. NUEVA VALIDACIÓN: Si el día es posterior a hoy, NO es seleccionable
    if (diaNormalizado.isAfter(hoyNormalizado)) {
      return false;
    }

    return clasesConPeriodo.any((clase) {
      final inicio = _normalizeDate(clase['periodoInicio'] as DateTime);
      final fin = _normalizeDate(clase['periodoFin'] as DateTime);
      final diasClase = clase['diasClase'] as List<int>;

      // 2. Validar rango del periodo escolar
      bool enRango =
          !diaNormalizado.isBefore(inicio) && !diaNormalizado.isAfter(fin);

      // 3. Validar día de la semana (Lunes, Martes...)
      bool esDiaCorrecto = diasClase.contains(diaNormalizado.weekday);

      return enRango && esDiaCorrecto;
    });
  }

  DateTime? _obtenerFechaInicialValida() {
    if (clasesConPeriodo.isEmpty) return null;

    final today = _normalizeDate(DateTime.now());

    // 1. Si hoy es válido, retornar hoy.
    if (_esDiaSeleccionable(today)) return today;

    // 2. Buscar SOLO hacia atrás (ya que el futuro está prohibido)
    for (int i = 1; i <= 60; i++) {
      final prevDate = today.subtract(Duration(days: i));
      if (_esDiaSeleccionable(prevDate)) return prevDate;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final alumnosRender = listaAlumnos
        .where(
          (a) => a["nombre"].toString().toLowerCase().contains(
            searchController.text.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: Color(0xfff7f8fa),
      appBar: AppBar(
        title: Text(
          "Historial Asistencias",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Icon(Icons.arrow_back, color: Colors.black),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  color: Color(0xfff7f8fa),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Configuración de búsqueda",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),

                      // --- SELECTOR DE FECHA ---
                      GestureDetector(
                        onTap: () async {
                          final safeInitialDate = _obtenerFechaInicialValida();

                          if (safeInitialDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "No hay clases pasadas registradas.",
                                ),
                              ),
                            );
                            return;
                          }

                          // Calcular el primer día posible (inicio de semestre)
                          final firstDate = clasesConPeriodo
                              .map((c) => c['periodoInicio'] as DateTime)
                              .reduce((a, b) => a.isBefore(b) ? a : b);

                          // NUEVO: El último día posible es HOY. No dejamos pasar de hoy.
                          final lastDate = DateTime.now();

                          final date = await showDatePicker(
                            context: context,
                            initialDate: safeInitialDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                            // <--- ESTO BLOQUEA EL FUTURO EN EL CALENDARIO
                            selectableDayPredicate: _esDiaSeleccionable,
                          );

                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                              selectedMateriaId = null;
                              listaAlumnos = [];

                              // Filtrar materias del día
                              clasesDelDia = clasesConPeriodo.where((clase) {
                                final inicio = _normalizeDate(
                                  clase['periodoInicio'],
                                );
                                final fin = _normalizeDate(clase['periodoFin']);
                                final dias = clase['diasClase'] as List<int>;
                                final dateNorm = _normalizeDate(date);

                                bool enPeriodo =
                                    !dateNorm.isBefore(inicio) &&
                                    !dateNorm.isAfter(fin);
                                return enPeriodo &&
                                    dias.contains(dateNorm.weekday);
                              }).toList();
                            });
                          }
                        },
                        child: _selectorBox(
                          icon: Icons.calendar_month,
                          label: selectedDate == null
                              ? "Seleccionar fecha"
                              : DateFormat(
                                  "dd 'de' MMMM, yyyy",
                                ).format(selectedDate!),
                        ),
                      ),

                      SizedBox(height: 12),

                      // --- DROPDOWN MATERIAS ---
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: _boxDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMateriaId,
                            isExpanded: true,
                            hint: Text(
                              selectedDate == null
                                  ? "Selecciona fecha primero"
                                  : (clasesDelDia.isEmpty
                                        ? "Sin clases este día"
                                        : "Seleccionar materia"),
                            ),
                            items: clasesDelDia
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text(c['nombre']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => selectedMateriaId = val);
                              _cargarAlumnos();
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // --- BUSCADOR ---
                      if (listaAlumnos.isNotEmpty ||
                          searchController.text.isNotEmpty) ...[
                        Text(
                          "Lista de asistencia",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: _boxDecoration(),
                          child: TextField(
                            controller: searchController,
                            onChanged: (v) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "Buscar por nombre...",
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 10),
                    ],
                  ),
                ),

                // --- LISTA RESULTADOS ---
                Expanded(
                  child: isLoadingAlumnos
                      ? Center(child: CircularProgressIndicator())
                      : selectedMateriaId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 50,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Selecciona una fecha y materia\npara ver el historial",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : alumnosRender.isEmpty
                      ? Center(
                          child: Text(
                            "No se encontraron alumnos inscritos",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            top: 8,
                            left: 16,
                            right: 16,
                            bottom: 100,
                          ),
                          itemCount: alumnosRender.length,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemBuilder: (context, index) =>
                              _alumnoCard(alumnosRender[index]),
                        ),
                ),
              ],
            ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300),
  );

  Widget _selectorBox({required IconData icon, required String label}) =>
      Container(
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

  Widget _alumnoCard(Map<String, dynamic> alumno) {
    // Solo recuperamos el nombre
    final String nombre = alumno['nombre']?.toString() ?? "Sin Nombre";
    final bool asistio = alumno['asistio'] == true;

    // Manejo de la hora
    String horaTexto = "--:--";
    if (asistio && alumno['horaRegistro'] != null) {
      try {
        horaTexto = DateFormat('hh:mm a').format(alumno['horaRegistro']);
      } catch (e) {
        horaTexto = "--:--";
      }
    }

    // Colores y textos
    final Color estadoColor = asistio ? Colors.green : Colors.red;
    final Color bgIconColor = asistio
        ? Colors.green.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);
    final IconData iconEstado = asistio ? Icons.check_circle : Icons.cancel;
    final String textoEstado = asistio ? "Asistió" : "Falta";

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Avatar
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : "?",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 12),

          // 2. Nombre (Ahora es solo un Text dentro del Expanded, sin Column)
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              // Corta con '...' si es muy largo
              maxLines: 2,
            ),
          ),

          SizedBox(width: 8),

          // 3. Estado (Asistió/Falta) y Hora
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: bgIconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(iconEstado, color: estadoColor, size: 16),
                    SizedBox(width: 4),
                    Text(
                      textoEstado,
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (asistio)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    horaTexto,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
