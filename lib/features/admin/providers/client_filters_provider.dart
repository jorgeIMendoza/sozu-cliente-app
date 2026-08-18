import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros del selector de cliente, **fuera de la pantalla**.
///
/// El equivalente de un store de Zustand: el estado vive en el provider, no en
/// el `State` del widget, así que sobrevive a salir del selector y volver. Antes
/// eran campos de `_SelectClientScreenState` y se perdían al navegar a avisos o
/// al entrar como un cliente y regresar: había que reescribir proyecto, unidad
/// y búsqueda cada vez.
///
/// En memoria a propósito, sin `shared_preferences`: es contexto de trabajo de
/// la sesión, no una preferencia. Al cerrar sesión se limpia ([clear]).
class ClientFiltersController extends ChangeNotifier {
  String _query = '';
  int? _projectId;
  String _unit = '';

  /// Texto del buscador por nombre o correo.
  String get query => _query;

  /// Proyecto elegido, o null si no hay filtro de proyecto.
  int? get projectId => _projectId;

  /// Número de unidad tal cual lo escribió el usuario, ya recortado.
  String get unit => _unit;

  /// Hay algo que limpiar. Lo consume el botón global de "Limpiar filtros",
  /// que no debe ofrecerse cuando no hay nada puesto.
  bool get isDirty =>
      _query.isNotEmpty || _projectId != null || _unit.isNotEmpty;

  void setQuery(String v) {
    if (_query == v) return;
    _query = v;
    notifyListeners();
  }

  void setProjectId(int? v) {
    if (_projectId == v) return;
    _projectId = v;
    notifyListeners();
  }

  void setUnit(String v) {
    if (_unit == v) return;
    _unit = v;
    notifyListeners();
  }

  /// Deja los tres filtros en blanco de una sola vez.
  void clear() {
    if (!isDirty) return;
    _query = '';
    _projectId = null;
    _unit = '';
    notifyListeners();
  }
}

final clientFiltersProvider = ChangeNotifierProvider<ClientFiltersController>(
  (ref) => ClientFiltersController(),
);
