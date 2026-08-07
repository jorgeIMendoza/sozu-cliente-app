import 'package:flutter/material.dart';

import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Estado de una sección del Perfil (validada / en proceso / pendiente).
enum SeccionEstado { validada, enProceso, pendiente }

/// Estado de las 4 secciones del Perfil más los flags "completo" de las filas.
///
/// Cuidado: el tally del hero y los chips de las filas NO usan el mismo
/// criterio. Una fila es "completa" solo con todos los requeridos verificados,
/// mientras el hero cuenta validada / enProceso / pendiente.
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

  int get validadas => _todas.where((e) => e == SeccionEstado.validada).length;
  int get enProceso => _todas.where((e) => e == SeccionEstado.enProceso).length;
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
      cuentas.isNotEmpty &&
      cuentas.every((c) => (c.evidencia ?? '').isNotEmpty);
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

/// Hero "Tu expediente · el motor de tu activación" del overview del Perfil:
/// contador de secciones completadas y caja "ESTADO DE SECCIONES".
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
    final t = context.s;
    final tone = t.color;
    final Color eyebrowColor = tone.primaryHover;
    final Color titleColor = tone.fg;
    final Color bodyColor = tone.fgMuted;

    Widget txt(String s, TextStyle style) => Text(s, style: style);

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        txt(
          'TU EXPEDIENTE · EL MOTOR DE TU ACTIVACIÓN',
          t.text.overline.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: eyebrowColor,
          ),
        ),
        SizedBox(height: t.space.xs),
        txt(
          'Tu información se construye desde tus documentos.',
          t.text.h3.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.4,
            color: titleColor,
          ),
        ),
        SizedBox(height: t.space.xs),
        txt(
          'Cada documento que subes alimenta tu información personal y '
          'fiscal. Solo validas lo que ya dijeron.',
          t.text.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.55,
            color: bodyColor,
          ),
        ),
        SizedBox(height: t.space.md),
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
                textStyle: t.text.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Gestionar mis documentos'),
            ),
            txt(
              '${estado.validadas} de ${PerfilSeccionesEstado.total} '
              'secciones completadas',
              t.text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: bodyColor,
              ),
            ),
          ],
        ),
      ],
    );

    final estadoBox = _EstadoSeccionesBox(estado: estado);

    return Container(
      padding: EdgeInsets.all(t.space.lg),
      decoration: BoxDecoration(
        color: tone.primarySoft,
        border: Border.all(color: tone.primaryBorder),
        borderRadius: t.radius.lgBorder,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 560;
          if (ancho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                SizedBox(width: t.space.lg),
                SizedBox(width: 210, child: estadoBox),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              izquierda,
              SizedBox(height: t.space.md),
              estadoBox,
            ],
          );
        },
      ),
    );
  }
}

/// Caja "ESTADO DE SECCIONES" con los tres renglones de conteo.
class _EstadoSeccionesBox extends StatelessWidget {
  final PerfilSeccionesEstado estado;

  const _EstadoSeccionesBox({required this.estado});

  @override
  Widget build(BuildContext context) {
    final t = context.s;
    final tone = t.color;

    final tally = <({int n, String label, Color bg, Color fg})>[
      (
        n: estado.validadas,
        label: 'validadas',
        bg: tone.primarySoft,
        fg: tone.primaryHover,
      ),
      (
        n: estado.enProceso,
        label: 'en proceso',
        bg: tone.warningSoft,
        fg: tone.warningFg,
      ),
      (
        n: estado.pendientes,
        label: 'pendientes',
        bg: tone.surfaceAlt,
        fg: tone.fgMuted,
      ),
    ];

    final labelStyle = t.text.overline.copyWith(
      fontWeight: FontWeight.w700,
      color: tone.fgSubtle,
      letterSpacing: 0.8,
    );

    return Container(
      padding: EdgeInsets.all(t.space.md),
      decoration: BoxDecoration(
        color: tone.surface,
        border: Border.all(color: tone.border),
        borderRadius: t.radius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ESTADO DE SECCIONES', style: labelStyle),
          SizedBox(height: t.space.sm),
          for (var i = 0; i < tally.length; i++) ...[
            if (i > 0) SizedBox(height: t.space.sm),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tally[i].bg,
                    borderRadius: t.radius.smBorder,
                  ),
                  child: Text(
                    '${tally[i].n}',
                    style: t.text.overline.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tally[i].fg,
                    ),
                  ),
                ),
                SizedBox(width: t.space.xs),
                Text(
                  tally[i].label,
                  style: t.text.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone.fgMuted,
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

/// Estilo (punto/chip) por estatus del expediente: aprobado verde · en revisión
/// y expirado ámbar · rechazado rojo · pendiente y opcional neutro.
({Color dot, Color bg, Color fg, String label}) expedienteEstatusStyle(
  String estatus,
  SozuColorRoles tone,
) {
  switch (estatus) {
    case 'aprobado':
      return (
        dot: tone.positive,
        bg: tone.primarySoft,
        fg: tone.primaryHover,
        label: 'Aprobado',
      );
    case 'revision':
      return (
        dot: tone.warning,
        bg: tone.warningSoft,
        fg: tone.warningFg,
        label: 'En revisión',
      );
    case 'expirado':
      // Gris neutro (no ámbar), como el portal: punto #d1d5db, chip
      // #6b7280 sobre #f3f4f6 (aquí vía tokens neutros theme-aware).
      return (
        dot: SozuNeutral.n300,
        bg: tone.surfaceAlt,
        fg: tone.fgMuted,
        label: 'Expirado',
      );
    case 'rechazado':
      return (
        dot: tone.danger,
        bg: tone.danger.withValues(alpha: 0.1),
        fg: tone.danger,
        label: 'Rechazado',
      );
    case 'opcional':
      return (
        dot: SozuNeutral.n300,
        bg: tone.surfaceAlt,
        fg: tone.fgMuted,
        label: 'Opcional',
      );
    default: // pendiente
      return (
        dot: SozuNeutral.n300,
        bg: tone.surfaceAlt,
        fg: tone.fgMuted,
        label: 'Pendiente',
      );
  }
}
