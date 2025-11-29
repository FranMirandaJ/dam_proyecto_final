import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherGenerateQRScreen extends StatelessWidget {
  const TeacherGenerateQRScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definimos los colores del diseño
    final Color primaryGreen = const Color(0xFF00C853);
    final Color darkText = const Color(0xFF1F222E);
    final Color greyText = const Color(0xFF757575);
    final Color lightBackgroundCard = const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: Colors.white,
      // 1. APPBAR PERSONALIZADO
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // Eliminamos el leading (flecha atrás) si esto va dentro de un tab bar
        // para que no cause conflicto, o lo dejamos si es push.
        // Si es una pestaña principal, usualmente no lleva "atrás".
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10), // Pequeño ajuste visual
            Text(
              "Generar QR",
              style: TextStyle(
                  color: darkText, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              "Programación - Grupo 5B",
              style: TextStyle(color: greyText, fontSize: 14),
            ),
          ],
        ),
      ),

      // 2. CUERPO DE LA PANTALLA
      body: SingleChildScrollView(
        // Agregamos un bouncing physics para que se sienta bien el scroll
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Divider(),
              const SizedBox(height: 20),

              // --- SECCIÓN DEL TEMPORIZADOR ---
              Text(
                "Código expira en",
                style: TextStyle(color: greyText, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "5:00",
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // BOTÓN AÑADIR TIEMPO
              TextButton.icon(
                onPressed: () {
                  debugPrint("Añadir 1 minuto");
                },
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  backgroundColor: primaryGreen.withOpacity(0.1),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text("Añadir 1 min extra"),
              ),
              const SizedBox(height: 30),

              // --- SECCIÓN DEL CÓDIGO QR ---
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: "CLASE-PROGRA-5B-TOKEN-123",
                      version: QrVersions.auto,
                      size: 200.0,
                      foregroundColor: darkText,
                    ),
                    _buildCornerBrackets(greyText.withOpacity(0.3)),
                  ],
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
                          Text("B-205",
                              style: TextStyle(
                                  color: darkText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text("Salón", style: TextStyle(color: greyText)),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.grey.shade300),
                    Expanded(
                      child: Column(
                        children: [
                          Text("32",
                              style: TextStyle(
                                  color: darkText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text("Estudiantes",
                              style: TextStyle(color: greyText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- BOTÓN REGENERAR ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    debugPrint("Regenerar QR");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    "Regenerar Código",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- BOTÓN DESCARGAR IMAGEN ---
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

              // --- AQUÍ ESTÁ EL TRUCO ---
              // Agregamos un espacio grande al final (100 px).
              // Esto permite hacer scroll "de más" para que el último botón
              // suba por encima de la barra de navegación flotante.
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