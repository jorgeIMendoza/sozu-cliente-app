import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Llamada cruda a una Edge Function SIN sesion, para las pantallas de acceso
/// (recuperar contrasena, reenviar confirmacion). Vive en la capa de
/// adaptadores porque conoce el backend (URL del proyecto, llave anonima,
/// forma de la respuesta); los puertos y la UI no la ven.

/// Respuesta cruda de una Edge Function llamada sin sesion.
typedef AnonFunctionResponse = ({int status, Map<String, dynamic> body});

/// Invoca la Edge Function [fn] con la llave anonima en el header `apikey`.
///
/// No usa `functions.invoke` a proposito, por dos motivos:
///  1. `invoke` manda la llave anonima en `apikey` Y en `Authorization`. El
///     gateway nuevo de Supabase (llaves `sb_`) compara los dos headers y
///     responde 401 "Conflicting API keys" ANTES de ejecutar la funcion.
///  2. Las funciones de acceso solo entran en su "modo publico" (self-service,
///     anti-enumeracion de correos) cuando NO reciben `Authorization`: con ese
///     header intentan resolver un usuario autenticado y rechazan la peticion.
///
/// [withAuthorization] repite la llave en `Authorization: Bearer`, y hace falta
/// para las functions que NO estan declaradas publicas en `config.toml`
/// (`verify_jwt = true`): a esas el gateway les responde 401 si solo reciben
/// `apikey`. Va apagado por default porque romperia el motivo 2.
///
/// Nunca lanza por status != 2xx: devuelve status + cuerpo para que decida el
/// llamador (el adaptador traduce a `AuthError`/`ApiError` segun su contrato).
/// Si no hay red, propaga la excepcion de [http.post].
///
/// [client] solo lo usan los tests, para fijar que headers sale cada llamada
/// sin tocar red; en produccion siempre es null.
Future<AnonFunctionResponse> invokeAnonFunction(
  String fn, {
  Map<String, dynamic> body = const {},
  bool withAuthorization = false,
  http.Client? client,
}) async {
  final baseUrl = (dotenv.env['SUPABASE_URL'] ?? '').replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  final uri = Uri.parse('$baseUrl/functions/v1/$fn');
  final headers = {
    'Content-Type': 'application/json',
    'apikey': anonKey,
    if (withAuthorization) 'Authorization': 'Bearer $anonKey',
  };
  final payload = jsonEncode(body);
  final res = client == null
      ? await http.post(uri, headers: headers, body: payload)
      : await client.post(uri, headers: headers, body: payload);
  var parsed = const <String, dynamic>{};
  try {
    final decoded = jsonDecode(res.body);
    if (decoded is Map) parsed = Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Cuerpo no-JSON (p.ej. HTML de error del gateway): se ignora.
  }
  return (status: res.statusCode, body: parsed);
}
