import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/profile/ports/profile_port.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Doble de [ProfilePort] con datos fijos en memoria: sin red, sin Supabase.
/// Se inyecta con `profilePortProvider.overrideWithValue`.
class FakeProfilePort implements ProfilePort {
  /// Fallo forzado de la PROXIMA operacion; se consume al usarse.
  ApiError? nextFailure;

  /// Nombres de los metodos llamados, en orden, para tests de secuencia.
  final List<String> log = [];

  String nombreLegal = 'Alex Hernández';

  void _throwIfFailing(String method) {
    log.add(method);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<ClientePerfil> profile() async {
    _throwIfFailing('profile');
    return ClientePerfil.fromJson({'nombre_legal': nombreLegal});
  }

  @override
  Future<PerfilCatalogos> catalogs() async {
    _throwIfFailing('catalogs');
    return PerfilCatalogos.fromJson({
      'bancos': [
        {'id': 1, 'nombre': 'BBVA'},
      ],
    });
  }

  @override
  Future<void> updatePersonalData({
    required String legalName,
    String? rfc,
    String? curp,
    String? phoneCountryCode,
    String? phone,
    String? occupation,
  }) async {
    _throwIfFailing('updatePersonalData');
    nombreLegal = legalName;
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
    _throwIfFailing('updateTaxData');
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
    _throwIfFailing('addBankAccount:$bankId');
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
    _throwIfFailing('updateBankAccount:$accountId');
  }

  @override
  Future<BancoCatalogo> addBankToCatalog(String name) async {
    _throwIfFailing('addBankToCatalog:$name');
    return (id: 99, nombre: name);
  }

  @override
  Future<String?> uploadAvatar({
    required String base64,
    required String mime,
  }) async {
    _throwIfFailing('uploadAvatar');
    return 'https://firmada/avatar.jpg';
  }

  @override
  Future<void> deleteAvatar() async {
    _throwIfFailing('deleteAvatar');
  }
}
