import 'package:flutter/material.dart';
import 'package:proyecto_final/services/auth.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';

import 'admin_users.dart';
import 'admin_aulas.dart';
import 'admin_periodos.dart';
import 'admin_clases.dart';

import 'widgets/create_teacher_modal.dart';
import 'widgets/manage_aula_modal.dart';
import 'widgets/manage_periodo_modal.dart';
import 'widgets/manage_clase_modal.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  final Color primaryColor = const Color(0xFF3F51B5);

  final List<String> _titles = [
    "Gestión Usuarios",
    "Gestión Aulas",
    "Gestión Periodos",
    "Gestión Clases",
  ];

  late final List<Widget> _screens = [
    const AdminUsersScreen(),
    const AdminAulasScreen(),
    const AdminPeriodosScreen(),
    const AdminClasesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              await Auth().signOut(context);
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginRegister(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: _screens[_currentIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: primaryColor.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Usuarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: 'Aulas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Periodos',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Clases',
          ),
        ],
      ),

      // Botón flotante genérico
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          if (_currentIndex == 0) {
            // USUARIOS
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const CreateTeacherModal(),
            );
          } else if (_currentIndex == 1) {
            // AULAS
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, // Importante para el teclado
              backgroundColor: Colors.transparent,
              builder: (context) =>
                  const ManageAulaModal(), // Sin argumentos = Crear
            );
          } else if (_currentIndex == 2) {
            // PERIODOS
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ManagePeriodoModal(), // Crear nuevo
            );
          } else if (_currentIndex == 3) {
            // CLASES
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ManageClaseModal(), // Crear nueva
            );
          }
        },
      ),
    );
  }
}
