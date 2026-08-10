import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/ui/tokens/color_roles.dart';

/// Prueba que migrar `PortalColors.X` a `context.s.color.Y` NO cambia un pixel.
///
/// En tema claro `context.s.color` ES `SozuColorRoles.light`. Si cada constante
/// del shim vale exactamente lo mismo que su rol claro, la migracion es un
/// renombre y no un cambio de diseño. Cuando esto se rompa, alguien movio un
/// valor y la migracion dejo de ser invisible: hay que enterarse aqui, no en la
/// pantalla.
///
/// En oscuro NO hay equivalencia posible: las constantes del shim son claras y
/// no dependen del tema. Por eso lo que sigue sin migrar se ve claro sobre
/// oscuro, y por eso esta migracion es la que desbloquea el modo oscuro.
///
/// El mapeo es el de la tabla del docstring de `core/portal_theme.dart`.
void main() {
  const light = SozuColorRoles.light;

  test('los roles que usa el menu de Inicio son identicos al shim', () {
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.mutedForeground, light.fgMuted);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primary, light.primary);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.border, light.border);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.borderSoft, light.borderSoft);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.muted, light.muted);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.warning, light.warning);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.surface, light.surface);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.foreground, light.fg);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.destructive, light.danger);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.textMuted, light.fgSubtle);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primaryHover, light.primaryHover);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.background, light.background);
  });

  test('los tintes colapsados apuntan al rol fuerte, no a uno propio', () {
    // soft10 y soft15 colapsaron en primarySoftStrong (ADR §6.3).
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primarySoft10, light.primarySoftStrong);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primarySoft15, light.primarySoftStrong);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primarySoft6, light.primarySoft);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.primaryBorder30, light.primaryBorder);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.mutedHover, light.surfaceAlt);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.warningSoft10, light.warningSoft);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.warningSoft15, light.warningSoftStrong);
    // ignore: deprecated_member_use_from_same_package
    expect(PortalColors.destructiveSoft15, light.dangerSoftStrong);
  });

  test('mutedSoft30 es el UNICO que NO es identico: casi-blanco vs blanco', () {
    // La tabla de portal_theme.dart dice "indistinguible de surface", y es un
    // juicio de diseño, no identidad: #FBFCFD contra #FFFFFF. Migrarlo SI
    // cambia pixeles (3 sitios en el menu de Inicio), aunque el ojo no lo vea.
    // Queda afirmado para que el cambio sea deliberado y no una sorpresa.
    // ignore: deprecated_member_use_from_same_package
    const shim = PortalColors.mutedSoft30;
    expect(shim, isNot(light.surface));
    expect(light.surface.r, 1.0);
    // Diferencia por canal < 2%: por eso el ADR los colapso.
    for (final (a, b) in [
      (shim.r, light.surface.r),
      (shim.g, light.surface.g),
      (shim.b, light.surface.b),
    ]) {
      expect((a - b).abs(), lessThan(0.02));
    }
  });
}
