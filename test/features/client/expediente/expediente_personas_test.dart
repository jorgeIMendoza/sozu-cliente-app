import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/client/expediente/components/expediente_personas.dart';
import 'package:sozu_cliente_app/features/client/expediente/providers/expediente_providers.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

import '../client_test_support.dart';
import 'fake_expediente_port.dart';

/// Contrato del alta de personas ligadas (representante legal y accionistas).
///
/// Lo que se fija aqui: que con nombre, correo y telefono basta (ningun
/// documento en el alta), que los porcentajes de los accionistas no pueden
/// sumar mas de 100, y que el titulo de cada seccion se ve aunque este vacia.
void main() {
  ExpedientePersona accionista(String nombre, double pct) =>
      ExpedientePersona.recienCreada(
        idPersona: nombre.hashCode,
        nombre: nombre,
        tipoPersona: 'pf',
        rol: 'accionista',
        porcentaje: pct,
      );

  Future<FakeExpedientePort> montar(
    WidgetTester tester, {
    List<ExpedientePersona> personas = const [],
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final port = FakeExpedientePort();
    await tester.pumpWidget(
      ProviderScope(
        overrides: clientWidgetOverrides(
          overrides: [expedientePortProvider.overrideWithValue(port)],
        ),
        child: MaterialApp(
          theme: sozuLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpedientePersonas(
                personas: personas,
                contexto: 7,
                umbral: 25,
                onAbrir: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return port;
  }

  /// Llena los campos de texto de la hoja EN ORDEN: nombre, correo, telefono
  /// y, si el rol es accionista, el porcentaje. Se va por posicion porque la
  /// etiqueta del sistema es un `Text` aparte, no el label del campo.
  Future<void> llenar(WidgetTester tester, List<String> valores) async {
    for (var i = 0; i < valores.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), valores[i]);
    }
    await tester.pump();
  }

  testWidgets('los dos titulos se ven aunque no haya nadie registrado', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('REPRESENTANTE LEGAL'), findsOneWidget);
    expect(find.text('ACCIONISTAS CON MÁS DEL 25%'), findsOneWidget);
  });

  testWidgets('el alta pide datos, no documentos', (tester) async {
    final port = await montar(tester);

    await tester.tap(find.text('Agregar persona'));
    await tester.pumpAndSettle();

    // Ni zona de carga ni previsualizacion: los documentos van despues.
    expect(find.textContaining('Vista previa'), findsNothing);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);

    await llenar(tester, ['Ana Pérez López', 'ana@correo.com', '5512345678']);
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(port.altas.single['rol'], 'representante');
    expect(port.altas.single['correo'], 'ana@correo.com');
    expect(port.altas.single['telefono'], '5512345678');
    // Tras el alta se ofrece subir su documentacion, que es lo que sigue.
    expect(find.textContaining('Completa su información'), findsOneWidget);
  });

  testWidgets('los porcentajes de los accionistas no pasan del 100%', (
    tester,
  ) async {
    final port = await montar(
      tester,
      personas: [accionista('Grupo A', 60), accionista('Grupo B', 25)],
    );

    expect(find.text('Registrado: 85% · disponible: 15%'), findsOneWidget);

    await tester.tap(find.text('Agregar persona'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Representante legal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accionista mayoritario').last);
    await tester.pumpAndSettle();

    await llenar(tester, ['Grupo C', 'c@correo.com', '5512345678', '30']);
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Solo quedan 15% por repartir'), findsOneWidget);
    expect(port.altas, isEmpty);
  });
}
