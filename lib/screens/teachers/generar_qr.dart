import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherGenerateQRScreen extends StatefulWidget {
  final String claseId;
  final String nombreClase;
  final String nombreAula;
  final int cantidadAlumnos;

  const TeacherGenerateQRScreen({
    Key? key,
    required this.claseId,
    required this.nombreClase,
    required this.nombreAula,
    required this.cantidadAlumnos,
  }) : super(key: key);

  @override
  State<TeacherGenerateQRScreen> createState() => _TeacherGenerateQRScreenState();
}

class _TeacherGenerateQRScreenState extends State<TeacherGenerateQRScreen> {
  String? qrData;
  bool isGenerating = false;
  bool isQrActive = false;

  // Timer & Control
  Timer? _timer;
  int _remainingSeconds = 300;
  int _minutosExtraAgregados = 0; // Control local para el límite
  final int _maxMinutosExtra = 10; // Tope máximo

  @override
  void initState() {
    super.initState();
    _verificarSesionActiva();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verificarSesionActiva() async {
    setState(() => isGenerating = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('clase').doc(widget.claseId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool activo = data['qrActivo'] ?? false;

        if (activo) {
          final String tokenGuardado = data['qrActual'];
          // Recuperamos cuántos minutos extra se han añadido en esta sesión
          final int minutosExtraDB = data['minutosExtra'] ?? 0;

          final parts = tokenGuardado.split('_');
          if (parts.length > 1) {
            final int timestampGeneracion = int.parse(parts[1]);
            final int now = DateTime.now().millisecondsSinceEpoch;
            final int diferenciaSegundos = ((now - timestampGeneracion) / 1000).round();

            // FÓRMULA CORREGIDA: 5 min base + minutos extra guardados
            final int duracionTotalSeconds = 300 + (minutosExtraDB * 60);
            final int tiempoRestante = duracionTotalSeconds - diferenciaSegundos;

            if (tiempoRestante > 0) {
              setState(() {
                qrData = tokenGuardado;
                isQrActive = true;
                _remainingSeconds = tiempoRestante;
                _minutosExtraAgregados = minutosExtraDB; // Sincronizamos el límite
                _startTimer();
              });
            } else {
              _desactivarQR();
            }
          }
        }
      }
    } catch (e) {
      print("Error verificando sesión: $e");
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _desactivarQR();
      }
    });
  }

  Future<void> _desactivarQR() async {
    _timer?.cancel();
    setState(() {
      isQrActive = false;
      qrData = null;
      _remainingSeconds = 300;
      _minutosExtraAgregados = 0;
    });

    try {
      await FirebaseFirestore.instance.collection('clase').doc(widget.claseId).update({
        'qrActivo': false,
      });
    } catch (e) {
      print("Error desactivando QR: $e");
    }
  }

  Future<void> _generarNuevoQR() async {
    setState(() => isGenerating = true);

    String nuevoTokenQR = "${widget.claseId}_${DateTime.now().millisecondsSinceEpoch}";

    try {
      // 1. Consultar la clase para ver cuándo fue la última vez que se dictó
      final docRef = FirebaseFirestore.instance.collection('clase').doc(widget.claseId);
      final docSnap = await docRef.get();

      bool incrementarContador = true;

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data.containsKey('ultimaFechaClase')) {
          final Timestamp ultimaFechaTs = data['ultimaFechaClase'];
          final DateTime ultimaFecha = ultimaFechaTs.toDate();
          final DateTime ahora = DateTime.now();

          // Si la última clase registrada fue HOY, no incrementamos el contador
          if (ultimaFecha.year == ahora.year &&
              ultimaFecha.month == ahora.month &&
              ultimaFecha.day == ahora.day) {
            incrementarContador = false;
            print("📅 La clase ya se registró hoy. No se incrementará el contador.");
          }
        }
      }

      // 2. Preparar actualización
      final Map<String, dynamic> updates = {
        'qrActual': nuevoTokenQR,
        'qrActivo': true,
        'minutosExtra': 0, // Reiniciamos los minutos extra de la sesión
      };

      // Solo si es una nueva clase (otro día), incrementamos y actualizamos fecha
      if (incrementarContador) {
        updates['totalClasesDictadas'] = FieldValue.increment(1);
        updates['ultimaFechaClase'] = FieldValue.serverTimestamp();
      }

      await docRef.update(updates);

      setState(() {
        qrData = nuevoTokenQR;
        isQrActive = true;
        _remainingSeconds = 300;
        _minutosExtraAgregados = 0; // Reiniciamos localmente
        isGenerating = false;
      });

      _startTimer();

    } catch (e) {
      print("Error generando QR: $e");
      setState(() => isGenerating = false);
    }
  }

  Future<void> _anadirTiempo() async {
    if (!isQrActive) return;

    // Validación del tope (10 min)
    if (_minutosExtraAgregados >= _maxMinutosExtra) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Has alcanzado el límite máximo de tiempo extra."))
      );
      return;
    }

    setState(() {
      _remainingSeconds += 60; // Visualmente sumamos 1 min inmediato
      _minutosExtraAgregados++;
    });

    // Guardamos en Firebase para que persista si sale de la pantalla
    try {
      await FirebaseFirestore.instance.collection('clase').doc(widget.claseId).update({
        'minutosExtra': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error guardando tiempo extra: $e");
    }
  }

  String get _timerString {
    final int minutes = _remainingSeconds ~/ 60;
    final int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF00C853);
    final Color darkText = const Color(0xFF1F222E);
    final Color greyText = const Color(0xFF757575);
    final Color lightBackgroundCard = const Color(0xFFF5F6FA);

    // Calculamos si el botón de añadir debe estar habilitado
    final bool puedeAnadirMas = isQrActive && _minutosExtraAgregados < _maxMinutosExtra;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
        title: Column(
          children: [
            Text(
              "Generar QR",
              style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              widget.nombreClase,
              style: TextStyle(color: greyText, fontSize: 14),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              const Divider(),
              const SizedBox(height: 20),

              // --- TEMPORIZADOR ---
              Text(
                  isQrActive ? "Código expira en" : "Código inactivo",
                  style: TextStyle(color: greyText, fontSize: 16)
              ),
              const SizedBox(height: 8),
              Text(
                _timerString,
                style: TextStyle(
                    color: isQrActive ? primaryGreen : Colors.grey,
                    fontSize: 48,
                    fontWeight: FontWeight.bold
                ),
              ),

              // BOTÓN AÑADIR TIEMPO
              if (isQrActive)
                TextButton.icon(
                  onPressed: puedeAnadirMas ? _anadirTiempo : null, // Se deshabilita si llegó al tope
                  style: TextButton.styleFrom(
                    foregroundColor: puedeAnadirMas ? primaryGreen : Colors.grey,
                    backgroundColor: puedeAnadirMas ? primaryGreen.withOpacity(0.1) : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(
                    puedeAnadirMas
                        ? "Añadir 1 min extra"
                        : "Límite alcanzado (+${_maxMinutosExtra} min)",
                  ),
                )
              else
                const SizedBox(height: 48),

              const SizedBox(height: 30),

              // --- SECCIÓN QR ---
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: isGenerating
                    ? const SizedBox(
                    height: 200,
                    width: 200,
                    child: Center(child: CircularProgressIndicator())
                )
                    : (qrData != null && isQrActive)
                    ? Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                      foregroundColor: darkText,
                    ),
                    _buildCornerBrackets(greyText.withOpacity(0.3)),
                  ],
                )
                    : Container(
                  height: 200,
                  width: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 50, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text(
                        "Presiona Generar",
                        style: TextStyle(color: Colors.grey.shade400),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // --- TARJETA DE INFORMACIÓN ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: lightBackgroundCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(widget.nombreAula,
                              style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text("Salón", style: TextStyle(color: greyText)),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.grey.shade300),
                    Expanded(
                      child: Column(
                        children: [
                          Text("${widget.cantidadAlumnos}",
                              style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text("Estudiantes", style: TextStyle(color: greyText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- BOTÓN DE ACCIÓN PRINCIPAL ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  // Si está activo, deshabilitamos el botón (null en onPressed)
                  onPressed: isQrActive ? null : _generarNuevoQR,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300, // Color cuando está desactivado
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isQrActive ? 0 : 2,
                  ),
                  icon: Icon(isQrActive ? Icons.check : Icons.qr_code),
                  label: Text(
                    isQrActive ? "Código Activo" : "Generar Código QR",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de descargar (Solo si hay QR visible)
              if (isQrActive)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      debugPrint("Descargar imagen");
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkText,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text(
                      "Descargar QR como imagen",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerBrackets(Color color) {
    double size = 240;
    double thickness = 2;
    double length = 20;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: Container(width: length, height: thickness, color: color)),
          Positioned(top: 0, left: 0, child: Container(width: thickness, height: length, color: color)),
          Positioned(top: 0, right: 0, child: Container(width: length, height: thickness, color: color)),
          Positioned(top: 0, right: 0, child: Container(width: thickness, height: length, color: color)),
          Positioned(bottom: 0, left: 0, child: Container(width: length, height: thickness, color: color)),
          Positioned(bottom: 0, left: 0, child: Container(width: thickness, height: length, color: color)),
          Positioned(bottom: 0, right: 0, child: Container(width: length, height: thickness, color: color)),
          Positioned(bottom: 0, right: 0, child: Container(width: thickness, height: length, color: color)),
        ],
      ),
    );
  }
}