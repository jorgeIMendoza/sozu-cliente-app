import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Andamio de las pantallas de acceso (login / recuperar / cambio forzado).
///
/// Vive en `layouts/` y no en `components/`: no es una pieza de interfaz
/// reutilizable, es la **estructura** que envuelve a una pantalla. La distinción
/// importa porque un layout puede imponer tema, scroll y breakpoints -cosas que
/// un componente nunca debería decidir por su cuenta.
///
/// Dos layouts sobre el MISMO contenido, sin ramas de código en las pantallas:
///
/// * **< 1024 px**: una columna, el formulario sobre el fondo con degradado
///   radial verde.
/// * **>= 1024 px**: doble columna - panel de marca a la izquierda (55%) y
///   formulario a la derecha (45%). Evita el vacío enorme que dejaba el
///   formulario solo en medio de un monitor.
///
/// En ambos casos el scroll es de **toda la página**: el `SingleChildScrollView`
/// envuelve un `ConstrainedBox(minHeight: viewport)`, así que cuando el contenido
/// cabe queda centrado sin barra, y cuando no cabe (ventana baja, teclado
/// abierto) se desplaza el lienzo completo.
///
/// **Breakpoints:** usa los del design system (`context.bp`), no unos propios.
/// Antes tenía `kAuthSplitBreakpoint = 1024` y `kAuthCompactBreakpoint = 480`
/// duplicando lo que ya define `ui/theme/breakpoints.dart` - y 1024 era
/// exactamente `kSozuDesktopMin`. Un sistema de breakpoints, no dos.
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child, required this.brand});

  /// Contenido de la columna del formulario.
  final Widget child;

  /// Panel decorativo de la columna izquierda en el layout partido.
  ///
  /// Se recibe por parámetro y no se instancia aquí: así la PANTALLA decide qué
  /// compone (imagen + formulario) y este archivo, compartido por las tres
  /// pantallas de acceso, no depende de ninguna.
  final Widget brand;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Columna del formulario: centrada, desplazable y con ancho de lectura
  /// acotado. [insidePanel] = va dentro del panel derecho del layout partido,
  /// donde el fondo ya es una superficie lisa y el aire lateral lo pone el panel.
  Widget _formColumn(BuildContext context, {required bool insidePanel}) {
    final isCompact = context.bp.isMobile;
    final padH = insidePanel ? 48.0 : (isCompact ? 16.0 : 24.0);
    final padV = insidePanel ? 48.0 : (isCompact ? 24.0 : 40.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            // Clamping en vez del rebote de iOS: una página de acceso no
            // "rebota" al llegar al tope.
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: ConstrainedBox(
              // Al menos el alto del viewport menos el padding: eso es lo que
              // permite centrar y desplazar a la vez.
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - padV * 2),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isCompact ? double.infinity : 400,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSplit = context.bp.isDesktop;

    final Widget body = isSplit
        ? Scaffold(
            backgroundColor: _kSurface,
            body: Row(
              children: [
                Expanded(flex: 55, child: widget.brand),
                Expanded(
                  flex: 45,
                  child: SafeArea(
                    child: _formColumn(context, insidePanel: true),
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: _kSurface,
            body: DecoratedBox(
              // El `decoration` sí es const (sus dos colores son constantes de
              // la paleta), aunque el DecoratedBox no pueda serlo porque su hijo
              // depende del State.
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  // Elipse ancha y poco alta, desplazada arriba (50% 30%).
                  center: Alignment(0, -0.55),
                  radius: 0.9,
                  colors: [_kPrimarySoft, _kSurface],
                  stops: [0.0, 0.75],
                ),
              ),
              child: SafeArea(child: _formColumn(context, insidePanel: false)),
            ),
          );

    // El acceso es SIEMPRE claro, aunque el sistema esté en modo oscuro: es la
    // primera pantalla y debe verse igual para todos. El usuario elige
    // claro/oscuro ya dentro de la app.
    //
    // Fijar el TEMA (y no solo los colores) evita que se cuelen grises oscuros
    // por widgets que leen `Theme.of(context)`: menús del campo de texto,
    // scrollbar, tooltips, ripples. Y hace que `context.s.color` dentro de los
    // componentes de acceso devuelva los roles claros sin que ninguno tenga que
    // saberlo.
    return Theme(data: sozuLightTheme(), child: body);
  }
}

// ---------------------------------------------------------------------------
// Colores del acceso
// ---------------------------------------------------------------------------
//
// El acceso es light-only, así que sus dos colores de fondo se toman de la
// PALETA CRUDA en lugar de `context.s.color`.
//
// No es un atajo: leer un campo de un objeto `const` NO es una expresión
// constante en Dart, así que `const BoxDecoration(colors: [roles.primarySoft])`
// no compila -  "Not a constant expression". Las constantes de la paleta sí lo
// son, y así el degradado del fondo se mantiene `const` (se construye una vez,
// no en cada rebuild).
//
// Equivalencias: `_kSurface` == `SozuColorRoles.light.surface`,
// `_kPrimarySoft` == `SozuColorRoles.light.primarySoft`.

const Color _kSurface = SozuNeutral.n0;
const Color _kPrimarySoft = SozuBrand.soft06;

// ---------------------------------------------------------------------------
// Alineación del contenido de acceso
// ---------------------------------------------------------------------------

/// Alineación del bloque de encabezado (título, subtítulo, enlaces).
///
/// Centrado en los dos layouts: la columna del formulario es angosta y su eje
/// visual es el centro, así que un encabezado a la izquierda se leía descolgado
/// respecto a los campos.
const TextAlign kAuthTextAlign = TextAlign.center;

/// Equivalente de [kAuthTextAlign] para envolver widgets en `Align`.
const Alignment kAuthAlignment = Alignment.center;

/// Columna del formulario de acceso.
///
/// Vive junto al layout porque es **estructura**, no un elemento de interfaz: lo
/// único que hace es apilar los hijos a ancho completo con el aire lateral
/// correcto.
///
/// **Ya no es una tarjeta.** Antes, por debajo de 1024 px pintaba una card
/// blanca con borde y sombra sobre el fondo con degradado. Eso metía una caja
/// dentro de otra: en teléfono la card ocupaba casi todo el ancho, así que su
/// borde solo dibujaba un rectángulo pegado a los márgenes, y su padding se
/// sumaba al del [AuthLayout] dejando el formulario flotando en el centro.
class AuthFormBody extends StatelessWidget {
  const AuthFormBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.bp.isMobile;
    return Padding(
      // Solo aire horizontal en teléfono, donde el layout llega a los bordes.
      // El vertical ya lo pone AuthLayout.
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
