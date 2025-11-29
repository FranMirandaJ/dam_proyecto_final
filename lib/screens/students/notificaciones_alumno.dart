import 'package:flutter/material.dart';

class StudentNotificationScreen extends StatelessWidget {
  const StudentNotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Colores del tema del estudiante
    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textDark = const Color(0xFF1F222E);
    final Color bgWhite = const Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco limpio

      // 1. APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // Si esta pantalla es una pestaña principal del Home, no suele llevar botón "Atrás".
        // Si la abres con push, Flutter lo pone automático.
        // Si quieres quitarlo, usa: automaticallyImplyLeading: false,
        title: Text(
          "Notificaciones",
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Badge con el número de notificaciones no leídas
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.all(8), // Tamaño del círculo
            decoration: BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Text(
              "2",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),

      // 2. LISTA SCROLLEABLE
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [

          // NOTIFICACIÓN 1: Nueva clase (No leída)
          _buildNotificationCard(
            icon: Icons.calendar_today_rounded,
            iconColor: primaryBlue,
            title: "Nueva clase programada",
            body: "Clase de Programación mañana a las 10:00 AM en el salón B-205",
            time: "Hace 5 min",
            isUnread: true,
          ),

          // NOTIFICACIÓN 2: Advertencia (No leída)
          _buildNotificationCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFFFA000), // Amber/Naranja
            title: "Recordatorio importante",
            body: "Tienes 2 faltas acumuladas este mes. Recuerda asistir a todas tus clases.",
            time: "Hace 1 hora",
            isUnread: true,
          ),

          // NOTIFICACIÓN 3: Éxito (Leída)
          _buildNotificationCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF00C853), // Verde
            title: "Asistencia confirmada",
            body: "Tu asistencia a Matemáticas fue registrada exitosamente.",
            time: "Hace 3 horas",
            isUnread: false,
          ),

          // NOTIFICACIÓN 4: Info (Leída)
          _buildNotificationCard(
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFF757575), // Gris
            title: "Próxima clase",
            body: "Tu clase de Base de Datos comienza en 30 minutos. Salón C-301",
            time: "Ayer",
            isUnread: false,
          ),

          // NOTIFICACIÓN 5: Info Extra (Para probar scroll)
          _buildNotificationCard(
            icon: Icons.event_note_rounded,
            iconColor: primaryBlue,
            title: "Cambio de horario",
            body: "La clase de Redes se ha movido al viernes a las 12:00 PM.",
            time: "Ayer",
            isUnread: false,
          ),

          // --- AQUÍ ESTÁ EL CAMBIO ---
          // Aumentamos el espacio final a 100 px para evitar que la barra tape la última tarjeta
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA LA TARJETA ---
  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      // Decoración del contenedor principal
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // Usamos ClipRRect para que el borde azul de la izquierda respete el redondeo
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight( // Para que la línea azul crezca con el contenido
          child: Row(
            children: [
              // 1. BARRA LATERAL AZUL (Solo si no está leída)
              if (isUnread)
                Container(
                  width: 6,
                  color: const Color(0xFF2563EB), // Azul primario
                )
              else
                const SizedBox(width: 6), // Espacio invisible para alinear

              // 2. CONTENIDO
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ICONO CIRCULAR
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1), // Fondo suave del mismo color
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),

                      const SizedBox(width: 16),

                      // TEXTOS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título y Punto Azul
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: const Color(0xFF1F222E), // Texto oscuro
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      // Si es unread, el texto es un poco más negro, si no, normal
                                    ),
                                  ),
                                ),
                                // PUNTO AZUL (Indicador de nuevo)
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Cuerpo del mensaje
                            Text(
                              body,
                              style: const TextStyle(
                                color: Color(0xFF757575), // Gris texto
                                fontSize: 13,
                                height: 1.4, // Interlineado
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Tiempo
                            Text(
                              time,
                              style: TextStyle(
                                color: const Color(0xFF9E9E9E), // Gris clarito
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
      ),
    );
  }
}