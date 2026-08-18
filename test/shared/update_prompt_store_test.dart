import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sozu_cliente_app/shared/providers/update_prompt_provider.dart';

/// La memoria del aviso es lo que separa "recordar" de "fastidiar". Las tres
/// reglas: sale la primera vez, callarlo dura UN dia, y una version posterior
/// vuelve a preguntar.
void main() {
  late UpdatePromptStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = UpdatePromptStore(await SharedPreferences.getInstance());
  });

  final hoy = DateTime(2026, 8, 17);
  final manana = DateTime(2026, 8, 18);

  test('sin memoria previa, sale', () {
    expect(store.shouldPrompt('1.0.5', today: hoy), isTrue);
  });

  test('posponer lo calla el MISMO dia', () async {
    await store.snooze('1.0.5', today: hoy);
    expect(store.shouldPrompt('1.0.5', today: hoy), isFalse);
  });

  test('al dia siguiente vuelve a salir', () async {
    // No se apaga para siempre: eso haria inutil el aviso.
    await store.snooze('1.0.5', today: hoy);
    expect(store.shouldPrompt('1.0.5', today: manana), isTrue);
  });

  test('una version POSTERIOR vuelve a preguntar el mismo dia', () async {
    // Posponer 1.0.5 no puede callar tambien a 1.0.6.
    await store.snooze('1.0.5', today: hoy);
    expect(store.shouldPrompt('1.0.6', today: hoy), isTrue);
  });

  test('la clave del dia es la fecha del calendario, no un plazo de 24 h', () {
    // Con un timestamp, "una vez al dia" se corre solo: quien pospone a las
    // 23:00 no vuelve a ver el aviso hasta las 23:00 del dia siguiente.
    expect(
      UpdatePromptStore.dayKey(DateTime(2026, 8, 7, 23, 59)),
      '2026-08-07',
    );
    expect(UpdatePromptStore.dayKey(DateTime(2026, 8, 8, 0, 1)), '2026-08-08');
  });
}
