import 'package:flutter/material.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definición de colores del diseño
    final Color primaryBlue = const Color(0xFF2563EB); // Azul vibrante
    final Color backgroundWhite = const Color(0xFFF5F6FA); // Blanco humo
    final Color textDark = const Color(0xFF1F222E);

    return Scaffold(
      backgroundColor: primaryBlue, // Fondo azul para que se vea arriba
      body: SafeArea(
        bottom: false, // Para que el blanco llegue hasta abajo
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------
            // 1. ENCABEZADO AZUL (Perfil y Estadísticas)
            // ---------------------------------------------
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila Superior: Saludo y Avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Bienvenido de nuevo",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Carlos Martínez",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Avatar con iniciales
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            "CM",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Fila de Estadísticas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem("92%", "Asistencia"),
                      _buildStatItem("24", "Clases este mes"),
                      _buildStatItem("2", "Faltas"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ---------------------------------------------
            // 2. CONTENEDOR BLANCO CON LISTA SCROLLEABLE
            // ---------------------------------------------
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: backgroundWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Título de la sección (Fijo, no scrollea)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Clases de Hoy",
                            style: TextStyle(
                              color: textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: const [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text(
                                "27 Nov",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Lista Scrolleable
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(), // Efecto rebote suave
                        children: [
                          _buildClassCard(
                            time: "08:00",
                            subject: "Matemáticas",
                            room: "Salón A-101",
                            status: ClassStatus.completed,
                            accentColor: const Color(0xFF00C853), // Verde
                          ),
                          _buildClassCard(
                            time: "10:00",
                            subject: "Programación",
                            room: "Salón B-205",
                            status: ClassStatus.pending,
                            accentColor: const Color(0xFF2563EB), // Azul
                          ),
                          _buildClassCard(
                            time: "12:00",
                            subject: "Base de Datos",
                            room: "Salón C-301",
                            status: ClassStatus.upcoming,
                            accentColor: const Color(0xFFFFA000), // Naranja
                          ),
                          _buildClassCard(
                            time: "14:00",
                            subject: "Redes",
                            room: "Salón D-102",
                            status: ClassStatus.upcoming,
                            accentColor: const Color(0xFFE91E63), // Rosa
                          ),
                          // Agregamos una extra para probar el scroll
                          _buildClassCard(
                            time: "16:00",
                            subject: "Inglés V",
                            room: "Lab Idiomas",
                            status: ClassStatus.upcoming,
                            accentColor: const Color(0xFF9C27B0), // Morado
                          ),

                          // --- AQUÍ ESTÁ EL CAMBIO ---
                          // Espacio extra al final para evitar que la barra tape el último elemento
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para las estadísticas de arriba
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para las tarjetas de clase
  Widget _buildClassCard({
    required String time,
    required String subject,
    required String room,
    required ClassStatus status,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Línea de color a la izquierda
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),

            // Contenido de la tarjeta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  children: [
                    // Hora
                    Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1F222E),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Materia y Salón
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1F222E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Estado (Icono o Pill)
                    if (status == ClassStatus.completed)
                      const Icon(Icons.check_circle_outline, color: Color(0xFF00C853), size: 28)
                    else if (status == ClassStatus.pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Pendiente",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enum simple para manejar los estados visuales
enum ClassStatus { completed, pending, upcoming }