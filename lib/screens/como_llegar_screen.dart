import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Modo de viaje para la ruta. Los tres primeros se trazan con OSRM
/// (servidores públicos de FOSSGIS/OpenStreetMap, sin API key); transporte
/// público no existe en OSRM, así que abre Google Maps en modo transit.
enum _TravelMode {
  caminar('A pie', Icons.directions_walk, 'routed-foot', 'walking'),
  auto('Auto', Icons.directions_car_outlined, 'routed-car', 'driving'),
  bici('Bici', Icons.directions_bike_outlined, 'routed-bike', 'cycling'),
  transporte('Transporte', Icons.directions_bus_outlined, null, null);

  final String label;
  final IconData icon;
  final String? osrmServer;
  final String? osrmProfile;

  const _TravelMode(this.label, this.icon, this.osrmServer, this.osrmProfile);
}

class _Ruta {
  final List<LatLng> puntos;
  final double distanciaM;
  final double duracionSeg;

  const _Ruta(this.puntos, this.distanciaM, this.duracionSeg);
}

/// Pantalla "Cómo llegar" (solo móvil): ubica al usuario con el GPS del
/// dispositivo y traza la ruta hasta el proyecto en un mapa OSM según el
/// modo seleccionado.
class ComoLlegarScreen extends StatefulWidget {
  final double destinoLat;
  final double destinoLng;
  final String nombre;
  final String? direccion;

  const ComoLlegarScreen({
    super.key,
    required this.destinoLat,
    required this.destinoLng,
    required this.nombre,
    this.direccion,
  });

  @override
  State<ComoLlegarScreen> createState() => _ComoLlegarScreenState();
}

class _ComoLlegarScreenState extends State<ComoLlegarScreen> {
  final _mapController = MapController();
  _TravelMode _mode = _TravelMode.auto;
  LatLng? _origen;
  _Ruta? _ruta;
  bool _cargando = true;
  String? _error;

  LatLng get _destino => LatLng(widget.destinoLat, widget.destinoLng);

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pos = await _obtenerPosicion();
      _origen = LatLng(pos.latitude, pos.longitude);
      await _trazarRuta();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e is _UbicacionError
            ? e.mensaje
            : 'No pudimos calcular la ruta. Revisa tu conexión e intenta de nuevo.';
      });
    }
  }

  Future<Position> _obtenerPosicion() async {
    final servicio = await Geolocator.isLocationServiceEnabled();
    if (!servicio) {
      throw _UbicacionError(
        'La ubicación del dispositivo está desactivada. Actívala e intenta de nuevo.',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw _UbicacionError(
        'Sin permiso de ubicación. Autorízalo en los ajustes del teléfono para trazar la ruta.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> _trazarRuta() async {
    final origen = _origen;
    if (origen == null) return;
    if (_mode == _TravelMode.transporte) {
      // OSRM no calcula transporte público: se abre Google Maps en transit.
      setState(() {
        _ruta = null;
        _cargando = false;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final url = Uri.parse(
      'https://routing.openstreetmap.de/${_mode.osrmServer}/route/v1/${_mode.osrmProfile}/'
      '${origen.longitude},${origen.latitude};${_destino.longitude},${_destino.latitude}'
      '?overview=full&geometries=geojson',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('sin rutas');
    }
    final route = routes.first as Map<String, dynamic>;
    final coords =
        ((route['geometry'] as Map)['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
    if (!mounted) return;
    setState(() {
      _ruta = _Ruta(
        coords,
        (route['distance'] as num).toDouble(),
        (route['duration'] as num).toDouble(),
      );
      _cargando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ajustarVista());
  }

  void _ajustarVista() {
    final puntos = [
      if (_origen != null) _origen!,
      _destino,
      ...?_ruta?.puntos,
    ];
    if (puntos.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: puntos,
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 120),
      ),
    );
  }

  Future<void> _abrirGoogleMapsTransit() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${widget.destinoLat},${widget.destinoLng}&travelmode=transit',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _resumenRuta() {
    final r = _ruta;
    if (r == null) return '';
    final km = r.distanciaM / 1000;
    final dist = km >= 1
        ? '${km.toStringAsFixed(1)} km'
        : '${r.distanciaM.round()} m';
    final min = (r.duracionSeg / 60).round();
    final dur = min >= 60 ? '${min ~/ 60} h ${min % 60} min' : '$min min';
    return '$dist · $dur';
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cómo llegar')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _destino, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sozu.sozuClienteApp',
              ),
              if (_ruta != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _ruta!.puntos,
                      strokeWidth: 5,
                      color: SozuColors.emerald500,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_origen != null)
                    Marker(
                      point: _origen!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  Marker(
                    point: _destino,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: SozuColors.emerald600,
                    ),
                  ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors'),
              ),
            ],
          ),

          // Panel superior: destino + selector de modo.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nombre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tone.textPrimary,
                      ),
                    ),
                    if (widget.direccion != null &&
                        widget.direccion!.trim().isNotEmpty)
                      Text(
                        widget.direccion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: tone.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_TravelMode>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        segments: [
                          for (final m in _TravelMode.values)
                            ButtonSegment(
                              value: m,
                              icon: Icon(m.icon, size: 18),
                              tooltip: m.label,
                            ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (sel) {
                          setState(() => _mode = sel.first);
                          _trazarRuta().catchError((_) {
                            if (!mounted) return;
                            setState(() {
                              _cargando = false;
                              _error =
                                  'No pudimos calcular la ruta en este modo.';
                            });
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Panel inferior: estado / resumen / acciones.
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _cargando
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text('Calculando ruta…'),
                        ],
                      )
                    : _error != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: tone.negative,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _iniciar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : _mode == _TravelMode.transporte
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Las rutas de transporte público se consultan en Google Maps.',
                            style: TextStyle(
                              fontSize: 13,
                              color: tone.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _abrirGoogleMapsTransit,
                            icon: const Icon(Icons.directions_bus_outlined),
                            label: const Text('Abrir en Google Maps'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(_mode.icon, color: tone.primaryDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _resumenRuta(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tone.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Centrar ruta',
                            onPressed: _ajustarVista,
                            icon: const Icon(Icons.center_focus_strong),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UbicacionError implements Exception {
  final String mensaje;

  _UbicacionError(this.mensaje);
}
