import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sozu_cliente_app/shared/adapters/app_version_adapter.dart';
import 'package:sozu_cliente_app/shared/api_error.dart';

/// Este archivo existe por un fallo concreto: la 1.0.3 llamaba a
/// `cliente-app-version` sin `Authorization`, el gateway respondia 401 antes de
/// ejecutar la function y el version gate quedaba MUDO - ni aviso ni forzado -
/// sin ninguna senal, porque el provider degrada a null ante cualquier error.
///
/// Lo que se fija aqui son los HEADERS de la llamada, no la logica del gate
/// (esa vive en version_gate_test.dart): la function no esta declarada publica
/// en `config.toml`, asi que con solo `apikey` el gateway responde 401.
void main() {
  setUp(() {
    dotenv.testLoad(
      fileInput:
          'SUPABASE_URL=https://proyecto.supabase.co\n'
          'SUPABASE_ANON_KEY=llave-anonima',
    );
  });

  test(
    'manda apikey Y Authorization: sin el segundo el gateway da 401',
    () async {
      late http.Request enviada;
      final adapter = AppVersionAdapter(
        client: MockClient((req) async {
          enviada = req;
          return http.Response(
            jsonEncode({'min_version': '1.0.0', 'latest_version': '1.0.4'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final info = await adapter.version();

      expect(enviada.headers['apikey'], 'llave-anonima');
      expect(enviada.headers['Authorization'], 'Bearer llave-anonima');
      expect(
        enviada.url.toString(),
        'https://proyecto.supabase.co/functions/v1/cliente-app-version',
      );
      expect(info.latestVersion, '1.0.4');
    },
  );

  test('un 401 del gateway sale como ApiError, no como info vacia', () async {
    final adapter = AppVersionAdapter(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'UNAUTHORIZED_NO_AUTH_HEADER'}),
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    // Importa que LANCE: un AppVersionInfo vacio se veria igual que "no hay
    // version nueva" y el fallo volveria a pasar desapercibido.
    await expectLater(
      adapter.version(),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
    );
  });
}
