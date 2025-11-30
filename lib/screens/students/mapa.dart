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

  List<Map<String, dynamic>> _allClases = [];
  int? _selectedIndex;

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

  // Lógica corregida para clasificar clases usando horaFin
  Future<void> _cargarClases() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null || user.uid.isEmpty) return;

    try {
      final clasesData = await EstudianteQueries.getClasesInfoParaEstudiante(
        user.uid,
      );
      final now = DateTime.now();
      final nowInMinutes = now.hour * 60 + now.minute;

      final processedClases = clasesData.map((clase) {
        final horaInicioStr = clase['hora'] as String? ?? '00:00';
        final horaFinStr =
            clase['horaFin'] as String? ?? horaInicioStr; // Usa horaFin

        final inicioParts = horaInicioStr.split(':');
        final finParts = horaFinStr.split(':');

        final inicioInMinutes =
            int.parse(inicioParts[0]) * 60 + int.parse(inicioParts[1]);
        final finInMinutes =
            int.parse(finParts[0]) * 60 + int.parse(finParts[1]);

        // Lógica de estado corregida
        final isPast = nowInMinutes > finInMinutes;
        final isInProgress =
            nowInMinutes >= inicioInMinutes && nowInMinutes <= finInMinutes;

        return {...clase, 'isPast': isPast, 'isInProgress': isInProgress};
      }).toList();

      // Ordena la lista
      processedClases.sort((a, b) {
        // Comparación segura para evitar el error
        final aIsPast = a['isPast'] == true;
        final bIsPast = b['isPast'] == true;

        if (aIsPast && !bIsPast) return 1;
        if (!aIsPast && bIsPast) return -1;

        final horaA = a['hora'] as String;
        final horaB = b['hora'] as String;
        return horaA.compareTo(horaB);
      });

      if (mounted) {
        setState(() {
          _allClases = processedClases;
        });
      }
    } catch (e) {
      print('Error al cargar y procesar las clases: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron procesar las clases.')),
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

  String _formatTime12Hour(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2) return time24h;

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
      return time24h;
    }
  }

  void _onItemTapped(int indexInAllClases) {
    final clase = _allClases[indexInAllClases];
    final newCenter = LatLng(clase['latitud'], clase['longitud']);

    setState(() {
      _selectedIndex = (_selectedIndex == indexInAllClases)
          ? null
          : indexInAllClases;
    });

    if (_selectedIndex != null) {
      _mapController.move(newCenter, 18.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // La lista de UI ahora muestra clases en curso y próximas
    final upcomingOrCurrentClases = _allClases
        .where((c) => c['isPast'] != true)
        .toList();

    final List<Marker> clasesMarkers = [];
    for (int i = 0; i < _allClases.length; i++) {
      final clase = _allClases[i];
      final isSelected = i == _selectedIndex;

      // Comparación segura para los estados
      final bool isPast = clase['isPast'] == true;
      final bool isInProgress = clase['isInProgress'] == true;

      final Color markerColor;
      if (isInProgress) {
        markerColor = Colors.green;
      } else if (isPast) {
        markerColor = Colors.grey.shade600;
      } else {
        markerColor = Colors.deepOrange;
      }

      clasesMarkers.add(
        Marker(
          point: LatLng(clase['latitud'], clase['longitud']),
          width: 150,
          height: 120,
          child: GestureDetector(
            onTap: () => _onItemTapped(i),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 84,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            clase['nombreClase'] ?? 'Clase',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Aula ${clase['nombreAula'] ?? ''}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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
          Expanded(
            flex: 4,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _schoolLocation,
                initialZoom: 17.0,
                maxZoom: 18.4,
                onTap: (tapPosition, point) {
                  if (_selectedIndex != null) {
                    setState(() {
                      _selectedIndex = null;
                    });
                  }
                },
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
                  child: upcomingOrCurrentClases.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(height: 50,),
                              Icon(
                                Icons.check_circle_outline,
                                size: 50,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '¡Felicidades!\nNo tienes más clases hoy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          itemCount: upcomingOrCurrentClases.length,
                          itemBuilder: (context, index) {
                            final clase = upcomingOrCurrentClases[index];
                            final mainIndex = _allClases.indexOf(clase);
                            final isSelected = mainIndex == _selectedIndex;
                            final isInProgress = clase['isInProgress'] == true;

                            return Card(
                              elevation: isSelected ? 4.0 : 2.0,
                              color: isSelected ? Colors.blue.shade50 : null,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: ListTile(
                                onTap: () => _onItemTapped(mainIndex),
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.indigo,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        clase['nombreClase'] ?? 'Clase',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isInProgress)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Chip(
                                          label: const Text(
                                            'En curso',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  "Aula ${clase['nombreAula'] ?? ''}",
                                ),
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
