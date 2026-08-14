import 'package:flutter_dotenv/flutter_dotenv.dart';

/// De qué backend habla la app: `assets/env` por defecto, o lo que llegue por
/// `--dart-define` si viene.
///
/// El define GANA a propósito. `assets/env` apunta a producción, y probar un
/// cambio de edge function contra ella obliga a pasarlo por PR, `dev`, `main` y
/// deploy. Con `BACKEND=dev ./tool/dev.sh` la app corre contra el ambiente de
/// desarrollo sin editar el archivo, así que nadie se queda apuntando a DEV por
/// olvido ni commitea el de producción cambiado.
///
/// SEGURIDAD: aquí solo viven valores PÚBLICOS (URL y llave anónima). El
/// `service_role` no entra a este repo por ninguna vía.
const _urlDefine = String.fromEnvironment('SUPABASE_URL');
const _anonDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const _rolDefine = String.fromEnvironment('CLIENTE_ROL_ID');

String _leer(String define, String clave) =>
    define.isNotEmpty ? define : (dotenv.env[clave] ?? '');

/// URL del proyecto de Supabase.
String get backendUrl => _leer(_urlDefine, 'SUPABASE_URL');

/// Llave anónima (pública) del proyecto.
String get backendAnonKey => _leer(_anonDefine, 'SUPABASE_ANON_KEY');

/// Override del `roles.id` que gatea el acceso al portal. Vacío = el de código.
String get backendClienteRolId => _leer(_rolDefine, 'CLIENTE_ROL_ID');

/// true si la app NO habla con producción. Solo para avisos en pantalla.
bool get esBackendAlterno => _urlDefine.isNotEmpty;
