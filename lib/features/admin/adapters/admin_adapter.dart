import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/admin/ports/admin_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion actual de [AdminPort] sobre Supabase (edge functions
/// admin-clientes y admin-avisos-app): la unica frontera de la feature donde
/// se conocen sus tipos. Si el backend cambia, se reescribe este archivo y
/// nada mas.
class AdminAdapter implements AdminPort {
  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca una edge function con el JWT del usuario y normaliza cualquier
  /// fallo a [ApiError]. Sin cabecera de impersonacion: el admin actua
  /// siempre con su propia identidad.
  Future<Map<String, dynamic>> _invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(fn, body: body ?? {});
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiError(500, 'empty_response');
    } on FunctionException catch (e) {
      var code = 'internal_error';
      final details = e.details;
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      throw ApiError(e.status, code);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, 'network_error');
    }
  }

  static List<CatalogoItem> _catalog(Map<String, dynamic> res, String key) =>
      ((res[key] as List?) ?? [])
          .map((e) => CatalogoItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  @override
  Future<AdminClientes> clients() async =>
      AdminClientes.fromJson(await _invoke('admin-clientes'));

  @override
  Future<AdminClientes> searchClients({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async => AdminClientes.fromJson(
    await _invoke(
      'admin-clientes',
      body: {
        'action': 'buscar',
        'q': query,
        'limite': limit,
        'desplazamiento': offset,
      },
    ),
  );

  /// Con un backend sin action=propietarios la respuesta trae {clientes} y
  /// esto devuelve lista vacia (degrada sin romperse), como pide el puerto.
  @override
  Future<List<AdminCliente>> owners({
    required int projectId,
    required String propertyNumber,
  }) async {
    final res = await _invoke(
      'admin-clientes',
      body: {
        'action': 'propietarios',
        'id_proyecto': projectId,
        'numero_propiedad': propertyNumber,
      },
    );
    return ((res['propietarios'] as List?) ?? [])
        .map((e) => AdminCliente.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<CatalogoItem>> projectCatalog() async => _catalog(
    await _invoke('admin-avisos-app', body: {'action': 'catalogos'}),
    'proyectos',
  );

  @override
  Future<List<CatalogoItem>> modelCatalog(List<int> projectIds) async =>
      _catalog(
        await _invoke(
          'admin-avisos-app',
          body: {'action': 'modelos', 'ids_proyectos': projectIds},
        ),
        'modelos',
      );

  @override
  Future<List<CatalogoItem>> levelCatalog(
    List<int> projectIds, {
    List<int> modelIds = const [],
  }) async => _catalog(
    await _invoke(
      'admin-avisos-app',
      body: {
        'action': 'niveles',
        'ids_proyectos': projectIds,
        if (modelIds.isNotEmpty) 'ids_modelos': modelIds,
      },
    ),
    'niveles',
  );

  @override
  Future<List<CatalogoItem>> propertyCatalog(
    List<int> projectIds, {
    List<int> modelIds = const [],
    List<int> levelIds = const [],
  }) async => _catalog(
    await _invoke(
      'admin-avisos-app',
      body: {
        'action': 'propiedades',
        'ids_proyectos': projectIds,
        if (modelIds.isNotEmpty) 'ids_modelos': modelIds,
        if (levelIds.isNotEmpty) 'ids_niveles': levelIds,
      },
    ),
    'propiedades',
  );

  @override
  Future<List<AvisoApp>> announcements() async {
    final res = await _invoke('admin-avisos-app', body: {'action': 'listar'});
    return ((res['avisos'] as List?) ?? [])
        .map((e) => AvisoApp.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    final res = await _invoke(
      'admin-avisos-app',
      body: {
        'action': 'crear',
        'titulo': title,
        'mensaje': message,
        'tipo': type,
        'categoria': category,
        'canales': channels,
        if (projectIds.isNotEmpty) 'ids_proyectos': projectIds,
        if (modelIds.isNotEmpty) 'ids_modelos': modelIds,
        if (levelIds.isNotEmpty) 'ids_niveles': levelIds,
        if (propertyIds.isNotEmpty) 'ids_propiedades': propertyIds,
        if (scheduledFor != null)
          'programado_para': scheduledFor.toUtc().toIso8601String(),
      },
    );
    return AvisoApp.fromJson(Map<String, dynamic>.from(res['aviso'] as Map));
  }

  @override
  Future<bool> cancelAnnouncement(int announcementId) async {
    final res = await _invoke(
      'admin-avisos-app',
      body: {'action': 'cancelar', 'id': announcementId},
    );
    return res['cancelado'] == true;
  }

  @override
  Future<String> bellAnimation() async {
    final res = await _invoke(
      'admin-avisos-app',
      body: {'action': 'config_get'},
    );
    return (res['animacion_campana'] as String?) ?? 'gol';
  }

  @override
  Future<void> setBellAnimation(String animation) async {
    await _invoke(
      'admin-avisos-app',
      body: {'action': 'config_set', 'animacion_campana': animation},
    );
  }
}
