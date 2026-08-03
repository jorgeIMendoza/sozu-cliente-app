import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/ports/admin_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [AdminPort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `adminPortProvider.overrideWithValue`.
class FakeAdminPort implements AdminPort {
  /// Fallo forzado de la PRÓXIMA operación; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los métodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  /// Avisos "existentes"; [createAnnouncement] agrega y [cancelAnnouncement]
  /// marca cancelado.
  final List<AvisoApp> avisos = [];

  String animacion = 'gol';
  int _nextId = 1;

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  static CatalogoItem _item(int id, String nombre) =>
      CatalogoItem.fromJson({'id': id, 'nombre': nombre});

  @override
  Future<AdminClientes> clients() async {
    _throwIfFailing('clients');
    return AdminClientes.fromJson({
      'clientes': [
        {'id_persona': 7, 'nombre': 'Alex Hernández', 'email': 'alex@x.com'},
        {'id_persona': 8, 'nombre': 'Bruno Pérez', 'email': 'bruno@x.com'},
      ],
    });
  }

  @override
  Future<List<AdminCliente>> owners({
    required int projectId,
    required String propertyNumber,
  }) async {
    _throwIfFailing('owners');
    if (projectId != 1 || propertyNumber != '101') return const [];
    return [
      AdminCliente.fromJson({
        'id_persona': 7,
        'nombre': 'Alex Hernández',
        'email': 'alex@x.com',
      }),
    ];
  }

  @override
  Future<List<CatalogoItem>> projectCatalog() async {
    _throwIfFailing('projectCatalog');
    return [_item(1, 'Toreo'), _item(2, 'Reforma')];
  }

  @override
  Future<List<CatalogoItem>> modelCatalog(List<int> projectIds) async {
    _throwIfFailing('modelCatalog');
    return [for (final p in projectIds) _item(p * 10, 'Modelo $p')];
  }

  @override
  Future<List<CatalogoItem>> levelCatalog(
    List<int> projectIds, {
    List<int> modelIds = const [],
  }) async {
    _throwIfFailing('levelCatalog');
    return [for (final p in projectIds) _item(p * 100, 'Nivel $p')];
  }

  @override
  Future<List<CatalogoItem>> propertyCatalog(
    List<int> projectIds, {
    List<int> modelIds = const [],
    List<int> levelIds = const [],
  }) async {
    _throwIfFailing('propertyCatalog');
    return [for (final p in projectIds) _item(p * 1000, '$p-101')];
  }

  @override
  Future<List<AvisoApp>> announcements() async {
    _throwIfFailing('announcements');
    return List.of(avisos);
  }

  @override
  Future<AvisoApp> createAnnouncement({
    required String title,
    required String message,
    required String type,
    required String category,
    required List<String> channels,
    List<int> projectIds = const [],
    List<int> modelIds = const [],
    List<int> levelIds = const [],
    List<int> propertyIds = const [],
    DateTime? scheduledFor,
  }) async {
    _throwIfFailing('createAnnouncement');
    final aviso = AvisoApp.fromJson({
      'id': _nextId++,
      'titulo': title,
      'mensaje': message,
      'tipo': type,
      'categoria': category,
      'canales': channels,
      'ids_proyectos': projectIds,
      'ids_modelos': modelIds,
      'ids_propiedades': propertyIds,
      'programado_para': scheduledFor?.toUtc().toIso8601String(),
      'estado': scheduledFor != null ? 'pendiente' : 'enviado',
    });
    avisos.add(aviso);
    return aviso;
  }

  @override
  Future<bool> cancelAnnouncement(int announcementId) async {
    _throwIfFailing('cancelAnnouncement');
    final i = avisos.indexWhere(
      (a) => a.id == announcementId && a.estado == 'pendiente',
    );
    if (i < 0) return false;
    avisos.removeAt(i);
    return true;
  }

  @override
  Future<String> bellAnimation() async {
    _throwIfFailing('bellAnimation');
    return animacion;
  }

  @override
  Future<void> setBellAnimation(String animation) async {
    _throwIfFailing('setBellAnimation');
    animacion = animation;
  }
}
