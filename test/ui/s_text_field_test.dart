import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/primitives/s_text_field.dart';
import 'package:sozu_cliente_app/ui/theme/theme_data.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Contrato del campo de texto global.
///
/// Lo que se fija aquí es lo que distingue a este campo de un `TextFormField`
/// pelón: que la señal de estado vive en el BORDE (no en un relleno gris), que
/// el error del backend gana sobre el validator local, que la etiqueta no
/// flota, y que el ojo de la contraseña no es responsabilidad de la pantalla.
void main() {
  Future<void> pumpField(WidgetTester tester, Widget field) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: sozuLightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 400, child: field),
          ),
        ),
      ),
    );
  }

  /// Decoración realmente pintada. Se lee del `Container` interno y no del
  /// `AnimatedContainer` porque el widget externo guarda el valor DESTINO: leerlo
  /// daría el color final aunque la animación no haya corrido.
  BoxDecoration paintedBox(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AnimatedContainer),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  Color borderColor(WidgetTester tester) =>
      paintedBox(tester).border!.top.color;

  const light = SozuColorRoles.light;

  testWidgets('el borde se tiñe de primary al enfocar', (tester) async {
    await pumpField(
      tester,
      STextField(controller: TextEditingController(), label: 'Correo'),
    );

    expect(
      borderColor(tester),
      light.border,
      reason: 'en reposo el borde es el neutro estándar',
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(borderColor(tester), light.primary);
    expect(
      paintedBox(tester).boxShadow,
      isNotEmpty,
      reason: 'el anillo de foco acompaña al borde teñido',
    );
  });

  testWidgets('errorText pinta el borde danger y muestra el mensaje', (
    tester,
  ) async {
    await pumpField(
      tester,
      STextField(
        controller: TextEditingController(),
        label: 'Correo',
        errorText: 'Credenciales inválidas',
      ),
    );
    await tester.pumpAndSettle();

    expect(borderColor(tester), light.danger);
    expect(find.text('Credenciales inválidas'), findsOneWidget);
  });

  testWidgets('el error se muestra sin esperar un Form.validate()', (
    tester,
  ) async {
    // Es el caso del error que viene del backend: no hay validación local que
    // dispararlo.
    await pumpField(
      tester,
      Form(
        child: STextField(
          controller: TextEditingController(),
          errorText: 'La contraseña no coincide',
        ),
      ),
    );

    expect(find.text('La contraseña no coincide'), findsOneWidget);
  });

  testWidgets('errorText gana sobre el validator', (tester) async {
    final formKey = GlobalKey<FormState>();
    await pumpField(
      tester,
      Form(
        key: formKey,
        child: STextField(
          controller: TextEditingController(),
          errorText: 'Error del servidor',
          validator: (_) => 'Error del validator',
        ),
      ),
    );

    // Incluso forzando la validación, el validator local no puede tapar el
    // mensaje explícito.
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text('Error del servidor'), findsOneWidget);
    expect(find.text('Error del validator'), findsNothing);
  });

  testWidgets('sin errorText, el validator sí pinta el error', (tester) async {
    final formKey = GlobalKey<FormState>();
    await pumpField(
      tester,
      Form(
        key: formKey,
        child: STextField(
          controller: TextEditingController(),
          validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
        ),
      ),
    );

    expect(borderColor(tester), light.border);

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();

    expect(find.text('Requerido'), findsOneWidget);
    expect(borderColor(tester), light.danger);
  });

  testWidgets('el helper se muestra y el error lo reemplaza', (tester) async {
    await pumpField(
      tester,
      STextField(
        controller: TextEditingController(),
        helper: 'Mínimo 8 caracteres',
      ),
    );
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

    await pumpField(
      tester,
      STextField(
        controller: TextEditingController(),
        helper: 'Mínimo 8 caracteres',
        errorText: 'Muy corta',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muy corta'), findsOneWidget);
    expect(
      find.text('Mínimo 8 caracteres'),
      findsNothing,
      reason: 'dos líneas de texto chico bajo el mismo campo compiten',
    );
  });

  testWidgets('password arranca oculto y el toggle lo revela', (tester) async {
    await pumpField(
      tester,
      STextField.password(
        controller: TextEditingController(text: 'secreta123'),
        label: 'Contraseña',
      ),
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    expect(
      find.byTooltip('Ocultar contraseña'),
      findsOneWidget,
      reason: 'el tooltip describe la acción, no el estado actual',
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
  });

  testWidgets('enabled: false deshabilita el campo', (tester) async {
    await pumpField(
      tester,
      STextField(
        controller: TextEditingController(),
        label: 'Correo',
        enabled: false,
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      borderColor(tester),
      light.borderSoft,
      reason: 'deshabilitado baja el peso del borde en vez de teñirlo',
    );
  });

  testWidgets('la label es texto propio, no floating label de Material', (
    tester,
  ) async {
    await pumpField(
      tester,
      STextField(controller: TextEditingController(), label: 'Correo'),
    );

    expect(find.text('Correo'), findsOneWidget);

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(
      decoration.labelText,
      isNull,
      reason: 'con label flotante el campo cambia de alto y la columna salta',
    );
    expect(decoration.label, isNull);

    // La etiqueta está por ENCIMA del campo, no dentro.
    expect(
      tester.getBottomLeft(find.text('Correo')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(AnimatedContainer)).dy),
    );
  });

  testWidgets('la altura respeta el mínimo táctil de 44 px', (tester) async {
    await pumpField(
      tester,
      STextField(controller: TextEditingController(), size: STextFieldSize.md),
    );
    expect(
      tester.getSize(find.byType(AnimatedContainer)).height,
      greaterThanOrEqualTo(44),
    );

    await pumpField(
      tester,
      STextField(controller: TextEditingController(), size: STextFieldSize.lg),
    );
    expect(
      tester.getSize(find.byType(AnimatedContainer)).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('el ojo de la contraseña no infla el campo', (tester) async {
    // El IconButton por defecto trae 48 px de target; sin acotarlo, el campo
    // crecería por encima de su alto.
    await pumpField(
      tester,
      STextField.password(controller: TextEditingController()),
    );

    expect(tester.getSize(find.byType(AnimatedContainer)).height, 56);
  });

  testWidgets('enfocar NO cambia el alto del campo', (tester) async {
    // La razón de ser de la etiqueta arriba y del borde que se tiñe: la columna
    // del formulario no se mueve al pasar de un campo al siguiente.
    await pumpField(
      tester,
      STextField.password(controller: TextEditingController()),
    );
    final resting = tester.getSize(find.byType(AnimatedContainer)).height;

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AnimatedContainer)).height, resting);
  });

  testWidgets('el borde se anima en vez de saltar', (tester) async {
    await pumpField(tester, STextField(controller: TextEditingController()));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    // A mitad de la transición el color es intermedio: ni el de reposo ni el
    // final. Sin animación el cambio se siente de sistema viejo.
    await tester.pump(const Duration(milliseconds: 60));

    final mid = borderColor(tester);
    expect(mid, isNot(light.border));
    expect(mid, isNot(light.primary));

    await tester.pumpAndSettle();
    expect(borderColor(tester), light.primary);
  });

  group('centrado vertical del contenido', () {
    testWidgets('centrar NO encoge el ancho del campo', (tester) async {
      // Align da constraints holgadas al hijo: si el campo no se estirara,
      // quedaria angosto dentro de su propio borde.
      await pumpField(
        tester,
        STextField(controller: TextEditingController(text: 'x')),
      );
      // Ocupa todo el ancho MENOS el borde (1 px por lado). Si el Align no
      // estirara al hijo, el campo colapsaria al ancho del texto ('x').
      expect(
        tester.getSize(find.byType(TextFormField)).width,
        closeTo(tester.getSize(find.byType(STextField)).width - 2, 1.0),
      );
    });

    // Regresion: el alto lo fija un ConstrainedBox(minHeight) de afuera y con
    // `isDense: true` el InputDecorator NO rellena el sobrante. El texto medía
    // ~49 px (24.8 de linea + 24 de padding) en una caja de 52 y quedaba pegado
    // arriba. Se ve descentrado justo en el tamano `lg`, el de los formularios.
    Future<void> pumpSized(WidgetTester tester, STextFieldSize size) async {
      await pumpField(
        tester,
        STextField(
          controller: TextEditingController(text: 'texto'),
          size: size,
        ),
      );
    }

    testWidgets('lg: el texto queda centrado en el alto del campo', (
      tester,
    ) async {
      await pumpSized(tester, STextFieldSize.lg);

      final field = tester.getRect(find.byType(STextField));
      final text = tester.getRect(find.text('texto'));
      final desvio = (text.center.dy - field.center.dy).abs();

      // Medido: delta exacto 0.0. La tolerancia de 1 px cubre el redondeo de
      // la linea base, no una aproximacion del layout.
      expect(desvio, lessThan(1.0));
    });

    testWidgets('md: el texto queda centrado en el alto del campo', (
      tester,
    ) async {
      await pumpSized(tester, STextFieldSize.md);

      final field = tester.getRect(find.byType(STextField));
      final text = tester.getRect(find.text('texto'));
      expect((text.center.dy - field.center.dy).abs(), lessThan(1.0));
    });
  });
}
