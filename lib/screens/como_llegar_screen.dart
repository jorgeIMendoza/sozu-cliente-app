import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../widgets/pulsing_pin.dart';

/// Modo de viaje para la ruta, trazada con OSRM (servidores públicos de
/// FOSSGIS/OpenStreetMap, sin API key).
enum _TravelMode {
  caminar('A pie', Icons.directions_walk, '🚶', 'routed-foot', 'walking'),
  bici('En bici', Icons.directions_bike, '🚴', 'routed-bike', 'cycling'),
  auto('En auto', Icons.directions_car, '🚗', 'routed-car', 'driving');

  final String label;
  final IconData icon;

  /// Avatar que avanza por el mapa (estilo Uber: figura, no iconito).
  final String emoji;
  final String osrmServer;
  final String osrmProfile;

  const _TravelMode(
    this.label,
    this.icon,
    this.emoji,
    this.osrmServer,
    this.osrmProfile,
  );
}

class _Ruta {
  final List<LatLng> puntos;
  final double distanciaM;
  final double duracionSeg;

  const _Ruta(this.puntos, this.distanciaM, this.duracionSeg);
}

/// Pantalla "Cómo llegar" (embebida, todas las plataformas): al abrir ubica
/// al usuario con el GPS (en web, geolocalización del navegador), traza la
/// ruta hasta el proyecto (a pie / bici / auto) y SIGUE el movimiento en
/// vivo: stream de posición por eventos (distanceFilter, no polling) que
/// mueve el marcador según el modo, con cámara que sigue al usuario y
/// recálculo de ruta si se desvía.
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
  /// Metros de movimiento para que el GPS emita una nueva posición.
  static const _metrosPorEvento = 8;

  /// Desvío respecto al origen de la ruta actual que dispara recálculo.
  static const _metrosRecalculo = 120.0;

  final _mapController = MapController();
  _TravelMode _mode = _TravelMode.auto;
  LatLng? _origen;
  LatLng? _origenRuta; // origen con el que se calculó la ruta vigente
  _Ruta? _ruta;

  /// Duración estimada (seg) por modo, para mostrarla en el selector.
  final Map<_TravelMode, double> _duraciones = {};
  bool _cargando = true;
  String? _error;
  bool _seguir = false; // cámara siguiendo al usuario
  StreamSubscription<Position>? _posSub;

  LatLng get _destino => LatLng(widget.destinoLat, widget.destinoLng);

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
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
      _escucharMovimiento();
      _cargarDuraciones(); // ETAs de los otros modos, en segundo plano
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

  /// Rastreo en vivo: el stream emite por EVENTOS del GPS (cada
  /// [_metrosPorEvento] m de movimiento), no por timer — el sistema
  /// operativo avisa solo, con mejor precisión y menor batería.
  void _escucharMovimiento() {
    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _metrosPorEvento,
          ),
        ).listen((pos) {
          if (!mounted) return;
          final nueva = LatLng(pos.latitude, pos.longitude);
          setState(() => _origen = nueva);
          if (_seguir) {
            _mapController.move(nueva, _mapController.camera.zoom);
          }
          // Desvío grande respecto a la ruta vigente: recalcular.
          final base = _origenRuta;
          if (base != null && !_cargando) {
            final desvio = Geolocator.distanceBetween(
              base.latitude,
              base.longitude,
              nueva.latitude,
              nueva.longitude,
            );
            if (desvio > _metrosRecalculo) {
              _trazarRuta(ajustarCamara: false).catchError((_) {});
              _cargarDuraciones();
            }
          }
        }, onError: (_) {/* GPS intermitente: se conserva la última posición */});
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
        'Sin permiso de ubicación. Autorízalo en el navegador o en los '
        'ajustes del dispositivo para trazar la ruta.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Consulta en paralelo la duración de los 3 modos (overview=false: solo
  /// resumen, sin geometría) para pintar el ETA en el selector.
  Future<void> _cargarDuraciones() async {
    final origen = _origen;
    if (origen == null) return;
    await Future.wait(_TravelMode.values.map((m) async {
      try {
        final url = Uri.parse(
          'https://routing.openstreetmap.de/${m.osrmServer}/route/v1/${m.osrmProfile}/'
          '${origen.longitude},${origen.latitude};${_destino.longitude},${_destino.latitude}'
          '?overview=false',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) return;
        final routes =
            (jsonDecode(res.body) as Map<String, dynamic>)['routes'] as List?;
        if (routes == null || routes.isEmpty) return;
        final dur = ((routes.first as Map)['duration'] as num).toDouble();
        if (mounted) setState(() => _duraciones[m] = dur);
      } catch (_) {/* sin ETA para ese modo */}
    }));
  }

  String _fmtDuracion(double seg) {
    final min = (seg / 60).round();
    if (min < 1) return '1 min';
    return min >= 60 ? '${min ~/ 60} h ${min % 60}' : '$min min';
  }

  Future<void> _trazarRuta({bool ajustarCamara = true}) async {
    final origen = _origen;
    if (origen == null) return;
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
      _origenRuta = origen;
      _cargando = false;
    });
    if (ajustarCamara) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ajustarVista());
    }
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
            options: MapOptions(
              initialCenter: _destino,
              initialZoom: 15,
              onPositionChanged: (camera, hasGesture) {
                // Si el usuario mueve el mapa a mano, dejar de seguirlo.
                if (hasGesture && _seguir) setState(() => _seguir = false);
              },
            ),
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
                  // Usuario: avatar según el modo (carrito/personita/bici,
                  // estilo Uber) que avanza en vivo con el stream del GPS.
                  if (_origen != null)
                    Marker(
                      point: _origen!,
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Text(
                          _mode.emoji,
                          style: const TextStyle(
                            fontSize: 32,
                            height: 1,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 6),
                              Shadow(
                                color: Colors.white,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Destino: pin con efecto de respiración (halo que crece
                  // y se desvanece en loop); alineación center = punta del
                  // pin sobre la coordenada.
                  Marker(
                    point: _destino,
                    width: PulsingPin.lado,
                    height: PulsingPin.lado,
                    child: const PulsingPin(),
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
                              // Modo + ETA propio (ej. "En auto · 12 min").
                              label: Text(
                                _duraciones[m] == null
                                    ? m.label
                                    : '${m.label} · ${_fmtDuracion(_duraciones[m]!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
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
                            tooltip: _seguir
                                ? 'Dejar de seguirme'
                                : 'Seguir mi posición',
                            onPressed: () {
                              setState(() => _seguir = !_seguir);
                              final o = _origen;
                              if (_seguir && o != null) {
                                _mapController.move(o, 16);
                              }
                            },
                            icon: Icon(
                              _seguir
                                  ? Icons.my_location
                                  : Icons.location_searching,
                              color: _seguir ? tone.primaryDark : null,
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
