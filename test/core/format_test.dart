import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/core/format.dart';

/// Contrato de `toTitleCaseEs`: los documentos oficiales traen el nombre en
/// mayúsculas y así se guardaba en el perfil.
void main() {
  group('toTitleCaseEs', () {
    test('pasa un nombre en mayúsculas a inicial por palabra', () {
      expect(
        toTitleCaseEs('JORGE ADRIAN FIGUEROA RUVALCABA'),
        'Jorge Adrian Figueroa Ruvalcaba',
      );
    });

    test('respeta los acentos y la eñe', () {
      expect(
        toTitleCaseEs('EDUARDO DAVID PEÑA ARAUJO'),
        'Eduardo David Peña Araujo',
      );
      expect(toTitleCaseEs('ÁLVAREZ MARÍA'), 'Álvarez María');
    });

    test('las partículas intermedias van en minúscula', () {
      expect(toTitleCaseEs('JOSE DE LA CRUZ'), 'Jose de la Cruz');
      expect(
        toTitleCaseEs('MARIA DEL CARMEN Y LOPEZ'),
        'Maria del Carmen y Lopez',
      );
    });

    test('una partícula que abre el nombre SÍ va en mayúscula', () {
      expect(toTitleCaseEs('DE LA ROSA JUAN'), 'De la Rosa Juan');
    });

    test('colapsa espacios y aguanta null y vacío', () {
      expect(toTitleCaseEs('  JUAN   PEREZ  '), 'Juan Perez');
      expect(toTitleCaseEs(null), '');
      expect(toTitleCaseEs('   '), '');
    });
  });
}
