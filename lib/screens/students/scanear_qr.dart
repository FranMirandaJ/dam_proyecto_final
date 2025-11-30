import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint; // <--- AQUÍ ESTÁ LA CORRECCIÓN
import 'package:geolocator/geolocator.dart'; // Asegúrate de agregarlo a pubspec.yaml

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false; // Para evitar lecturas múltiples

  // Tamaño del área de escaneo
  final double scanSize = 300.0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // --- LÓGICA PRINCIPAL DE VALIDACIÓN Y REGISTRO ---
  Future<void> _procesarCodigoQR(String rawCode) async {
    if (_isProcessing) return; // Evita doble procesamiento
    setState(() => _isProcessing = true);

    try {
      // 1. PARSEO DEL CÓDIGO
      // Formato esperado: "CLASEID_TIMESTAMP"
      final parts = rawCode.split('_');
      if (parts.isEmpty) throw "Código QR inválido";

      final String claseId = parts[0];
      final String uidAlumno = FirebaseAuth.instance.currentUser!.uid;

      // Mostrar carga
      _mostrarDialogoCarga();

      // 2. CONSULTAR DATOS DE LA CLASE
      final claseDoc = await FirebaseFirestore.instance.collection('clase').doc(claseId).get();

      if (!claseDoc.exists) throw "La clase no existe";
      final dataClase = claseDoc.data()!;

      // 2.1 Validar si el QR sigue activo según el profesor
      if (dataClase['qrActivo'] == false) {
        throw "El código QR ya no es válido o ha expirado.";
      }

      // 2.2 Validar si el alumno pertenece a la clase
      final List<dynamic> alumnosInscritos = dataClase['alumnos'] ?? [];
      // Buscamos si la referencia del usuario está en la lista
      // Tu BD guarda referencias completas: /usuario/UID
      final userRef = FirebaseFirestore.instance.doc('usuario/$uidAlumno');

      // A veces Firestore compara referencias directo, a veces hay que comparar paths
      bool estaInscrito = alumnosInscritos.any((a) => a == userRef);
      if (!estaInscrito) throw "No estás inscrito en esta clase.";

      // 3. VALIDACIÓN DE UBICACIÓN (GPS)
      // Obtenemos referencia del aula para sacar sus coordenadas reales
      final DocumentReference aulaRef = dataClase['aula'];
      final aulaDoc = await aulaRef.get();

      if (!aulaDoc.exists) throw "Error: Aula no encontrada en el sistema.";

      // Asumiendo que guardaste coordenadas como GeoPoint o Mapa [lat, lng]
      // Tu imagen mostraba un array [lat, lng], lo adaptamos:
      final dynamic coordsData = aulaDoc['coordenadas'];
      double aulaLat = 0;
      double aulaLng = 0;

      if (coordsData is GeoPoint) {
        aulaLat = coordsData.latitude;
        aulaLng = coordsData.longitude;
      } else if (coordsData is List) {
        // Si lo guardaste como array [lat, lng]
        aulaLat = coordsData[0];
        aulaLng = coordsData[1];
      }

      // Obtener posición actual del alumno
      Position position = await _determinarPosicion();

      // Calcular distancia en metros
      double distanciaEnMetros = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          aulaLat,
          aulaLng
      );

      print("Distancia al salón: $distanciaEnMetros metros");

      // Rango permitido (ej. 50 metros)
      if (distanciaEnMetros > 100) {
        throw "Estás demasiado lejos del salón (${distanciaEnMetros.round()}m). Acércate más.";
      }

      // 4. VERIFICAR DUPLICADOS (Si ya checó hoy)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final asistenciaExistente = await FirebaseFirestore.instance
          .collection('asistencia')
          .where('claseId', isEqualTo: claseDoc.reference)
          .where('alumnoId', isEqualTo: userRef)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      if (asistenciaExistente.docs.isNotEmpty) {
        throw "Ya has registrado tu asistencia hoy.";
      }

      // 5. REGISTRAR ASISTENCIA
      await FirebaseFirestore.instance.collection('asistencia').add({
        'claseId': claseDoc.reference,
        'alumnoId': userRef,
        'fecha': FieldValue.serverTimestamp(),
        'ubicacionRegistro': GeoPoint(position.latitude, position.longitude),
        // 'estado': 1 // Ya acordamos que no es necesario, la existencia basta
      });

      // ÉXITO
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        _mostrarExito("¡Asistencia registrada correctamente!");
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        _mostrarError(e.toString());
      }
    } finally {
      // Pequeño delay antes de permitir escanear de nuevo si falló
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Helper para permisos de GPS
  Future<Position> _determinarPosicion() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('El GPS está desactivado.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permisos de ubicación denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permisos de ubicación denegados permanentemente.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _mostrarDialogoCarga() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK")
          )
        ],
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text("Éxito"),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Cerrar alerta
                Navigator.pop(context); // Regresar al dashboard
              },
              child: const Text("Aceptar")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colores
    final Color backgroundColor = const Color(0xFF0F111A);
    final Color accentBlue = const Color(0xFF3B82F6);
    final Color accentGreen = const Color(0xFF00C853);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. CÁMARA
          MobileScanner(
            controller: controller,
            errorBuilder: (context, error, child) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            },
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _procesarCodigoQR(barcode.rawValue!);
                  break; // Procesar solo el primero
                }
              }
            },
          ),

          // 2. FONDO OSCURO CON HUECO
          Positioned.fill(
            child: CustomPaint(
              painter: QRScannerOverlay(
                overlayColor: Colors.black.withOpacity(0.8),
                scanAreaSize: scanSize,
                borderRadius: 20,
              ),
            ),
          ),

          // 3. MARCOS AZULES
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: CustomPaint(
                painter: ScannerOverlayPainter(color: accentBlue),
              ),
            ),
          ),

          // 4. INTERFAZ
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          "Escanear QR",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: EdgeInsets.only(top: scanSize + 40),
                  child: const Text(
                    "Alinea el código QR dentro del marco",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, color: accentGreen, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Validación GPS Activa",
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ... (Las clases QRScannerOverlay y ScannerOverlayPainter se mantienen igual que en tu versión anterior)
class QRScannerOverlay extends CustomPainter {
  final Color overlayColor;
  final double scanAreaSize;
  final double borderRadius;

  QRScannerOverlay({
    required this.overlayColor,
    required this.scanAreaSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect screenRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double cutOutLeft = (size.width - scanAreaSize) / 2;
    final double cutOutTop = (size.height - scanAreaSize) / 2;
    final RRect cutOutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutOutLeft, cutOutTop, scanAreaSize, scanAreaSize),
      Radius.circular(borderRadius),
    );
    final Path backgroundPath = Path()
      ..addRect(screenRect)
      ..addRRect(cutOutRect)
      ..fillType = PathFillType.evenOdd;
    final Paint paint = Paint()..color = overlayColor;
    canvas.drawPath(backgroundPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScannerOverlayPainter extends CustomPainter {
  final Color color;
  ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    double cornerLength = 40;

    Path pathTL = Path()..moveTo(0, cornerLength)..lineTo(0, 0)..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    Path pathTR = Path()..moveTo(size.width - cornerLength, 0)..lineTo(size.width, 0)..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    Path pathBL = Path()..moveTo(0, size.height - cornerLength)..lineTo(0, size.height)..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    Path pathBR = Path()..moveTo(size.width - cornerLength, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}