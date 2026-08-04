import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/profile/ports/profile_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Implementacion de [ProfilePort] sobre Supabase (edge function
/// cliente-perfil y sus acciones).
class ProfileAdapter implements ProfilePort {
  /// Cliente que se esta viendo cuando un super admin impersona; null = el propio.
  final int? impersonate;

  const ProfileAdapter({this.impersonate});

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

  /// Body de alta/edicion de cuenta bancaria (comparten forma salvo `id`).
  static Map<String, dynamic> _accountBody({
    required String action,
    int? id,
    required int bankId,
    required String accountNumber,
    required String holder,
    String? clabe,
    String? swift,
    String? evidenceBase64,
    String? evidenceFileName,
    String? evidenceContentType,
  }) => {
    'action': action,
    if (id != null) 'id': id,
    'id_banco': bankId,
    'numero_cuenta': accountNumber,
    if (clabe != null && clabe.isNotEmpty) 'cuenta_clabe': clabe,
    if (swift != null && swift.isNotEmpty) 'cuenta_swift': swift,
    'titular': holder,
    if (evidenceBase64 != null) 'evidencia_base64': evidenceBase64,
    if (evidenceFileName != null) 'evidencia_nombre': evidenceFileName,
    if (evidenceContentType != null)
      'evidencia_content_type': evidenceContentType,
  };

  @override
  Future<ClientePerfil> profile() async =>
      ClientePerfil.fromJson(await _invoke('cliente-perfil'));

  @override
  Future<PerfilCatalogos> catalogs() async => PerfilCatalogos.fromJson(
    await _invoke('cliente-perfil', body: {'action': 'catalogos'}),
  );

  @override
  Future<void> updatePersonalData({
    required String legalName,
    String? rfc,
    String? curp,
    String? phoneCountryCode,
    String? phone,
    String? occupation,
  }) async {
    await _invoke(
      'cliente-perfil',
      body: {
        'action': 'update_personal',
        'nombre_legal': legalName,
        'rfc': rfc,
        'curp': curp,
        'clave_pais_telefono': phoneCountryCode,
        'telefono': phone,
        'ocupacion': occupation,
      },
    );
  }

  @override
  Future<void> updateTaxData({
    String? regime,
    String? cfdiUse,
    String? postalCode,
    String? street,
    String? exteriorNumber,
    String? interiorNumber,
    String? neighborhood,
  }) async {
    await _invoke(
      'cliente-perfil',
      body: {
        'action': 'update_fiscal',
        'regimen': regime,
        'uso_cfdi': cfdiUse,
        'codigo_postal': postalCode,
        'calle': street,
        'num_ext': exteriorNumber,
        'num_int': interiorNumber,
        'colonia': neighborhood,
      },
    );
  }

  @override
  Future<void> addBankAccount({
    required int bankId,
    required String accountNumber,
    required String holder,
    String? clabe,
    String? swift,
    String? evidenceBase64,
    String? evidenceFileName,
    String? evidenceContentType,
  }) async {
    await _invoke(
      'cliente-perfil',
      body: _accountBody(
        action: 'cuenta_add',
        bankId: bankId,
        accountNumber: accountNumber,
        holder: holder,
        clabe: clabe,
        swift: swift,
        evidenceBase64: evidenceBase64,
        evidenceFileName: evidenceFileName,
        evidenceContentType: evidenceContentType,
      ),
    );
  }

  @override
  Future<void> updateBankAccount({
    required int accountId,
    required int bankId,
    required String accountNumber,
    required String holder,
    String? clabe,
    String? swift,
    String? evidenceBase64,
    String? evidenceFileName,
    String? evidenceContentType,
  }) async {
    await _invoke(
      'cliente-perfil',
      body: _accountBody(
        action: 'cuenta_update',
        id: accountId,
        bankId: bankId,
        accountNumber: accountNumber,
        holder: holder,
        clabe: clabe,
        swift: swift,
        evidenceBase64: evidenceBase64,
        evidenceFileName: evidenceFileName,
        evidenceContentType: evidenceContentType,
      ),
    );
  }

  @override
  Future<BancoCatalogo> addBankToCatalog(String name) async {
    final res = await _invoke(
      'cliente-perfil',
      body: {'action': 'banco_add', 'nombre': name},
    );
    return (id: asInt(res['id']), nombre: asString(res['nombre'], name));
  }

  @override
  Future<String?> uploadAvatar({
    required String base64,
    required String mime,
  }) async {
    final res = await _invoke(
      'cliente-perfil',
      body: {'action': 'avatar_upload', 'base64': base64, 'mime': mime},
    );
    final url = res['foto_perfil_url'];
    return url is String && url.isNotEmpty ? url : null;
  }

  @override
  Future<void> deleteAvatar() async {
    await _invoke('cliente-perfil', body: {'action': 'avatar_delete'});
  }
}
