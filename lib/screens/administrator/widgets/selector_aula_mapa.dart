import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({Key? key, this.initialPosition}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;

  // Coordenadas del Tecnológico de Tepic (o tu escuela)
  // Úsalas como fallback seguro para que el mapa no aparezca en el mar o en Googleplex
  static const LatLng _schoolLocation = LatLng(21.47884788795137, -104.86588398779995);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Si nos pasan una posición inicial (edición), la usamos.
    // Si no, usamos la ubicación de la escuela por defecto.
    _currentCenter = widget.initialPosition ?? _schoolLocation;

    // Solo intentamos ir al GPS si es una creación nueva (no edición)
    if (widget.initialPosition == null) {
      _goToUserLocation();
    }
  }

  Future<void> _goToUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return; // Si no hay GPS, nos quedamos en la escuela

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // Obtenemos la posición
      Position position = await Geolocator.getCurrentPosition();

      // HACK PARA EMULADOR:
      // Si las coordenadas son las de Googleplex (37.42, -122.08), las ignoramos
      // y nos quedamos en la escuela, para no confundir al usuario en pruebas.
      if ((position.latitude - 37.42).abs() < 0.1 && (position.longitude - -122.08).abs() < 0.1) {
        print("Detectada ubicación default del emulador (Googleplex). Ignorando...");
        return;
      }

      if (mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          18.0,
        );
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print("Error obteniendo ubicación: $e");
      // En caso de error, no hacemos nada y el mapa se queda en _schoolLocation
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Ubicación"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Ir a mi ubicación",
            onPressed: _goToUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 18.0,
              // Actualizamos el centro cuando el usuario arrastra el mapa
              onPositionChanged: (camera, hasGesture) {
                setState(() {
                  _currentCenter = camera.center;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Es buena práctica poner tu nombre de paquete
                userAgentPackageName: 'com.example.proyecto_final',
              ),
            ],
          ),

          // Marcador Central Fijo (Target)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 50,
                  color: Colors.red,
                ),
                // Sombra del marcador
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 50), // Offset para centrar la punta
              ],
            ),
          ),

          // Botón Confirmar
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                // Devolvemos las coordenadas al formulario anterior
                Navigator.pop(context, _currentCenter);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: const Text(
                "CONFIRMAR ESTA UBICACIÓN",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // Panel informativo de coordenadas (Opcional, para debug)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gps_fixed, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}