import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/features/client/expediente/screens/persona_expediente_screen.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../client_test_support.dart';
import '../profile/fake_profile_port.dart';
import 'fake_expediente_port.dart';

/// El ciclo de beneficiario controlador: un accionista PERSONA MORAL repite el
/// expediente completo (sus documentos de empresa + su representante legal +
/// sus accionistas) y la rama solo se detiene al llegar a una persona fisica.
void main() {
  /// Expediente de una empresa: sus cuatro documentos y ninguna persona
  /// ligada todavia.
  final empresa = <String, dynamic>{
    'tipo_persona': 'pm',
    'contexto': 55,
    'nombre': 'Empresa Prueba',
    'umbral_accionista': 25,
    'personas': [],
    'grupos': [
      {'key': 'empresa', 'titulo': 'Documentos de la empresa', 'owner': 'self'},
    ],
    'slots': [
      {
        'key': 'csf_empresa',
        'tipo_id': 6,
        'nombre': 'Constancia de situación fiscal',
        'requerido': true,
        'grupo': 'empresa',
        'puede_subir': true,
      },
      {
        'key': 'acta_constitutiva',
        'tipo_id': 7,
        'nombre': 'Acta constitutiva',
        'requerido': true,
        'grupo': 'empresa',
        'puede_subir': true,
      },
    ],
  };

  Future<void> pump(
    WidgetTester tester, {
    required bool esMoral,
    required String rol,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 3000);
    addTearDown(tester.view.reset);

    final port = FakeExpedientePort()..expedienteJson = empresa;
    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [
            expedientePortProvider.overrideWithValue(port),
            // El perfil se lee para las cuentas bancarias; sin doble, su
            // esqueleto no termina de cargar y cuelga a pumpAndSettle.
            profilePortProvider.overrideWithValue(FakeProfilePort()),
          ],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          builder: (context, child) =>
              SozuAdaptiveTokens(child: child ?? const SizedBox()),
          home: PersonaExpedienteScreen(
            idPersona: 55,
            nombre: 'Empresa Prueba',
            rol: rol,
            esMoral: esMoral,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('un accionista PERSONA MORAL rehace el ciclo completo', (
    tester,
  ) async {
    await pump(tester, esMoral: true, rol: 'accionista');

    // Sus documentos de empresa, pero como tarjeta: la lista vive en su propia
    // pantalla, igual que en el titular.
    expect(find.text('Documentos de la empresa'), findsOneWidget);
    // Y la rama sigue: sus propias personas ligadas, con su alta.
    expect(find.text('REPRESENTANTE LEGAL'), findsOneWidget);
    expect(find.text('ACCIONISTAS CON MÁS DEL 25%'), findsOneWidget);
    expect(find.text('Agregar persona'), findsOneWidget);
  });

  testWidgets('un accionista PERSONA FISICA es donde se detiene la rama', (
    tester,
  ) async {
    await pump(tester, esMoral: false, rol: 'accionista');

    // Sus documentos, directo. Ni portada ni personas colgando de él.
    expect(find.text('Constancia de situación fiscal'), findsOneWidget);
    expect(find.text('REPRESENTANTE LEGAL'), findsNothing);
    expect(find.text('Agregar persona'), findsNothing);
  });

  testWidgets('la ficha de la empresa no repite el árbol', (tester) async {
    await pump(tester, esMoral: true, rol: 'empresa');

    expect(find.text('Acta constitutiva'), findsOneWidget);
    expect(find.text('REPRESENTANTE LEGAL'), findsNothing);
  });
}
