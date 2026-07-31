import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Banco recien dado de alta en el catalogo: id asignado y nombre guardado.
typedef BancoCatalogo = ({int id, String nombre});

/// Perfil del cliente: datos personales, fiscales, cuentas bancarias y avatar.
///
/// Igual que los demas puertos de `client`, la instancia ya sabe de que cliente se trata.
/// Todos los metodos lanzan [ApiError].
abstract interface class ProfilePort {
  /// Perfil completo del cliente.
  Future<ClientePerfil> profile();

  /// Catalogos para editar el perfil: regimen fiscal, uso de CFDI y bancos.
  Future<PerfilCatalogos> catalogs();

  /// Actualiza los datos personales del cliente.
  Future<void> updatePersonalData({
    required String legalName,
    String? rfc,
    String? curp,
    String? phoneCountryCode,
    String? phone,
    String? occupation,
  });

  /// Actualiza el regimen fiscal, el uso de CFDI y la direccion fiscal.
  Future<void> updateTaxData({
    String? regime,
    String? cfdiUse,
    String? postalCode,
    String? street,
    String? exteriorNumber,
    String? interiorNumber,
    String? neighborhood,
  });

  /// Alta de cuenta bancaria de dispersion. `accountNumber` (8-34 digitos) es la
  /// clave; CLABE/SWIFT son opcionales y `evidence*` es la caratula del estado
  /// de cuenta.
  Future<void> addBankAccount({
    required int bankId,
    required String accountNumber,
    required String holder,
    String? clabe,
    String? swift,
    String? evidenceBase64,
    String? evidenceFileName,
    String? evidenceContentType,
  });

  /// Edicion de una cuenta bancaria propia.
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
  });

  /// Agrega un banco al catalogo; el backend deduplica por nombre.
  Future<BancoCatalogo> addBankToCatalog(String name);

  /// Sube la foto de perfil (`mime`, p.ej. image/jpeg) y devuelve su URL
  /// firmada; null si el backend no la regresa.
  Future<String?> uploadAvatar({required String base64, required String mime});

  /// Elimina la foto de perfil.
  Future<void> deleteAvatar();
}
