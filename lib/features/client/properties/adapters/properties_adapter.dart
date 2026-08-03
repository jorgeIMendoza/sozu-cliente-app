import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/properties/ports/properties_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [PropertiesPort] sobre Supabase (edge functions
/// cliente-propiedades, cliente-propiedad-detalle, cliente-pagos,
/// cliente-estado-cuenta[-pdf], cliente-datos-pago, cliente-recibo-pago y
/// cliente-pago-final).
class PropertiesAdapter implements PropertiesPort {
  /// Cliente que se esta viendo cuando un super admin impersona; null = el propio.
  final int? impersonate;

  const PropertiesAdapter({this.impersonate});

  /// Getter perezoso a proposito: construir el adaptador no toca el singleton
  /// de Supabase, asi el provider puede crearlo antes de `Supabase.initialize`.
  SupabaseClient get _sb => Supabase.instance.client;

  /// Invoca una edge function con el JWT del usuario (y la cabecera de
  /// impersonacion si aplica) y normaliza cualquier fallo a [ApiError].
  Future<Map<String, dynamic>> _invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _sb.functions.invoke(
        fn,
        body: body ?? {},
        headers: impersonate != null
            ? {'x-impersonate-id-persona': '$impersonate'}
            : null,
      );
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

  /// Extrae `res['url']` cuando es una URL no vacia; null en cualquier otro caso.
  static String? _url(Map<String, dynamic> res) {
    final url = res['url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  @override
  Future<ClientePropiedades> properties() async =>
      ClientePropiedades.fromJson(await _invoke('cliente-propiedades'));

  @override
  Future<PropiedadDetalle> property(int propertyId) async =>
      PropiedadDetalle.fromJson(
        await _invoke('cliente-propiedad-detalle', body: {'id': propertyId}),
      );

  @override
  Future<ClientePagos> payments() async =>
      ClientePagos.fromJson(await _invoke('cliente-pagos'));

  @override
  Future<EstadoCuenta> accountStatement(int accountId) async =>
      EstadoCuenta.fromJson(
        await _invoke('cliente-estado-cuenta', body: {'id': accountId}),
      );

  @override
  Future<String?> accountStatementPdfUrl(int accountId) async =>
      _url(await _invoke('cliente-estado-cuenta-pdf', body: {'id': accountId}));

  @override
  Future<DatosPago> paymentDetails(int agreementId) async => DatosPago.fromJson(
    await _invoke('cliente-datos-pago', body: {'id': agreementId}),
  );

  @override
  Future<String?> paymentReceiptUrl(int paymentId) async =>
      _url(await _invoke('cliente-recibo-pago', body: {'id': paymentId}));

  @override
  Future<List<BancoConvenio>> mortgageBanks() async {
    final res = await _invoke('cliente-pago-final', body: {'action': 'bancos'});
    return ((res['bancos'] as List?) ?? [])
        .map((e) => BancoConvenio.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<SolicitudCredito?> createMortgageApplication({
    required int accountId,
    required int bankId,
    double? creditAmount,
    int? termMonths,
  }) async {
    final res = await _invoke(
      'cliente-pago-final',
      body: {
        'action': 'crear_solicitud',
        'id': accountId,
        'id_banco': bankId,
        if (creditAmount != null) 'monto_credito': creditAmount,
        if (termMonths != null) 'plazo_meses': termMonths,
      },
    );
    return res['solicitud'] is Map
        ? SolicitudCredito.fromJson(
            Map<String, dynamic>.from(res['solicitud'] as Map),
          )
        : null;
  }

  @override
  Future<void> setFinalPaymentMethod({
    required int accountId,
    required String method,
    int? bankId,
  }) async {
    await _invoke(
      'cliente-pago-final',
      body: {
        'id': accountId,
        'metodo': method,
        if (bankId != null) 'id_banco': bankId,
      },
    );
  }
}
