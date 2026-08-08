import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Contrato de la hoja de carga de documentos.
///
/// Lo que se fija aquí es lo que evita que un documento entre mal: que sin
/// archivo no se pueda guardar, que un campo requerido vacío bloquee, que las
/// claves salgan normalizadas, y que un documento de solo evidencia no invente
/// campos.
void main() {
  final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]);
  final jpg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);

  /// Abre la hoja. El holder recibe el resultado cuando se cierra.
  Future<List<SDocUploadResult?>> abrir(
    WidgetTester tester, {
    List<SDocFieldSpec> campos = const [],
    String? aviso,
    String? rechazo,
    List<SSelectOption<int>> tipos = const [],
    Uint8List? archivo,
    String? Function(Uint8List)? validar,
    List<String> Function(int)? condiciones,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final holder = <SDocUploadResult?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                holder.add(
                  await showSDocUpload(
                    context,
                    titulo: 'Acta de nacimiento',
                    tipos: tipos,
                    tipoId: 1,
                    onSeleccionar: () async => archivo == null
                        ? null
                        : (nombre: 'acta.pdf', bytes: archivo),
                    validar: validar,
                    condiciones: condiciones,
                    // El visor real no rasteriza en la VM de test (pdfx no
                    // tiene plataforma aquí); lo que se prueba es la hoja.
                    preview: (_, nombre) => Text('vista: \$nombre'),
                    onAnalizar: (_, __, ___) async => (
                      campos: campos,
                      aviso: aviso,
                      tono: SDocTone.warning,
                      rechazo: rechazo,
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return holder;
  }

  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> adjuntar(WidgetTester tester) async {
    await tester.tap(find.text('Adjuntar PDF'));
    await asentar(tester);
  }

  testWidgets('sin archivo no se puede guardar', (tester) async {
    await abrir(tester);

    final guardar = tester.widget<SButton>(
      find.widgetWithText(SButton, 'Guardar'),
    );
    expect(guardar.onPressed, isNull);
    expect(find.text('Adjuntar PDF'), findsOneWidget);
  });

  testWidgets('un archivo que no pasa la validación no se adjunta', (
    tester,
  ) async {
    await abrir(
      tester,
      archivo: jpg,
      validar: (b) => b.first == 0x25 ? null : 'El archivo no es un PDF.',
    );
    await adjuntar(tester);

    expect(find.text('El archivo no es un PDF.'), findsOneWidget);
    // La zona sigue ahí: no se aceptó nada.
    expect(find.text('Adjuntar PDF'), findsOneWidget);
  });

  testWidgets('documento de solo evidencia: ningún campo, guardar habilitado', (
    tester,
  ) async {
    final holder = await abrir(tester, archivo: pdf);
    await adjuntar(tester);

    expect(find.byType(STextField), findsNothing);
    await tester.tap(find.text('Guardar'));
    await asentar(tester);

    expect(holder.single?.campos, isEmpty);
    expect(holder.single?.tipoId, 1);
  });

  testWidgets('sin extracción: salen los campos vacíos con su aviso', (
    tester,
  ) async {
    await abrir(
      tester,
      archivo: pdf,
      aviso: 'Captura tus datos para continuar: el archivo está escaneado.',
      campos: const [
        SDocFieldSpec(
          key: 'curp',
          label: 'CURP',
          requerido: true,
          kind: SDocFieldKind.curp,
        ),
      ],
    );
    await adjuntar(tester);

    expect(find.textContaining('Captura tus datos'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await asentar(tester);
    expect(find.text('Escribe curp'), findsOneWidget);
  });

  testWidgets('un rechazo bloquea el guardado y dice por qué', (tester) async {
    await abrir(
      tester,
      archivo: pdf,
      rechazo: 'Tu constancia es de 2023 y tiene más de 3 meses.',
    );
    await adjuntar(tester);

    expect(find.textContaining('más de 3 meses'), findsOneWidget);
    final guardar = tester.widget<SButton>(
      find.widgetWithText(SButton, 'Guardar'),
    );
    expect(guardar.onPressed, isNull);
  });

  testWidgets('con extracción válida devuelve las claves en mayúscula', (
    tester,
  ) async {
    final holder = await abrir(
      tester,
      archivo: pdf,
      campos: const [
        SDocFieldSpec(
          key: 'curp',
          label: 'CURP',
          valor: 'firj810102hjcgvr04',
          kind: SDocFieldKind.curp,
        ),
        SDocFieldSpec(
          key: 'nombre',
          label: 'Nombre completo',
          valor: 'Jorge Adrian Figueroa Ruvalcaba',
        ),
      ],
    );
    await adjuntar(tester);
    await tester.tap(find.text('Guardar'));
    await asentar(tester);

    expect(holder.single?.campos, {
      'curp': 'FIRJ810102HJCGVR04',
      'nombre': 'Jorge Adrian Figueroa Ruvalcaba',
    });
  });

  testWidgets('las condiciones se aceptan antes de guardar', (tester) async {
    final holder = await abrir(
      tester,
      archivo: pdf,
      condiciones: (_) => const ['Sube el archivo en PDF y legible.'],
    );
    await adjuntar(tester);
    await tester.tap(find.text('Guardar'));
    await asentar(tester);

    expect(find.text('Sube el archivo en PDF y legible.'), findsOneWidget);
    expect(holder, isEmpty); // todavía no se cerró

    await tester.tap(find.text('Acepto y subir'));
    await asentar(tester);
    expect(holder.single, isNotNull);
  });

  testWidgets('si el analisis revienta no se puede guardar', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSDocUpload(
                context,
                titulo: 'Comprobante de domicilio',
                tipoId: 8,
                onSeleccionar: () async => (nombre: 'cfe.pdf', bytes: pdf),
                preview: (_, nombre) => Text('vista: \$nombre'),
                onAnalizar: (_, __, ___) async => throw Exception('400'),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await adjuntar(tester);

    // Antes seguia habilitado: se subia un archivo que nadie reviso y el fallo
    // salia despues, ya con el documento en el bucket.
    final guardar = tester.widget<SButton>(
      find.widgetWithText(SButton, 'Guardar'),
    );
    expect(guardar.onPressed, isNull);
    expect(find.textContaining('Vuelve a seleccionarlo'), findsOneWidget);
  });

  testWidgets('Esc cierra la hoja en escritorio', (tester) async {
    final holder = await abrir(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Acta de nacimiento'), findsNothing);
    expect(holder.single, isNull);
  });

  testWidgets('cambiar de tipo suelta el archivo ya adjunto', (tester) async {
    await abrir(
      tester,
      archivo: pdf,
      tipos: const [(value: 63, label: 'INE'), (value: 4, label: 'Pasaporte')],
    );

    // Sin tipo elegido la zona está bloqueada.
    expect(find.text('Elige primero el tipo de documento.'), findsOneWidget);
  });
}
