import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  // Definimos un tamaño fijo para el área de escaneo para que todo coincida
  final double scanSize = 300.0;

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
          // ------------------------------------------------
          // CAPA 1: LA CÁMARA
          // ------------------------------------------------
          MobileScanner(
            controller: controller,
            errorBuilder: (context, error, child) {
              return const Center(child: Icon(Icons.error, color: Colors.red));
            },
            onDetect: (capture) {
              // Tu lógica de detección aquí
            },
          ),

          // ------------------------------------------------
          // CAPA 2: FONDO OSCURO CON HUECO
          // ------------------------------------------------
          // Usamos Positioned.fill para que ocupe toda la pantalla
          // y el CustomPainter dibuje el hueco exactamente al centro.
          Positioned.fill(
            child: CustomPaint(
              painter: QRScannerOverlay(
                overlayColor: Colors.black.withOpacity(0.8),
                scanAreaSize: scanSize, // Usamos el mismo tamaño
                borderRadius: 20,
              ),
            ),
          ),

          // ------------------------------------------------
          // CAPA 3: MARCOS AZULES (BRACKETS)
          // ------------------------------------------------
          // Usamos "Center" para forzar que esté exactamente en medio,
          // coincidiendo con el hueco del paso anterior.
          Center(
            child: SizedBox(
              width: scanSize,  // Mismo tamaño que el hueco
              height: scanSize, // Mismo tamaño que el hueco
              child: CustomPaint(
                painter: ScannerOverlayPainter(color: accentBlue),
              ),
            ),
          ),

          // ------------------------------------------------
          // CAPA 4: INTERFAZ DE USUARIO (TEXTOS)
          // ------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                // --- CABECERA (Lo que querías conservar) ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Botón Atrás
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Texto Centrado
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
                      // Widget invisible para equilibrar el Row y que el título quede centrado
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(), // Empuja todo lo de abajo

                // Texto informativo debajo del cuadro
                // Le damos un padding top para que no pegue con el cuadro azul
                Padding(
                  padding: EdgeInsets.only(top: scanSize + 40),
                  child: const Text(
                    "Alinea el código QR dentro del marco",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

                const Spacer(), // Empuja el pie de página al fondo

                // --- PIE DE PÁGINA (Solo GPS, sin botones) ---
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, color: accentGreen, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "GPS Activo - Ubicación verificada",
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

// -------------------------------------------------------
// CLASES DE PINTURA (NO CAMBIAN, PERO SON NECESARIAS)
// -------------------------------------------------------

// 1. Pinta el fondo oscuro con el hueco
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

    // Calculamos el centro exacto de la pantalla disponible
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

// 2. Pinta las esquinas azules
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

    // Top Left
    Path pathTL = Path();
    pathTL.moveTo(0, cornerLength);
    pathTL.lineTo(0, 0);
    pathTL.lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    // Top Right
    Path pathTR = Path();
    pathTR.moveTo(size.width - cornerLength, 0);
    pathTR.lineTo(size.width, 0);
    pathTR.lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom Left
    Path pathBL = Path();
    pathBL.moveTo(0, size.height - cornerLength);
    pathBL.lineTo(0, size.height);
    pathBL.lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    // Bottom Right
    Path pathBR = Path();
    pathBR.moveTo(size.width - cornerLength, size.height);
    pathBR.lineTo(size.width, size.height);
    pathBR.lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}