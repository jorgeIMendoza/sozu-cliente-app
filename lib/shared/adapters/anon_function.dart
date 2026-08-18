import 'dart:convert';

import 'package:sozu_cliente_app/core/backend_env.dart';
import 'package:http/http.dart' as http;

/// Llamada cruda a una Edge Function SIN sesion, para las pantallas de acceso
/// (recuperar contrasena, reenviar confirmacion). Vive en la capa de
/// adaptadores porque conoce el backend (URL del proyecto, llave anonima,
/// forma de la respuesta); los puertos y la UI no la ven.

/// Respuesta cruda de una Edge Function llamada sin sesion.
typedef AnonFunctionResponse = ({int status, Map<String, dynamic> body});

/// Invoca la Edge Function [fn] con la llave anonima en el header `apikey`.
/// Devuelve status + cuerpo sin lanzar; traducir el error es del llamador.
///
/// WARN: NO cambiar por `functions.invoke`. Manda la llave en `apikey` Y en
/// `Authorization`, y eso rompe dos cosas: el gateway nuevo responde 401
/// "Conflicting API keys", y las functions de acceso salen de su modo publico
/// (anti-enumeracion de correos) en cuanto ven `Authorization`.
///
/// [withAuthorization] repite la llave en `Authorization: Bearer` para las
/// functions con `verify_jwt = true`. Apagado por default: rompe lo anterior.
/// [client] solo lo usan los tests.
Future<AnonFunctionResponse> invokeAnonFunction(
  String fn, {
  Map<String, dynamic> body = const {},
  bool withAuthorization = false,
  http.Client? client,
}) async {
  // La URL y la llave salen de `backendUrl`/`backendAnonKey`, no de dotenv: asi
  // `BACKEND=dev ./tool/dev.sh` apunta esta llamada al ambiente de desarrollo
  // igual que al resto de la app.
  final baseUrl = backendUrl.replaceAll(RegExp(r'/+$'), '');
  final anonKey = backendAnonKey;
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
