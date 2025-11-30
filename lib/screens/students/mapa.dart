import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:proyecto_final/services/queriesFirestore/estudianteQueries.dart';

class Mapa extends StatefulWidget {
  const Mapa({super.key});

  @override
  State<Mapa> createState() => _MapaState();
}

class _MapaState extends State<Mapa> {
  late final MapController _mapController;

  static const LatLng _schoolLocation = LatLng(
    21.47884788795137,
    -104.86588398779995,
  );
  LatLng _currentPosition = _schoolLocation;

  List<Map<String, dynamic>> _proximasClases = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition(moveMap: false);
    _cargarClases();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _cargarClases() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || user.uid.isEmpty) return;

    try {
      final clases = await EstudianteQueries.getClasesInfoParaEstudiante(
        user.uid,
      );
      clases.sort((a, b) {
        final horaA = a['hora'] as String? ?? '99:99';
        final horaB = b['hora'] as String? ?? '99:99';
        return horaA.compareTo(horaB);
      });

      if (mounted) {
        setState(() {
          _proximasClases = clases;
        });
      }
    } catch (e) {
      print('Error al cargar las clases en el mapa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar las clases.')),
        );
      }
    }
  }

  Future<void> _determinePosition({bool moveMap = true}) async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, activa los servicios de ubicación.'),
          ),
        );
      }
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      if (moveMap) {
        _mapController.move(_currentPosition, 17.5);
      }
    }
  }

  void _centerOnSchool() {
    _mapController.move(_schoolLocation, 17.0);
  }

  // 1. Nueva función para formatear la hora de 24h a 12h con am/pm
  String _formatTime12Hour(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2)
        return time24h; // Devuelve original si el formato es incorrecto

      int hour = int.parse(parts[0]);
      final String minute = parts[1];
      final String period = hour >= 12 ? 'pm' : 'am';

      if (hour > 12) {
        hour -= 12;
      } else if (hour == 0) {
        hour = 12;
      }

      return '$hour:$minute $period';
    } catch (e) {
      return time24h; // En caso de error, devuelve el string original
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> clasesMarkers = _proximasClases.map((clase) {
      return Marker(
        point: LatLng(clase['latitud'], clase['longitud']),
        width: 45,
        height: 45,
        child: Tooltip(
          message: "${clase['nombreClase']}\n${clase['nombreAula']}",
          child: Container(
            decoration: BoxDecoration(
              color: Colors.deepOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mi mapa de clases",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // PARTE SUPERIOR: EL MAPA
          Expanded(
            flex: 4,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _schoolLocation,
                initialZoom: 17.0,
                maxZoom: 18.4,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.25),
                            ),
                          ),
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...clasesMarkers,
                  ],
                ),
              ],
            ),
          ),
          // PARTE INFERIOR: LISTA DE CLASES
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Próximas clases',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                    itemCount: _proximasClases.length,
                    itemBuilder: (context, index) {
                      final clase = _proximasClases[index];
                      return Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: ListTile(
                          // 2. Icono cambiado a marcador de mapa
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.indigo,
                          ),
                          title: Text(
                            clase['nombreClase'] ?? 'Clase',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(clase['nombreAula'] ?? 'Aula'),
                          // 3. Usamos la función para formatear la hora
                          trailing: Text(
                            _formatTime12Hour(clase['hora'] ?? '--:--'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // 4. Padding de los botones corregido a un valor adecuado
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 410.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              onPressed: _cargarClases,
              heroTag: 'refresh_button',
              tooltip: 'Refrescar clases',
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              onPressed: _centerOnSchool,
              heroTag: 'school_button',
              tooltip: 'Centrar en escuela',
              child: const Icon(Icons.school),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              onPressed: () => _determinePosition(moveMap: true),
              heroTag: 'location_button',
              tooltip: 'Mi ubicación',
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }
}
