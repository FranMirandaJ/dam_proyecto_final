import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';

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
  bool _claseYaDictadaHoy = false;

  // Timer & Control
  Timer? _timer;
  int _remainingSeconds = 300;
  int _minutosExtraAgregados = 0;
  final int _maxMinutosExtra = 10;

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoClase();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _guardarImagenQR() async {
    if (qrData == null) return;

    setState(() => _isSaving = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 10),
          pixelRatio: 3.0
      );

      if (imageBytes != null) {
        await Gal.putImageBytes(imageBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("¡QR guardado en la galería!"),
                backgroundColor: Colors.green
            ),
          );
        }
      }
    } on GalException catch (e) {
      print("Error de Galería: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.type.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error general guardando imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo guardar la imagen"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- LÓGICA DEL QR Y TIMER ---
  Future<void> _verificarEstadoClase() async {
    setState(() => isGenerating = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('clase').doc(widget.claseId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['ultimaFechaClase'] != null) {
          final Timestamp ultimaFechaTs = data['ultimaFechaClase'];
          final DateTime ultimaFecha = ultimaFechaTs.toDate();
          final DateTime ahora = DateTime.now();

          if (ultimaFecha.year == ahora.year &&
              ultimaFecha.month == ahora.month &&
              ultimaFecha.day == ahora.day) {
            _claseYaDictadaHoy = true;
          }
        }

        final bool activo = data['qrActivo'] ?? false;
        if (activo) {
          final String tokenGuardado = data['qrActual'];
          final int minutosExtraDB = data['minutosExtra'] ?? 0;

          final parts = tokenGuardado.split('_');
          if (parts.length > 1) {
            final int timestampGeneracion = int.parse(parts[1]);
            final int now = DateTime.now().millisecondsSinceEpoch;
            final int diferenciaSegundos = ((now - timestampGeneracion) / 1000).round();

            final int duracionTotalSeconds = 300 + (minutosExtraDB * 60);
            final int tiempoRestante = duracionTotalSeconds - diferenciaSegundos;

            if (tiempoRestante > 0) {
              setState(() {
                qrData = tokenGuardado;
                isQrActive = true;
                _remainingSeconds = tiempoRestante;
                _minutosExtraAgregados = minutosExtraDB;
                _startTimer();
              });
            } else {
              _desactivarQR();
            }
          }
        }
      }
    } catch (e) {
      print("Error verificando estado: $e");
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  // --- GENERAR NUEVO CÓDIGO ---
  Future<void> _generarNuevoQR() async {
    if (_claseYaDictadaHoy && !isQrActive) {
      _mostrarAlertaYaGenerado();
      return;
    }

    setState(() => isGenerating = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('clase').doc(widget.claseId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data.containsKey('ultimaFechaClase')) {
          final Timestamp ultimaFechaTs = data['ultimaFechaClase'];
          final DateTime ultimaFecha = ultimaFechaTs.toDate();
          final DateTime ahora = DateTime.now();

          if (ultimaFecha.year == ahora.year &&
              ultimaFecha.month == ahora.month &&
              ultimaFecha.day == ahora.day) {

            setState(() {
              _claseYaDictadaHoy = true;
              isGenerating = false;
            });
            _mostrarAlertaYaGenerado();
            return;
          }
        }
      }

      String nuevoTokenQR = "${widget.claseId}_${DateTime.now().millisecondsSinceEpoch}";

      await docRef.update({
        'qrActual': nuevoTokenQR,
        'qrActivo': true,
        'totalClasesDictadas': FieldValue.increment(1),
        'ultimaFechaClase': FieldValue.serverTimestamp(),
        'minutosExtra': 0,
      });

      setState(() {
        qrData = nuevoTokenQR;
        isQrActive = true;
        _claseYaDictadaHoy = true;
        _remainingSeconds = 300;
        _minutosExtraAgregados = 0;
        isGenerating = false;
      });

      _startTimer();

    } catch (e) {
      print("Error generando QR: $e");
      setState(() => isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _mostrarAlertaYaGenerado() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Acción no permitida"),
        content: const Text("Ya generaste un código para esta clase el día de hoy.\nSolo se permite un registro por clase al día."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido"),
          )
        ],
      ),
    );
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

  Future<void> _anadirTiempo() async {
    if (!isQrActive) return;
    if (_minutosExtraAgregados >= _maxMinutosExtra) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Has alcanzado el límite máximo de tiempo extra."))
      );
      return;
    }
    setState(() {
      _remainingSeconds += 60;
      _minutosExtraAgregados++;
    });
    try {
      await FirebaseFirestore.instance.collection('clase').doc(widget.claseId).update({
        'minutosExtra': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error guardando tiempo: $e");
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

    final bool puedeAnadirMas = isQrActive && _minutosExtraAgregados < _maxMinutosExtra;
    final bool puedeGenerar = !isQrActive && !_claseYaDictadaHoy;
    final bool sesionTerminada = !isQrActive && _claseYaDictadaHoy;

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
              if (sesionTerminada)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade100)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_clock, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Clase finalizada por hoy", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else ...[
                Text(
                    isQrActive ? "Código expira en" : "Listo para iniciar",
                    style: TextStyle(color: greyText, fontSize: 16)
                ),
                const SizedBox(height: 8),
                Text(
                  isQrActive ? _timerString : "5:00",
                  style: TextStyle(
                      color: isQrActive ? primaryGreen : Colors.grey,
                      fontSize: 48,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ],

              // BOTÓN AÑADIR TIEMPO
              if (isQrActive)
                TextButton.icon(
                  onPressed: puedeAnadirMas ? _anadirTiempo : null,
                  style: TextButton.styleFrom(
                    foregroundColor: puedeAnadirMas ? primaryGreen : Colors.grey,
                    backgroundColor: puedeAnadirMas ? primaryGreen.withOpacity(0.1) : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(puedeAnadirMas ? "Añadir 1 min extra" : "Límite alcanzado"),
                )
              else
                const SizedBox(height: 48),

              const SizedBox(height: 30),

              // --- SECCIÓN QR CON CAPTURA ---
              Screenshot(
                controller: _screenshotController,
                child: Container(
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
                      : (isQrActive && qrData != null)
                      ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.nombreClase, style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          QrImageView(
                            data: qrData!,
                            version: QrVersions.auto,
                            size: 200.0,
                            foregroundColor: darkText,
                            backgroundColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  )
                      : Container(
                    height: 200,
                    width: 200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            sesionTerminada ? Icons.lock_clock : Icons.qr_code_2,
                            size: 50,
                            color: Colors.grey.shade300
                        ),
                        const SizedBox(height: 10),
                        Text(
                          sesionTerminada ? "Sesión Finalizada" : "Presiona Generar",
                          style: TextStyle(color: Colors.grey.shade400),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // INFO CARD
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
                  onPressed: puedeGenerar ? _generarNuevoQR : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isQrActive ? 0 : 2,
                  ),
                  icon: Icon(isQrActive ? Icons.check : (sesionTerminada ? Icons.block : Icons.qr_code)),
                  label: Text(
                    isQrActive ? "Código Activo" : (sesionTerminada ? "Clase Finalizada" : "Generar Código QR"),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de descargar
              if (isQrActive)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _guardarImagenQR,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkText,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_outlined),
                    label: Text(
                      _isSaving ? "Guardando..." : "Descargar QR como imagen",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  // Si quieres mantener las esquinas decorativas
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