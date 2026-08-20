/// Aviso en vivo de que al cliente le llego una notificacion nueva, para que la
/// campana se actualice sin esperar al siguiente sondeo.
///
/// Solo dice QUE llego algo, no que llego: quien escucha recarga su fuente. Asi
/// el contrato no arrastra el modelo de la notificacion ni su forma en la BD.
///
/// No lanza: quedarse sin aviso en vivo degrada al sondeo periodico, que es el
/// respaldo. Romper la pantalla por eso seria peor que la propia falla.
abstract interface class LiveNotificationsPort {
  /// Escucha lo que le llegue a [email]. Idempotente: llamar dos veces con el
  /// mismo correo no abre una segunda escucha; con otro correo reemplaza.
  Future<void> subscribe({
    required String email,
    required void Function() onNew,
  });

  /// Corta la escucha. Idempotente.
  Future<void> unsubscribe();
}
