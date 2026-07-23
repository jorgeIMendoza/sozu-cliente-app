import 'package:flutter/material.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'portal_widgets.dart';

/// Estado de una sección del Perfil (validada / en proceso / pendiente).
/// Espejo del arreglo `secciones` del overview de ClientePerfil.tsx del portal.
enum SeccionEstado { validada, enProceso, pendiente }

/// Estado agregado de las 4 secciones del Perfil (Documentos, Personal,
/// Fiscal, Cuentas) más los flags "completo" que usan las filas de la lista.
///
/// El tally del hero ("ESTADO DE SECCIONES") y los chips de las filas usan
/// criterios distintos, tal como el portal:
///  - hero: docs → validada/enProceso/pendiente; cuentas con evidencia+estatus.
///  - filas: docs → completo solo si todos los requeridos verificados;
///    fiscal → completo si CSF verificada **o** hay régimen.
class PerfilSeccionesEstado {
  final SeccionEstado documentos;
  final SeccionEstado personal;
  final SeccionEstado fiscal;
  final SeccionEstado cuentas;

  // Flags "completo" de las filas "Secciones de tu perfil".
  final bool documentosCompleto;
  final bool personalCompleto;
  final bool fiscalCompleto;
  final bool cuentasCompleto;

  const PerfilSeccionesEstado({
    required this.documentos,
    required this.personal,
    required this.fiscal,
    required this.cuentas,
    required this.documentosCompleto,
    required this.personalCompleto,
    required this.fiscalCompleto,
    required this.cuentasCompleto,
  });

  /// Número total de secciones consideradas en el overview (portal: 4).
  static const int total = 4;

  List<SeccionEstado> get _todas => [documentos, personal, fiscal, cuentas];

  int get validadas =>
      _todas.where((e) => e == SeccionEstado.validada).length;
  int get enProceso =>
      _todas.where((e) => e == SeccionEstado.enProceso).length;
  int get pendientes =>
      _todas.where((e) => e == SeccionEstado.pendiente).length;
}

/// Deriva el estado de las secciones a partir del perfil y el expediente.
/// Copia la lógica del overview de ClientePerfil.tsx (portal web); degrada a
/// conteos en 0/pendiente cuando aún no hay datos del expediente.
PerfilSeccionesEstado computePerfilSeccionesEstado(
  ClientePerfil? p,
  ClienteExpediente? exp,
) {
  // Documentos: todos los requeridos aprobados → validada; con algún subido
  // pero no todos → en proceso; sin subir nada → pendiente.
  final reqTotal = exp?.requeridosTotal ?? 0;
  final reqAprob = exp?.requeridosAprobados ?? 0;
  final subidos = exp?.subidos ?? 0;
  final docsAllVerified = reqTotal > 0 && reqAprob >= reqTotal;
  final docState = docsAllVerified
      ? SeccionEstado.validada
      : subidos > 0
          ? SeccionEstado.enProceso
          : SeccionEstado.pendiente;

  // CSF (tipo 6) aprobada = fuente de los datos fiscales (fila fiscal completa).
  final csfVerificada =
      exp?.slots.any((s) => s.tipoId == 6 && s.estatus == 'aprobado') ?? false;

  // Personal: hay nombre legal real (el modelo usa "Cliente" como fallback).
  final nombre = (p?.nombreLegal ?? '').trim();
  final personalOk = p != null && nombre.isNotEmpty && nombre != 'Cliente';

  // Fiscal (hero): hay régimen.
  final tieneRegimen = (p?.regimen ?? '').isNotEmpty;

  // Cuentas: sin evidencia en alguna → pendiente; todas validadas (estatus 2)
  // → validada; con evidencia pero no todas validadas → en proceso.
  final cuentas = p?.cuentasBancarias ?? const <CuentaBancariaPerfil>[];
  final todasConEvidencia =
      cuentas.isNotEmpty && cuentas.every((c) => (c.evidencia ?? '').isNotEmpty);
  final todasValidadas =
      cuentas.isNotEmpty && cuentas.every((c) => c.estatus == 2);
  final cuentasState = !todasConEvidencia
      ? SeccionEstado.pendiente
      : todasValidadas
          ? SeccionEstado.validada
          : SeccionEstado.enProceso;

  return PerfilSeccionesEstado(
    documentos: docState,
    personal: personalOk ? SeccionEstado.validada : SeccionEstado.pendiente,
    fiscal: tieneRegimen ? SeccionEstado.validada : SeccionEstado.pendiente,
    cuentas: cuentasState,
    documentosCompleto: docsAllVerified,
    personalCompleto: personalOk,
    fiscalCompleto: csfVerificada || tieneRegimen,
    cuentasCompleto: cuentas.isNotEmpty,
  );
}

// ── Paleta exacta del hero "motor" del portal (ClientePerfil.tsx) ──────────
const Color _heroGradA = Color(0xFFF0FAF4);
const Color _heroGradB = Color(0xFFFBFEFC);
const Color _heroBorder = Color(0xFFCFE9DA);
const Color _heroTitle = Color(0xFF16331F);
const Color _heroBody = Color(0xFF3F5A4A);
const Color _estadoBoxBorder = Color(0xFFDCEEE3);
const Color _estadoLabel = Color(0xFF9AA3AD);
const Color _tallyLabel = Color(0xFF4B5563);
const Color _valBg = Color(0xFFE8F5EE);
const Color _procBg = Color(0xFFFBEFD9);
const Color _procFg = Color(0xFFB5730A);
const Color _pendBg = Color(0xFFEEF0F2);
const Color _pendFg = Color(0xFF6B7280);

/// Hero "Tu expediente · el motor de tu activación" del overview del Perfil
/// (espejo exacto de la sección `motor` de ClientePerfil.tsx): fondo verde
/// tenue con borde, título/subtítulo, botón verde "Gestionar documentos",
/// contador "N de 4 secciones completadas" y caja "ESTADO DE SECCIONES" con
/// los conteos validadas / en proceso / pendientes.
///
/// En modo portal usa la paleta exacta del portal; en móvil degrada a colores
/// theme-aware (soporta oscuro).
class ExpedienteCard extends StatelessWidget {
  final PerfilSeccionesEstado estado;
  final VoidCallback onGestionarDocumentos;

  const ExpedienteCard({
    super.key,
    required this.estado,
    required this.onGestionarDocumentos,
  });

  @override
  Widget build(BuildContext context) {
    final portal = isPortalMode(context);
    final tone = SozuTone.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Colores del contenedor.
    final Gradient? gradient =
        portal ? const LinearGradient(colors: [_heroGradA, _heroGradB]) : null;
    final Color bg = portal
        ? _heroGradA
        : dark
            ? tone.primarySoft
            : const Color(0xFFEEF7F1);
    final Color border = portal
        ? _heroBorder
        : dark
            ? SozuColors.emerald700
            : const Color(0xFFD8ECDF);

    final Color eyebrowColor = portal ? PortalColors.primary : tone.primaryDark;
    final Color titleColor = portal ? _heroTitle : tone.textPrimary;
    final Color bodyColor = portal ? _heroBody : tone.textSecondary;

    Widget txt(String s, TextStyle style) =>
        portal ? Text(s, style: _p(style)) : Text(s, style: style);

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        txt(
          'TU EXPEDIENTE · EL MOTOR DE TU ACTIVACIÓN',
          TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: eyebrowColor,
          ),
        ),
        const SizedBox(height: 8),
        txt(
          'Tu información se construye desde tus documentos.',
          TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.4,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 8),
        txt(
          'Cada documento que subes alimenta tu información personal y '
          'fiscal. Solo validas lo que ya dijeron.',
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: bodyColor,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onGestionarDocumentos,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: portal ? PortalColors.primary : null,
                shape: portal
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kPortalRadiusMd),
                      )
                    : null,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Gestionar documentos'),
            ),
            txt(
              '${estado.validadas} de ${PerfilSeccionesEstado.total} '
              'secciones completadas',
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bodyColor,
              ),
            ),
          ],
        ),
      ],
    );

    final estadoBox = _EstadoSeccionesBox(estado: estado, portal: portal);

    return Container(
      padding: portal
          ? const EdgeInsets.all(22)
          : const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: bg,
        gradient: gradient,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(portal ? kPortalRadiusMd : 16),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 560;
          if (ancho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                const SizedBox(width: 22),
                SizedBox(width: 210, child: estadoBox),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              izquierda,
              const SizedBox(height: 18),
              estadoBox,
            ],
          );
        },
      ),
    );
  }

  /// Aplica la familia tipográfica del portal a un [TextStyle] arbitrario.
  TextStyle _p(TextStyle s) => portalText(
        size: s.fontSize ?? 13,
        weight: s.fontWeight ?? FontWeight.w400,
        color: s.color ?? PortalColors.foreground,
        letterSpacing: s.letterSpacing,
        height: s.height,
      );
}

/// Caja "ESTADO DE SECCIONES" con los tres renglones de conteo.
class _EstadoSeccionesBox extends StatelessWidget {
  final PerfilSeccionesEstado estado;
  final bool portal;

  const _EstadoSeccionesBox({required this.estado, required this.portal});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);

    final tally = <({int n, String label, Color bg, Color fg})>[
      (
        n: estado.validadas,
        label: 'validadas',
        bg: portal ? _valBg : tone.primarySoft,
        fg: portal ? PortalColors.primary : tone.primaryDark,
      ),
      (
        n: estado.enProceso,
        label: 'en proceso',
        bg: portal ? _procBg : tone.pendingSoft,
        fg: portal ? _procFg : SozuColors.amber600,
      ),
      (
        n: estado.pendientes,
        label: 'pendientes',
        bg: portal ? _pendBg : tone.surfaceAlt,
        fg: portal ? _pendFg : tone.textSecondary,
      ),
    ];

    final labelStyle = portal
        ? portalText(
            size: 9.5,
            weight: FontWeight.w700,
            color: _estadoLabel,
            letterSpacing: 0.8,
          )
        : TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: tone.textMuted,
            letterSpacing: 0.8,
          );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: portal ? PortalColors.surface : tone.surface,
        border: Border.all(color: portal ? _estadoBoxBorder : tone.border),
        borderRadius: BorderRadius.circular(portal ? kPortalRadiusMd : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ESTADO DE SECCIONES', style: labelStyle),
          const SizedBox(height: 12),
          for (var i = 0; i < tally.length; i++) ...[
            if (i > 0) const SizedBox(height: 11),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tally[i].bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${tally[i].n}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tally[i].fg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  tally[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: portal ? _tallyLabel : tone.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Estilo (punto/chip) por estatus del expediente, compartido entre la
/// pantalla Expediente y otras vistas. Espejo de los colores del portal:
/// Aprobado verde · En revisión/Expirado ámbar · Rechazado rojo ·
/// Pendiente/Opcional neutro.
({Color dot, Color bg, Color fg, String label}) expedienteEstatusStyle(
  String estatus,
  SozuTone tone,
) {
  switch (estatus) {
    case 'aprobado':
      return (
        dot: SozuColors.emerald500,
        bg: tone.primarySoft,
        fg: tone.primaryDark,
        label: 'Aprobado',
      );
    case 'revision':
      return (
        dot: SozuColors.amber500,
        bg: tone.pendingSoft,
        fg: SozuColors.amber600,
        label: 'En revisión',
      );
    case 'expirado':
      // Gris neutro (no ámbar), como el portal: punto #d1d5db, chip
      // #6b7280 sobre #f3f4f6 (aquí vía tokens neutros theme-aware).
      return (
        dot: SozuColors.slate300,
        bg: tone.surfaceAlt,
        fg: tone.textSecondary,
        label: 'Expirado',
      );
    case 'rechazado':
      return (
        dot: tone.negative,
        bg: tone.negative.withValues(alpha: 0.1),
        fg: tone.negative,
        label: 'Rechazado',
      );
    case 'opcional':
      return (
        dot: SozuColors.slate300,
        bg: tone.surfaceAlt,
        fg: tone.textSecondary,
        label: 'Opcional',
      );
    default: // pendiente
      return (
        dot: SozuColors.slate300,
        bg: tone.surfaceAlt,
        fg: tone.textSecondary,
        label: 'Pendiente',
      );
  }
}
