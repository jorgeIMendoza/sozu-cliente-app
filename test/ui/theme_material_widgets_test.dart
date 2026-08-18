import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// Los widgets de Material que la app usa sin envoltura propia (Switch,
/// Checkbox, dialogos) tienen que pintar con los roles de SOZU.
///
/// Sin tematizar, Material los deriva del `colorScheme` que genera a partir del
/// seed, y sale un verde que NO es el de la marca. Es el mismo defecto que
/// tenian el aviso de version y el `TabBar` de avisos.
void main() {
  for (final (nombre, theme, roles) in <(String, ThemeData, SozuColorRoles)>[
    ('claro', sozuLightTheme(), SozuColorRoles.light),
    ('oscuro', sozuDarkTheme(), SozuColorRoles.dark),
  ]) {
    test('$nombre: el Switch encendido usa primary', () {
      const encendido = <WidgetState>{WidgetState.selected};
      expect(theme.switchTheme.trackColor?.resolve(encendido), roles.primary);
      expect(theme.switchTheme.thumbColor?.resolve(encendido), roles.onPrimary);
    });

    test('$nombre: el Checkbox marcado usa primary', () {
      const marcado = <WidgetState>{WidgetState.selected};
      expect(theme.checkboxTheme.fillColor?.resolve(marcado), roles.primary);
      expect(theme.checkboxTheme.checkColor?.resolve(marcado), roles.onPrimary);
    });

    test('$nombre: el Checkbox sin marcar no se pierde en el fondo', () {
      const vacio = <WidgetState>{};
      expect(theme.checkboxTheme.fillColor?.resolve(vacio), roles.surface);
      expect(theme.checkboxTheme.side?.color, roles.border);
    });
  }
}
