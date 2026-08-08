import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sozu_cliente_app/core/portal_theme.dart';
import 'package:sozu_cliente_app/data/models.dart';
import 'package:sozu_cliente_app/features/auth/providers/auth_provider.dart';
import 'package:sozu_cliente_app/features/client/profile/providers/profile_providers.dart';
import 'package:sozu_cliente_app/widgets/network_image.dart';
import 'package:sozu_cliente_app/features/auth/components/password_rules.dart';
import 'package:sozu_cliente_app/widgets/portal_widgets.dart'
    show showPortalDialog;
import 'package:sozu_cliente_app/ui/ui.dart';

/// Bottom sheet en móvil / diálogo centrado del portal en web ancha.
Future<T?> _showPerfilModal<T>(BuildContext context, Widget child) {
  if (isPortalMode(context)) {
    return showPortalDialog<T>(context, child: child);
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => child,
  );
}

// ─── Gate de contraseña ───────────────────────────────────────────────────────

DateTime? _pwAuthAt;
const _pwAuthGrace = Duration(seconds: 90);

bool get _pwAuthed =>
    _pwAuthAt != null && DateTime.now().difference(_pwAuthAt!) < _pwAuthGrace;

/// Pide la contraseña actual antes de un guardado sensible. Devuelve true si
/// la identidad quedó confirmada (o si sigue vigente la gracia de 90 s).
Future<bool> ensurePerfilPwAuth(BuildContext context) async {
  if (_pwAuthed) return true;
  final ok = await _showPerfilModal<bool>(context, const _PwGateSheet());
  if (ok == true) {
    _pwAuthAt = DateTime.now();
    return true;
  }
  return false;
}

class _PwGateSheet extends ConsumerStatefulWidget {
  const _PwGateSheet();

  @override
  ConsumerState<_PwGateSheet> createState() => _PwGateSheetState();
}

class _PwGateSheetState extends ConsumerState<_PwGateSheet> {
  final _pw = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref.read(authPortProvider).verifyPassword(_pw.text);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _error = 'Contraseña incorrecta';
        _busy = false;
      });
    } catch (_) {
      // AuthError de red/servidor: no se pudo verificar, no es contraseña mala.
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo verificar. Intenta de nuevo.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.lock_outline,
      title: 'Confirmar identidad',
      subtitle: 'Ingresa tu contraseña para guardar los cambios',
      children: [
        SFieldLabel('Contraseña actual'),
        TextField(
          controller: _pw,
          autofocus: true,
          obscureText: !_show,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _verify(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Tu contraseña',
            errorText: _error,
            suffixIcon: IconButton(
              icon: Icon(
                _show ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (_pw.text.isEmpty || _busy) ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Continuar'),
        ),
        _CancelButton(onTap: () => Navigator.pop(context, false)),
      ],
    );
  }
}

// ─── Catálogo de ocupaciones ─────────────────────────────────────────────────

/// Ocupaciones canónicas del selector. El selector agrega "Otro" al final para
/// los valores fuera del catálogo.
const List<String> _kOcupaciones = [
  'Abogado/a',
  'Administrador/a',
  'Agricultor/a',
  'Ama de casa',
  'Arquitecto/a',
  'Asalariado/a',
  'Comerciante',
  'Consultor/a',
  'Contador/a público/a',
  'Dentista',
  'Diseñador/a',
  'Docente',
  'Director/a',
  'Empleado/a',
  'Empleado/a privado/a',
  'Empresario/a',
  'Enfermero/a',
  'Estudiante',
  'Ingeniero/a',
  'Independiente',
  'Jubilado/a',
  'Médico/a',
  'Negocio propio',
  'Pensionado/a',
  'Profesionista',
  'Profesor/a',
  'Servidor/a público/a',
  'Transportista',
  'Ventas',
];

/// Normaliza ocupación libre a Title Case, dejando los conectores comunes en
/// minúscula.
String? _normalizarOcupacion(String? raw) {
  if (raw == null) return null;
  final limpio = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return null;
  const minus = {'de', 'del', 'la', 'el', 'y', 'en', 'a'};
  final palabras = limpio.toLowerCase().split(' ');
  return [
    for (var i = 0; i < palabras.length; i++)
      if (i > 0 && minus.contains(palabras[i]))
        palabras[i]
      else if (palabras[i].isEmpty)
        palabras[i]
      else
        '${palabras[i][0].toUpperCase()}${palabras[i].substring(1)}',
  ].join(' ');
}

/// ¿El valor está fuera del catálogo (→ debe capturarse como "Otro")?
bool _esOcupacionOtro(String? valor) {
  if (valor == null || valor.isEmpty) return false;
  return !_kOcupaciones.contains(valor);
}

// ─── Editar datos personales ─────────────────────────────────────────────────

Future<void> showEditPersonalSheet(BuildContext context, ClientePerfil p) =>
    _showPerfilModal<void>(context, _EditPersonalSheet(perfil: p));

class _EditPersonalSheet extends ConsumerStatefulWidget {
  final ClientePerfil perfil;
  const _EditPersonalSheet({required this.perfil});

  @override
  ConsumerState<_EditPersonalSheet> createState() => _EditPersonalSheetState();
}

class _EditPersonalSheetState extends ConsumerState<_EditPersonalSheet> {
  late final _nombre = TextEditingController(text: widget.perfil.nombreLegal);
  late final _rfc = TextEditingController(text: widget.perfil.rfc ?? '');
  late final _curp = TextEditingController(text: widget.perfil.curp ?? '');
  late final _tel = TextEditingController(text: widget.perfil.telefono ?? '');
  late String _clavePais = _ladaValida(widget.perfil.clavePaisTelefono);
  // Ocupación: valor del catálogo, o modo "Otro" con texto libre.
  late String? _ocupacion = _esOcupacionOtro(widget.perfil.ocupacion)
      ? null
      : widget.perfil.ocupacion;
  late bool _ocupacionOtro = _esOcupacionOtro(widget.perfil.ocupacion);
  late final _ocupacionOtroCtrl = TextEditingController(
    text: _ocupacionOtro ? (widget.perfil.ocupacion ?? '') : '',
  );
  bool _busy = false;

  // Clave país con bandera.
  static const _claves = <(String, String)>[
    ('+52', '🇲🇽'),
    ('+1', '🇺🇸'),
    ('+34', '🇪🇸'),
    ('+57', '🇨🇴'),
    ('+54', '🇦🇷'),
    ('+56', '🇨🇱'),
  ];

  /// ISO del pais a lada, para los registros que guardaron "MX" en vez de "+52".
  static const _isoALada = <String, String>{
    'MX': '+52',
    'US': '+1',
    'ES': '+34',
    'CO': '+57',
    'AR': '+54',
    'CL': '+56',
  };

  /// El valor del desplegable SIEMPRE tiene que existir en `_claves`: si no,
  /// Flutter revienta con "There should be exactly one item with
  /// DropdownButton's value". El backend devuelve ISO en algunos registros.
  static String _ladaValida(String? guardado) {
    if (guardado == null || guardado.isEmpty) return '+52';
    if (_claves.any((c) => c.$1 == guardado)) return guardado;
    return _isoALada[guardado.toUpperCase()] ?? '+52';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _rfc.dispose();
    _curp.dispose();
    _tel.dispose();
    _ocupacionOtroCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nombre.text.trim().isEmpty) {
      _snack('El nombre completo es requerido');
      return;
    }
    if (!await ensurePerfilPwAuth(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final ocupacion = _normalizarOcupacion(
        _ocupacionOtro ? _ocupacionOtroCtrl.text : _ocupacion,
      );
      await ref
          .read(profilePortProvider)
          .updatePersonalData(
            legalName: _nombre.text.trim(),
            rfc: _rfc.text.trim().toUpperCase(),
            curp: _curp.text.trim().toUpperCase(),
            phoneCountryCode: _clavePais,
            phone: _tel.text.trim(),
            occupation: ocupacion,
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: SozuBrand.green400,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Datos personales actualizados')),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo guardar. Intenta de nuevo.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.person_outline,
      title: 'Datos personales',
      subtitle: 'Actualiza tu información de identificación',
      children: [
        SFieldLabel('Nombre completo', requerido: true),
        TextField(
          controller: _nombre,
          decoration: const InputDecoration(
            hintText: 'Nombre completo o razón social',
          ),
        ),
        const SizedBox(height: 14),
        SFieldLabel('RFC con homoclave'),
        TextField(
          controller: _rfc,
          maxLength: 13,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'AAAA######AAA',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        SFieldLabel('CURP'),
        TextField(
          controller: _curp,
          maxLength: 18,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: '18 caracteres',
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        SFieldLabel('Teléfono'),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                initialValue: _clavePais,
                items: [
                  for (final (clave, bandera) in _claves)
                    DropdownMenuItem(
                      value: clave,
                      child: Text('$bandera $clave'),
                    ),
                ],
                onChanged: (v) => setState(() => _clavePais = v ?? '+52'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _tel,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: const InputDecoration(
                  hintText: '10 dígitos',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SFieldLabel('Ocupación'),
        _PickerField(
          value: _ocupacionOtro ? 'Otro' : _ocupacion,
          placeholder: 'Selecciona tu ocupación...',
          enabled: true,
          onTap: () async {
            final sel = await _pickOption(
              context,
              title: 'Ocupación',
              options: [
                for (final o in _kOcupaciones) (value: o, label: o),
                (value: 'Otro', label: 'Otro'),
              ],
              selected: _ocupacionOtro ? 'Otro' : _ocupacion,
            );
            if (sel == null) return;
            setState(() {
              if (sel == 'Otro') {
                _ocupacionOtro = true;
                _ocupacion = null;
              } else {
                _ocupacionOtro = false;
                _ocupacion = sel;
                _ocupacionOtroCtrl.clear();
              }
            });
          },
        ),
        if (_ocupacionOtro) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _ocupacionOtroCtrl,
            decoration: const InputDecoration(
              hintText: 'Especifica tu ocupación',
            ),
          ),
        ],
        const SizedBox(height: 12),
        const _NoteBox(
          icon: Icons.mail_outline,
          text: 'El correo electrónico no se puede modificar desde aquí.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando...' : 'Guardar cambios'),
        ),
        _CancelButton(onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Editar datos fiscales ───────────────────────────────────────────────────

Future<void> showEditFiscalSheet(BuildContext context, ClientePerfil p) =>
    _showPerfilModal<void>(context, _EditFiscalSheet(perfil: p));

class _EditFiscalSheet extends ConsumerStatefulWidget {
  final ClientePerfil perfil;
  const _EditFiscalSheet({required this.perfil});

  @override
  ConsumerState<_EditFiscalSheet> createState() => _EditFiscalSheetState();
}

class _EditFiscalSheetState extends ConsumerState<_EditFiscalSheet> {
  PerfilCatalogos? _catalogos;
  bool _loadError = false;
  late String? _regimen = widget.perfil.regimen;
  late String? _usoCfdi = widget.perfil.usoCfdi;
  late final _cp = TextEditingController(text: widget.perfil.cp ?? '');
  late final _calle = TextEditingController(text: widget.perfil.calle ?? '');
  late final _numExt = TextEditingController(text: widget.perfil.numExt ?? '');
  late final _numInt = TextEditingController(text: widget.perfil.numInt ?? '');
  late final _colonia = TextEditingController(
    text: widget.perfil.colonia ?? '',
  );
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final c = await ref.read(profilePortProvider).catalogs();
      if (mounted) setState(() => _catalogos = c);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _cp.dispose();
    _calle.dispose();
    _numExt.dispose();
    _numInt.dispose();
    _colonia.dispose();
    super.dispose();
  }

  String? get _regimenLabel {
    if (_regimen == null) return null;
    final match =
        _catalogos?.regimen.where((r) => r.id == _regimen).toList() ?? [];
    return match.isEmpty
        ? (widget.perfil.regimenDisplay ?? _regimen)
        : '${match.first.id} - ${match.first.nombre}';
  }

  String? get _usoCfdiLabel {
    if (_usoCfdi == null) return null;
    final match =
        _catalogos?.usoCfdi.where((u) => u.codigo == _usoCfdi).toList() ?? [];
    return match.isEmpty
        ? (widget.perfil.usoCfdiDisplay ?? _usoCfdi)
        : '${match.first.codigo} - ${match.first.nombre}';
  }

  Future<void> _save() async {
    if (!await ensurePerfilPwAuth(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profilePortProvider)
          .updateTaxData(
            regime: _regimen,
            cfdiUse: _usoCfdi,
            postalCode: _cp.text.trim(),
            street: _calle.text.trim(),
            exteriorNumber: _numExt.text.trim(),
            interiorNumber: _numInt.text.trim(),
            neighborhood: _colonia.text.trim(),
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: SozuBrand.green400,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Datos fiscales actualizados')),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.business_outlined,
      title: 'Datos fiscales',
      subtitle: 'Régimen, CFDI y dirección fiscal',
      children: [
        SFieldLabel('Régimen fiscal'),
        _PickerField(
          value: _regimenLabel,
          placeholder: _loadError
              ? 'Catálogo no disponible'
              : (_catalogos == null
                    ? 'Cargando catálogo...'
                    : 'Buscar régimen fiscal...'),
          enabled: _catalogos != null,
          onTap: () async {
            final sel = await _pickOption(
              context,
              title: 'Régimen fiscal',
              options: [
                for (final r in _catalogos!.regimen)
                  (value: r.id, label: '${r.id} - ${r.nombre}'),
              ],
              selected: _regimen,
            );
            if (sel != null) setState(() => _regimen = sel);
          },
        ),
        const SizedBox(height: 14),
        SFieldLabel('Uso CFDI'),
        _PickerField(
          value: _usoCfdiLabel,
          placeholder: _loadError
              ? 'Catálogo no disponible'
              : (_catalogos == null
                    ? 'Cargando catálogo...'
                    : 'Buscar uso CFDI...'),
          enabled: _catalogos != null,
          onTap: () async {
            final sel = await _pickOption(
              context,
              title: 'Uso CFDI',
              options: [
                for (final u in _catalogos!.usoCfdi)
                  (value: u.codigo, label: '${u.codigo} - ${u.nombre}'),
              ],
              selected: _usoCfdi,
            );
            if (sel != null) setState(() => _usoCfdi = sel);
          },
        ),
        const SizedBox(height: 14),
        SFieldLabel('Código postal'),
        TextField(
          controller: _cp,
          maxLength: 5,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '00000', counterText: ''),
        ),
        const SizedBox(height: 14),
        SFieldLabel('Calle'),
        TextField(
          controller: _calle,
          decoration: const InputDecoration(hintText: 'Nombre de la calle'),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SFieldLabel('Núm. exterior'),
                  TextField(
                    controller: _numExt,
                    decoration: const InputDecoration(hintText: '123'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SFieldLabel('Núm. interior'),
                  TextField(
                    controller: _numInt,
                    decoration: const InputDecoration(hintText: 'A'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SFieldLabel('Colonia'),
        TextField(
          controller: _colonia,
          decoration: const InputDecoration(hintText: 'Nombre de la colonia'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando...' : 'Guardar cambios'),
        ),
        _CancelButton(onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Agregar / editar cuenta bancaria ────────────────────────────────────────

Future<void> showCuentaBancariaSheet(
  BuildContext context, {
  CuentaBancariaPerfil? cuenta,
}) => showSDocModal<void>(context, child: _CuentaSheet(cuenta: cuenta));

class _CuentaSheet extends ConsumerStatefulWidget {
  final CuentaBancariaPerfil? cuenta;
  const _CuentaSheet({this.cuenta});

  @override
  ConsumerState<_CuentaSheet> createState() => _CuentaSheetState();
}

class _CuentaSheetState extends ConsumerState<_CuentaSheet> {
  PerfilCatalogos? _catalogos;
  bool _loadError = false;
  late int? _idBanco = widget.cuenta?.idBanco;
  late String? _bancoNombre = widget.cuenta?.banco;
  late final _numeroCuenta = TextEditingController(
    text: widget.cuenta?.numeroCuenta ?? '',
  );
  late final _clabe = TextEditingController(text: widget.cuenta?.clabe ?? '');
  late final _swift = TextEditingController(text: widget.cuenta?.swift ?? '');
  late final _titular = TextEditingController(
    text: widget.cuenta?.titular ?? '',
  );

  // Carátula del estado de cuenta: requerida en el alta.
  String? _evidenciaNombre;
  Uint8List? _evidenciaBytes;
  bool _titularAuto = false;
  bool _busy = false;

  bool get _isEdit => widget.cuenta != null;

  bool get _valid {
    final num = _numeroCuenta.text.trim();
    final clabe = _clabe.text.trim();
    final swift = _swift.text.trim();
    final numOk = num.length >= 8 && num.length <= 34;
    final clabeOk = clabe.isEmpty || clabe.length == 18;
    final swiftOk = swift.isEmpty || swift.length == 8 || swift.length == 11;
    // La carátula es obligatoria en el alta; al editar no se re-sube.
    final evidenciaOk = _isEdit || _evidenciaBytes != null;
    return _idBanco != null &&
        numOk &&
        clabeOk &&
        swiftOk &&
        _titular.text.trim().isNotEmpty &&
        evidenciaOk;
  }

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final c = await ref.read(profilePortProvider).catalogs();
      if (mounted) setState(() => _catalogos = c);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _numeroCuenta.dispose();
    _clabe.dispose();
    _swift.dispose();
    _titular.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _contentType(String nombre) {
    switch (nombre.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<({String nombre, Uint8List bytes})?> _pickEvidencia() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Evidencia',
          extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null) return null;
    return (nombre: file.name, bytes: await file.readAsBytes());
  }

  /// Recibe la carátula del selector o del arrastre.
  void _adjuntarEvidencia(String nombre, Uint8List bytes) {
    if (bytes.length > 10 * 1024 * 1024) {
      _snack('El archivo supera el límite de 10 MB.');
      return;
    }
    setState(() {
      _evidenciaBytes = bytes;
      _evidenciaNombre = nombre;
    });
  }

  /// PDF con el visor del sistema de diseño; imagen tal cual.
  Widget _vistaEvidencia() {
    final bytes = _evidenciaBytes!;
    final esPdf = (_evidenciaNombre ?? '').toLowerCase().endsWith('.pdf');
    if (esPdf) return SPdfPreview(bytes: bytes, nombre: _evidenciaNombre);
    return ClipRRect(
      borderRadius: context.s.radius.mdBorder,
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }

  /// Alta de un banco nuevo al catálogo.
  Future<String?> _agregarBanco(String nombre) async {
    try {
      final port = ref.read(profilePortProvider);
      final b = await port.addBankToCatalog(nombre);
      final c = await port.catalogs();
      if (!mounted) return null;
      setState(() => _catalogos = c);
      return '${b.id}';
    } catch (_) {
      if (mounted) _snack('No se pudo agregar el banco. Intenta de nuevo.');
      return null;
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    // Editar una cuenta existente exige contraseña; el alta, no.
    if (_isEdit && !await ensurePerfilPwAuth(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final clabe = _clabe.text.trim();
      final swift = _swift.text.trim();
      final b64 = _evidenciaBytes != null
          ? base64Encode(_evidenciaBytes!)
          : null;
      final ct = _evidenciaNombre != null
          ? _contentType(_evidenciaNombre!)
          : null;
      final port = ref.read(profilePortProvider);
      if (_isEdit) {
        await port.updateBankAccount(
          accountId: widget.cuenta!.id,
          bankId: _idBanco!,
          accountNumber: _numeroCuenta.text.trim(),
          clabe: clabe.isEmpty ? null : clabe,
          swift: swift.isEmpty ? null : swift,
          holder: _titular.text.trim(),
          evidenceBase64: b64,
          evidenceFileName: _evidenciaNombre,
          evidenceContentType: ct,
        );
      } else {
        await port.addBankAccount(
          bankId: _idBanco!,
          accountNumber: _numeroCuenta.text.trim(),
          clabe: clabe.isEmpty ? null : clabe,
          swift: swift.isEmpty ? null : swift,
          holder: _titular.text.trim(),
          evidenceBase64: b64,
          evidenceFileName: _evidenciaNombre,
          evidenceContentType: ct,
        );
      }
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Cuenta bancaria actualizada'
                : 'Cuenta bancaria registrada',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final nombreLegal = ref.watch(profileProvider).valueOrNull?.nombreLegal;
    return SDocUploadLayout(
      titulo: _isEdit ? 'Editar cuenta bancaria' : 'Nueva cuenta bancaria',
      descripcion: _isEdit
          ? 'Corrige los datos y revisa la carátula antes de guardar'
          : 'SOZU usará esta cuenta para depósitos. Adjunta la carátula y '
                'revísala antes de guardar',
      apilado: !context.bp.hasTwoColumns,
      preview: _evidenciaBytes != null ? _vistaEvidencia() : null,
      etiquetaGuardar: _isEdit ? 'Guardar cambios' : 'Guardar cuenta',
      etiquetaGuardando: 'Guardando…',
      guardando: _busy,
      onGuardar: (!_valid || _busy) ? null : _save,
      izquierda: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SFieldLabel('Banco', requerido: true),
          _PickerField(
            value: _bancoNombre,
            placeholder: _loadError
                ? 'Catálogo no disponible'
                : (_catalogos == null
                      ? 'Cargando bancos...'
                      : 'Buscar banco...'),
            enabled: _catalogos != null,
            onTap: () async {
              final sel = await _pickOption(
                context,
                title: 'Banco',
                options: [
                  for (final b in _catalogos!.bancos)
                    (value: '${b.id}', label: b.nombre),
                ],
                selected: _idBanco?.toString(),
                onAddNew: _agregarBanco,
              );
              if (sel != null) {
                setState(() {
                  _idBanco = int.tryParse(sel);
                  _bancoNombre = _catalogos!.bancos
                      .where((b) => '${b.id}' == sel)
                      .map((b) => b.nombre)
                      .firstOrNull;
                });
              }
            },
          ),
          SizedBox(height: context.s.space.sm),
          SFieldLabel('Número de cuenta', requerido: true),
          STextField(
            controller: _numeroCuenta,
            hint: 'Entre 8 y 34 caracteres',
            size: STextFieldSize.md,
            maxLength: 34,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
            ],
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.s.space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SFieldLabel('CLABE'),
                    STextField(
                      controller: _clabe,
                      hint: '18 dígitos (opcional)',
                      size: STextFieldSize.md,
                      maxLength: 18,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.s.space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SFieldLabel('Código SWIFT'),
                    STextField(
                      controller: _swift,
                      hint: '8 u 11 (opcional)',
                      size: STextFieldSize.md,
                      maxLength: 11,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9A-Za-z]'),
                        ),
                        TextInputFormatter.withFunction(
                          (_, n) => n.copyWith(text: n.text.toUpperCase()),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.s.space.sm),
          SFieldLabel('Titular de la cuenta', requerido: true),
          if ((nombreLegal ?? '').trim().isNotEmpty)
            InkWell(
              onTap: () => setState(() {
                _titularAuto = !_titularAuto;
                _titular.text = _titularAuto ? nombreLegal!.trim() : '';
              }),
              borderRadius: context.s.radius.mdBorder,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.s.space.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _titularAuto,
                        onChanged: (v) => setState(() {
                          _titularAuto = v ?? false;
                          _titular.text = _titularAuto
                              ? nombreLegal!.trim()
                              : '';
                        }),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(width: context.s.space.xs),
                    Expanded(
                      child: Text(
                        'El titular es $nombreLegal',
                        style: context.s.text.caption.copyWith(
                          color: tone.fgMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: context.s.space.xxs),
          STextField(
            controller: _titular,
            hint: 'Nombre completo del titular',
            size: STextFieldSize.md,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.s.space.sm),
          SFieldLabel('Evidencia', requerido: !_isEdit),
          SDropZone(
            titulo: _evidenciaNombre ?? 'Adjuntar carátula',
            subtitulo: _isEdit
                ? 'Reemplaza la carátula (opcional)'
                : 'Carátula de tu estado de cuenta, en PDF o imagen',
            archivo: _evidenciaNombre,
            onSeleccionar: _pickEvidencia,
            onArchivo: _adjuntarEvidencia,
          ),
        ],
      ),
    );
  }
}

// ─── Cambiar contraseña (diálogo centrado en modo portal) ────────────────────

/// Cambio de contraseña: diálogo centrado en web ancha, sheet en móvil.
Future<void> showCambiarPasswordDialog(BuildContext context) =>
    _showPerfilModal<void>(context, const _CambiarPasswordSheet());

class _CambiarPasswordSheet extends ConsumerStatefulWidget {
  const _CambiarPasswordSheet();

  @override
  ConsumerState<_CambiarPasswordSheet> createState() =>
      _CambiarPasswordSheetState();
}

class _CambiarPasswordSheetState extends ConsumerState<_CambiarPasswordSheet> {
  final _current = TextEditingController();
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String _pwdValue = '';

  @override
  void dispose() {
    _current.dispose();
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valido =>
      _current.text.isNotEmpty &&
      isValidPassword(_pwdValue) &&
      _pwd.text != _current.text &&
      _confirm.text == _pwd.text;

  Future<void> _guardar() async {
    if (!_valido || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).changePassword(_current.text, _pwd.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } on WrongCurrentPasswordError {
      if (!mounted) return;
      setState(() {
        _error = 'La contraseña actual es incorrecta.';
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos actualizar la contraseña. Intenta de nuevo.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return _SheetShell(
      icon: Icons.lock_outline,
      title: 'Cambiar contraseña',
      subtitle: 'Actualiza tu contraseña de acceso',
      children: [
        SFieldLabel('Contraseña actual'),
        TextField(
          controller: _current,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        const SizedBox(height: 14),
        SFieldLabel('Nueva contraseña'),
        TextField(
          controller: _pwd,
          obscureText: true,
          onChanged: (v) => setState(() => _pwdValue = v),
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        const SizedBox(height: 10),
        PasswordRulesChecklist(value: _pwdValue),
        const SizedBox(height: 14),
        SFieldLabel('Confirmar nueva contraseña'),
        TextField(
          controller: _confirm,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        if (_pwd.text.isNotEmpty && _pwd.text == _current.text) ...[
          const SizedBox(height: 8),
          Text(
            'La nueva contraseña debe ser distinta a la actual.',
            style: TextStyle(fontSize: 12, color: tone.danger),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tone.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 13, color: tone.danger),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (_valido && !_busy) ? _guardar : null,
          child: Text(_busy ? 'Guardando...' : 'Actualizar contraseña'),
        ),
        _CancelButton(onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Foto de perfil (avatar) ─────────────────────────────────────────────────

/// Gestión de la foto de perfil: subir/cambiar y, si ya hay, eliminar.
/// Invalida el perfil al terminar.
Future<void> showAvatarSheet(BuildContext context, ClientePerfil p) =>
    _showPerfilModal<void>(context, _AvatarSheet(perfil: p));

class _AvatarSheet extends ConsumerStatefulWidget {
  final ClientePerfil perfil;
  const _AvatarSheet({required this.perfil});

  @override
  ConsumerState<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends ConsumerState<_AvatarSheet> {
  bool _busy = false;

  bool get _tieneFoto => (widget.perfil.fotoPerfilUrl ?? '').isNotEmpty;

  /// Deriva el mime de la extensión (png/jpg/jpeg/webp); default image/jpeg.
  String _mimeFor(String nombre) {
    switch (nombre.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _subir() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Imagen', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      _snack('La imagen supera el límite de 10 MB.');
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profilePortProvider)
          .uploadAvatar(base64: base64Encode(bytes), mime: _mimeFor(file.name));
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: SozuBrand.green400,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Foto de perfil actualizada')),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo subir la foto. Intenta de nuevo.');
    }
  }

  Future<void> _eliminar() async {
    final tone = context.s.color;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Seguro que quieres eliminar tu foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: tone.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(profilePortProvider).deleteAvatar();
      ref.invalidate(profileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto de perfil eliminada')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo eliminar la foto. Intenta de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return _SheetShell(
      icon: Icons.photo_camera_outlined,
      title: 'Foto de perfil',
      subtitle: 'Así te verán en tu portal',
      children: [
        if (_tieneFoto) ...[
          Center(
            child: ClipOval(
              child: SizedBox(
                width: 96,
                height: 96,
                child: SozuNetworkImage(
                  url: widget.perfil.fotoPerfilUrl,
                  placeholderIcon: Icons.person_outline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : _subir,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.upload_outlined, size: 18),
          label: Text(_tieneFoto ? 'Cambiar foto' : 'Subir foto'),
        ),
        if (_tieneFoto) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _eliminar,
            icon: Icon(Icons.delete_outline, size: 18, color: tone.danger),
            style: OutlinedButton.styleFrom(
              foregroundColor: tone.danger,
              side: BorderSide(color: tone.danger.withValues(alpha: 0.3)),
            ),
            label: const Text('Eliminar foto'),
          ),
        ],
        _CancelButton(onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Piezas compartidas ──────────────────────────────────────────────────────

/// Selector con búsqueda para los catálogos de régimen/CFDI/bancos. Con
/// [onAddNew], si el texto buscado no existe ofrece "Agregar «q»" y devuelve el
/// value creado.
Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required List<({String value, String label})> options,
  String? selected,
  Future<String?> Function(String nombre)? onAddNew,
}) => _showPerfilModal<String>(
  context,
  _OptionPicker(
    title: title,
    options: options,
    selected: selected,
    onAddNew: onAddNew,
  ),
);

class _OptionPicker extends StatefulWidget {
  final String title;
  final List<({String value, String label})> options;
  final String? selected;
  final Future<String?> Function(String nombre)? onAddNew;

  const _OptionPicker({
    required this.title,
    required this.options,
    this.selected,
    this.onAddNew,
  });

  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  String _q = '';
  bool _adding = false;

  Future<void> _add() async {
    final nombre = _q.trim();
    if (nombre.isEmpty || widget.onAddNew == null) return;
    setState(() => _adding = true);
    final value = await widget.onAddNew!(nombre);
    if (!mounted) return;
    if (value != null) {
      Navigator.pop(context, value);
    } else {
      setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.label.toLowerCase().contains(q))
              .toList();
    // "Agregar «q»" cuando hay callback, la búsqueda es ≥2 y no hay match exacto.
    final puedeAgregar =
        widget.onAddNew != null &&
        q.length >= 2 &&
        !widget.options.any((o) => o.label.toLowerCase() == q);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tone.fg,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length + (puedeAgregar ? 1 : 0),
              itemBuilder: (context, i) {
                if (puedeAgregar && i == filtered.length) {
                  return ListTile(
                    dense: true,
                    leading: _adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add, size: 20, color: tone.primaryHover),
                    title: Text(
                      'Agregar «${_q.trim()}»',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tone.primaryHover,
                      ),
                    ),
                    onTap: _adding ? null : _add,
                  );
                }
                final o = filtered[i];
                final isSel = o.value == widget.selected;
                return ListTile(
                  dense: true,
                  tileColor: isSel ? tone.primarySoft : null,
                  title: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? tone.primaryHover : tone.fg,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, o.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de solo lectura que abre un selector al tocarlo.
class _PickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerField({
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.expand_more, size: 20),
        ),
        child: Text(
          value ?? placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: value != null ? tone.fg : tone.fgSubtle,
          ),
        ),
      ),
    );
  }
}

/// Contenedor común de los sheets: header con icono + título + cerrar.
class _SheetShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SheetShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tone.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: tone.fgMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: tone.fg,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: tone.fgSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(color: tone.border, height: 28),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: tone.fgSubtle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: tone.fgMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = context.s.color;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: tone.danger),
        child: const Text(
          'Cancelar',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
