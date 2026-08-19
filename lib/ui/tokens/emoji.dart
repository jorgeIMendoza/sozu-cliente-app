/// Emoji que la app PINTA como contenido: etiquetas que lee el cliente y
/// glifos que dibuja una animación.
///
/// Es el único sitio del repo donde se escribe un emoji. En comentarios, docs y
/// salida de scripts van etiquetas de texto (`WARN:`, `ERROR:`, `OK:`), que se
/// buscan con grep y no dependen de la fuente del terminal.
///
/// Cambiar uno aquí lo cambia en todos sus usos.
class SozuEmoji {
  SozuEmoji._();

  // Escapes y no el glifo: asi el repo entero queda en ASCII y el grep de la
  // regla debe salir vacio SIN excepciones, incluido este archivo.

  /// Sobre volador.
  static const String sobre = '\u{2709}\u{FE0F}';

  /// Balon: la variante "gol".
  static const String balon = '\u{26BD}';

  /// Cohete.
  static const String cohete = '\u{1F680}';

  /// A pie, en "Como llegar".
  static const String aPie = '\u{1F6B6}';

  /// En bici.
  static const String bici = '\u{1F6B4}';

  /// En auto.
  static const String auto = '\u{1F697}';

  /// Festejo: unidad liquidada.
  static const String festejo = '\u{1F389}';
}
