import 'package:flutter_test/flutter_test.dart';
import 'package:sozu_cliente_app/ui/ui.dart';

/// `SozuEmoji` es el unico sitio del repo donde se escribe un emoji. Fuera de
/// aqui van etiquetas de texto (`WARN:`, `ERROR:`, `OK:`), que se buscan con
/// grep y no dependen de la fuente del terminal.
void main() {
  test('cada entrada resuelve a un glifo, no a una cadena vacia', () {
    // Un escape mal copiado compila igual y deja la etiqueta muda en pantalla.
    const todos = <String, String>{
      'sobre': SozuEmoji.sobre,
      'balon': SozuEmoji.balon,
      'cohete': SozuEmoji.cohete,
      'aPie': SozuEmoji.aPie,
      'bici': SozuEmoji.bici,
      'auto': SozuEmoji.auto,
      'festejo': SozuEmoji.festejo,
    };
    for (final e in todos.entries) {
      expect(e.value, isNotEmpty, reason: '${e.key} quedo vacio');
      expect(
        e.value.runes.first,
        greaterThan(0x2000),
        reason: '${e.key} no es un glifo pictografico',
      );
    }
  });

  test('no hay dos entradas con el mismo glifo', () {
    // Duplicar uno hace que cambiarlo "en un sitio" no lo cambie en todos, que
    // es justo lo que el diccionario evita.
    const valores = [
      SozuEmoji.sobre,
      SozuEmoji.balon,
      SozuEmoji.cohete,
      SozuEmoji.aPie,
      SozuEmoji.bici,
      SozuEmoji.auto,
      SozuEmoji.festejo,
    ];
    expect(valores.toSet().length, valores.length);
  });
}
