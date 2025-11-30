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

  // Coordenadas de la escuela como una constante
  static const LatLng _schoolLocation = LatLng(21.47884788795137, -104.86588398779995);

  // La posición del usuario empieza en un punto neutro hasta que se obtenga.
  LatLng _currentPosition = _schoolLocation;

  List<Map<String, dynamic>> _aulasDelEstudiante = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition(moveMap: false);
    _cargarAulas();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _cargarAulas() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || user.uid.isEmpty) return;

    try {
      final aulas = await EstudianteQueries.getAulasDeEstudiante(user.uid);
      if (mounted) {
        setState(() {
          _aulasDelEstudiante = aulas;
        });
      }
    } catch (e) {
      print('Error al cargar las aulas en el mapa: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudieron cargar las aulas.'))
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
            const SnackBar(content: Text('Por favor, activa los servicios de ubicación.'))
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

  @override
  Widget build(BuildContext context) {
    final List<Marker> aulasMarkers = _aulasDelEstudiante.map((aula) {
      return Marker(
        point: LatLng(aula['latitud'], aula['longitud']),
        width: 80,
        height: 80,
        child: Tooltip(
          message: aula['nombre'] ?? 'Aula',
          child: Icon(
            Icons.school_outlined,
            color: Colors.deepOrange,
            size: 35,
            shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi mapa de clases", style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: true,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: _schoolLocation,
          initialZoom: 17.0,
          maxZoom: 18.4,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentPosition,
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.25))),
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
              ...aulasMarkers,
            ],
          ),
        ],
      ),
      // 6. Columna de botones elevada para no ser tapada por la BottomNavigationBar
      floatingActionButton: Padding(
        // Añadimos un padding inferior para "subir" los botones.
        // El valor 80.0 es un buen punto de partida. Puedes ajustarlo si es necesario.
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Usamos .small para que sean más compactos y se vean mejor apilados
            FloatingActionButton.small(
              onPressed: _cargarAulas,
              heroTag: 'refresh_button',
              tooltip: 'Refrescar aulas',
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