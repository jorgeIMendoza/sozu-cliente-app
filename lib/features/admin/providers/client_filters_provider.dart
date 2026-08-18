import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros del selector de cliente. Viven fuera del `State` de la pantalla para
/// sobrevivir a salir y volver. En memoria: es contexto de sesión, no una
/// preferencia.
class ClientFiltersController extends ChangeNotifier {
  String _query = '';
  int? _projectId;
  String _unit = '';

  /// Busqueda por nombre o correo.
  String get query => _query;

  int? get projectId => _projectId;

  /// Numero de unidad, ya recortado.
  String get unit => _unit;

  /// Hay algo puesto. Decide si se ofrece "Limpiar filtros".
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
