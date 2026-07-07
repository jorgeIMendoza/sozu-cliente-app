# Proyecto: SOZU — Portal del Cliente (app Flutter multiplataforma)

Port 1:1 del app RN (`../sozu-cliente-rn-app`). Misma funcionalidad, mismo
backend (Edge Functions en admin_sozu). Código compartido en `lib/`;
plataformas: `android/`, `ios/` (build requiere Mac), `web/` (target principal
de prueba: Chrome).

## Stack
- Flutter stable (SDK en C:\dev\flutter) + Dart. Material 3.
- Estado/datos: flutter_riverpod (FutureProvider por endpoint).
- Navegación: go_router (guards de sesión + cambio de contraseña forzado,
  StatefulShellRoute con 5 tabs).
- Backend: supabase_flutter (Auth + functions.invoke + RPC).
- Sesión/tokens: flutter_secure_storage vía `SecureSessionStorage`
  (lib/core/secure_session_storage.dart). NUNCA SharedPreferences para tokens.
  Caveat web: cae al storage del navegador (limitación de plataforma).
- Env: flutter_dotenv (.env gitignored; ver .env.example).
- Formato: intl (MXN 2 decimales, fechas DD/MM/YYYY).
- Versión (misma metodología que sozu-admin): `vX.Y.Z-YYMMDD.HHMM` en el footer
  del login, definida en lib/core/version.dart. En cada build/entrega actualizar
  `_buildTimestampDefault` (PowerShell: `Get-Date -Format "yyMMdd.HHmm"`) o
  compilar con `--dart-define=BUILD_TIMESTAMP=...`.

## Ejecuciones manuales (SQL / deploys de Edge Functions)
- PROHIBIDO ejecutar SQL o `supabase functions deploy` directo desde aquí.
- Todo cambio de BD/deploy va primero a un `.md` en `Ejecuciones_manuales/`
  (gitignored; patrón de admin-sozu/sozu-admin: secciones fechadas + comandos
  exactos). Jorge lo ejecuta a mano y reporta.

## Reglas de SEGURIDAD (innegociables — mismas que el app RN)
- SOLO Supabase ANON KEY (pública) + JWT del usuario logueado.
- NUNCA service_role ni credenciales de BD en el código.
- CERO queries a tablas: todo dato sensible vía Edge Functions
  (cliente-resumen, cliente-pagos, cliente-propiedades,
  cliente-propiedad-detalle, cliente-perfil, cliente-documentos,
  cliente-notificaciones) + 2 RPC SECURITY DEFINER
  (get_current_user_profile, mark_password_changed).
- No loguear PII (RFC, CURP, CLABE, montos).
- Documentos/recibos/CEP: URLs firmadas temporales que entrega el backend.

## Estructura lib/
- core/: theme (tokens SOZU), format, secure_session_storage, open_doc
- data/: models (DTOs de las 7 functions), api_client (invoke + ApiError)
- providers/: auth (sesión+perfil+password flows), data (FutureProviders), theme
- router.dart: guards + shell 5 tabs + secundarias
- widgets/: common (AppCard/Badge/Avatar/ProgressBar/Skeleton), property_card,
  portal_top_bar, level_map (CustomPaint regiones), password_rules
- screens/: login, forgot, change_password_forced, inicio, adquisicion,
  patrimonio, documentos, perfil, pagos, estado_cuenta, pagar (placeholder),
  notificaciones, cambiar_password, propiedad_detalle

## Correr
- Web (principal): `flutter run -d chrome`
- Android: requiere Android SDK (no instalado aún).
- iOS: requiere Mac/Xcode; la carpeta ios/ queda lista.

## Reglas de código
- La versión WEB debe ser RESPONSIVE (móvil/tablet/desktop): contenido con
  max-width centrado en pantallas anchas (WebFrame), FittedBox/Wrap para
  cifras. Probar en Chrome ancho + ventana angosta + iPhone Safari.
- Cada pantalla maneja carga (skeleton) / vacío / error+reintentar y
  pull-to-refresh.
- Fechas DD/MM/YYYY; moneda $9,324,282.24; compacto $2.46M.
- Este repo es SOLO FRONTEND. El backend vive en otros repos:
  - Edge Functions (incluidas las cliente-*): Escritorio/admin-sozu/sozu-edge-functions
    (CI: rama dev → deploy DEV; PR dev→main → deploy PRD a admin_sozu).
  - Migraciones SQL: Escritorio/admin-sozu/sozu-supabase-migrations.
  - ../sozu-cliente-rn-app/supabase/functions es copia legacy, NO fuente de verdad.
