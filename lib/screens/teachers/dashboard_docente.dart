import 'package:flutter/material.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Colores extraídos de tu imagen (Tema Verde)
    final Color primaryGreen = const Color(0xFF00C853);
    final Color backgroundWhite = const Color(0xFFF5F6FA);
    final Color textDark = const Color(0xFF1F222E);

    return Scaffold(
      backgroundColor: primaryGreen, // Fondo verde para la parte superior
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------
            // 1. ENCABEZADO VERDE (Perfil y Estadísticas)
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
                            "Buenos días",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Prof. María García",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            "MG",
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem("3", "Clases hoy"),
                        _buildVerticalDivider(),
                        _buildStatItem("85", "Estudiantes"),
                        _buildVerticalDivider(),
                        _buildStatItem("94%", "Asistencia"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ---------------------------------------------
            // 2. CONTENEDOR BLANCO (LISTA SCROLLEABLE)
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
                    // Título de la sección
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                      child: Row(
                        children: [
                          Text(
                            "Mis Clases",
                            style: TextStyle(
                              color: textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista de Clases
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Clase 1: Pasada
                          _buildClassCard(
                            subject: "Matemáticas",
                            groupInfo: "Grupo 6A • 08:00",
                            attendanceRatio: "26/28",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),

                          // Clase 2: En Curso (Activa)
                          _buildClassCard(
                            subject: "Programación",
                            groupInfo: "Grupo 5B • 10:00",
                            attendanceRatio: "0/32",
                            isActive: true,
                            primaryColor: primaryGreen,
                          ),

                          // Clase 3: Futura
                          _buildClassCard(
                            subject: "Base de Datos",
                            groupInfo: "Grupo 6B • 12:00",
                            attendanceRatio: "0/25",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),

                          // Clase 4
                          _buildClassCard(
                            subject: "Redes II",
                            groupInfo: "Grupo 7A • 14:00",
                            attendanceRatio: "0/30",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),

                          // Clases Extra para probar scroll
                          _buildClassCard(
                            subject: "Redes II",
                            groupInfo: "Grupo 7A • 14:00",
                            attendanceRatio: "0/30",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),
                          _buildClassCard(
                            subject: "Redes II",
                            groupInfo: "Grupo 7A • 14:00",
                            attendanceRatio: "0/30",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),
                          _buildClassCard(
                            subject: "Redes II",
                            groupInfo: "Grupo 7A • 14:00",
                            attendanceRatio: "0/30",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),
                          _buildClassCard(
                            subject: "Redes II",
                            groupInfo: "Grupo 7A • 14:00",
                            attendanceRatio: "0/30",
                            isActive: false,
                            primaryColor: primaryGreen,
                          ),

                          // --- AQUÍ ESTÁ EL CAMBIO ---
                          // Aumentamos el espacio final a 100 para que la barra no tape el último item
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

  // Widget para estadísticas del encabezado
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
        height: 30,
        width: 1,
        color: Colors.white.withOpacity(0.3)
    );
  }

  // Widget de la Tarjeta de Clase
  Widget _buildClassCard({
    required String subject,
    required String groupInfo,
    required String attendanceRatio,
    required bool isActive,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: primaryColor, width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Icono del reloj
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? primaryColor : const Color(0xFFF0F1F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time_filled,
              color: isActive ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // 2. Información Central
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1F222E),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "En curso",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  groupInfo,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // 3. Columna de Asistencia
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                attendanceRatio,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1F222E),
                ),
              ),
              const Text(
                "asistencia",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}