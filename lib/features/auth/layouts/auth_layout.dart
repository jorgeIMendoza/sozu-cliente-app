import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Andamio de las pantallas de acceso (login / recuperar / cambio forzado).
/// Impone tema, scroll y breakpoints sobre el mismo contenido:
///
/// * < 1024 px: una columna sobre el fondo con degradado radial verde.
/// * >= 1024 px: doble columna - marca izquierda (55%), formulario derecha
///   (45%).
///
/// El scroll es de toda la página: si el contenido cabe queda centrado.
/// Breakpoints: los del design system (`context.bp`), nunca unos propios.
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child, required this.brand});

  /// Contenido de la columna del formulario.
  final Widget child;

  /// Panel decorativo de la columna izquierda en el layout partido.
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
            // Clamping: una página de acceso no "rebota" al llegar al tope.
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            child: ConstrainedBox(
              // Alto del viewport: permite centrar y desplazar a la vez.
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
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Foto de marca de fondo, tenue. Puramente decorativa; el
                // formulario va encima sobre la superficie clara.
                Opacity(opacity: 0.18, child: widget.brand),
                SafeArea(child: _formColumn(context, insidePanel: false)),
              ],
            ),
          );

    // El acceso es SIEMPRE claro, aunque el sistema esté en modo oscuro. Se
    // fija el TEMA y no solo los colores: si no, se cuelan grises oscuros por
    // los widgets que leen `Theme.of(context)` (menús, scrollbar, ripples).
    return Theme(data: sozuLightTheme(), child: body);
  }
}

// ---------------------------------------------------------------------------
// Colores del acceso
// ---------------------------------------------------------------------------
//
// OJO: no cambiar por `context.s.color`. Leer un campo de un objeto `const` NO
// es una expresión constante en Dart, así que dentro de un
// `const BoxDecoration` falla con "Not a constant expression"; solo sirven las
// constantes crudas.
//
// Equivalencia: `_kSurface` == `SozuColorRoles.light.surface`.

const Color _kSurface = SozuNeutral.n0;

// ---------------------------------------------------------------------------
// Alineación del contenido de acceso
// ---------------------------------------------------------------------------

/// Alineación del bloque de encabezado (título, subtítulo, enlaces).
const TextAlign kAuthTextAlign = TextAlign.center;

/// Equivalente de [kAuthTextAlign] para envolver widgets en `Align`.
const Alignment kAuthAlignment = Alignment.center;

/// Columna del formulario de acceso: apila los hijos a ancho completo con el
/// aire lateral correcto. Sin tarjeta ni borde.
class AuthFormBody extends StatelessWidget {
  const AuthFormBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.bp.isMobile;
    return Padding(
      // Solo horizontal y solo en teléfono: el vertical lo pone AuthLayout.
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
