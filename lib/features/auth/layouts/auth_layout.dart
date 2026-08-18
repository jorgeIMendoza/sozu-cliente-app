import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sozu_cliente_app/features/auth/components/auth_brand_image.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Andamio de las pantallas de acceso: impone tema claro, scroll de página y
/// breakpoints. Bajo 1024 px una columna sobre degradado radial; encima, marca
/// (55%) y formulario (45%).
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child});

  /// Contenido de la columna del formulario.
  final Widget child;

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
                const Expanded(flex: 55, child: AuthBrandImage()),
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
// WARN: No cambiar por `context.s.color`: leer un campo de un objeto `const` no es
// expresión constante, y dentro de un `const BoxDecoration` falla. Equivalen a
// `SozuColorRoles.light.surface` y `.primarySoft`.

const Color _kSurface = SozuNeutral.n0;
const Color _kPrimarySoft = SozuBrand.soft06;

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
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? context.s.space.xxs : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
