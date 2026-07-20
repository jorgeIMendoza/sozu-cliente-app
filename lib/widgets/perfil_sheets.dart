import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/portal_theme.dart';
import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import 'password_rules.dart';
import 'portal_widgets.dart' show showPortalDialog;

/// Sheets de edición del Perfil (espejo de los modales de ClientePerfil.tsx
/// del portal): datos personales, datos fiscales y cuentas bancarias, con
/// verificación de contraseña previa a guardar (gate de 90 s como el portal).
/// En modo portal (web ≥1024) se muestran como diálogos centrados (max
/// ~560px), igual que los Dialog del portal web; en móvil siguen siendo
/// bottom sheets.

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

class _PwGateSheet extends StatefulWidget {
  const _PwGateSheet();

  @override
  State<_PwGateSheet> createState() => _PwGateSheetState();
}

class _PwGateSheetState extends State<_PwGateSheet> {
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
    final sb = Supabase.instance.client;
    final email = sb.auth.currentSession?.user.email;
    if (email == null || _pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sb.auth.signInWithPassword(email: email, password: _pw.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _error = 'Contraseña incorrecta';
        _busy = false;
      });
    } catch (_) {
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
        _FieldLabel('Contraseña actual'),
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
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility,
                  size: 20),
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
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Continuar'),
        ),
        _CancelButton(onTap: () => Navigator.pop(context, false)),
      ],
    );
  }
}

// ─── Editar datos personales ─────────────────────────────────────────────────

Future<void> showEditPersonalSheet(BuildContext context, ClientePerfil p) =>
    _showPerfilModal<void>(context, _EditPersonalSheet(perfil: p));

class _EditPersonalSheet extends ConsumerStatefulWidget {
  final ClientePerfil perfil;
  const _EditPersonalSheet({required this.perfil});

  @override
  ConsumerState<_EditPersonalSheet> createState() =>
      _EditPersonalSheetState();
}

class _EditPersonalSheetState extends ConsumerState<_EditPersonalSheet> {
  late final _nombre = TextEditingController(text: widget.perfil.nombreLegal);
  late final _rfc = TextEditingController(text: widget.perfil.rfc ?? '');
  late final _curp = TextEditingController(text: widget.perfil.curp ?? '');
  late final _tel = TextEditingController(text: widget.perfil.telefono ?? '');
  late String _clavePais = widget.perfil.clavePaisTelefono ?? '+52';
  bool _busy = false;

  // Clave país con bandera, como el <select> del portal (ClientePerfil.tsx).
  static const _claves = <(String, String)>[
    ('+52', '🇲🇽'),
    ('+1', '🇺🇸'),
    ('+34', '🇪🇸'),
    ('+57', '🇨🇴'),
    ('+54', '🇦🇷'),
    ('+56', '🇨🇱'),
  ];

  @override
  void dispose() {
    _nombre.dispose();
    _rfc.dispose();
    _curp.dispose();
    _tel.dispose();
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
      await updatePerfilPersonal(
        nombreLegal: _nombre.text.trim(),
        rfc: _rfc.text.trim().toUpperCase(),
        curp: _curp.text.trim().toUpperCase(),
        clavePaisTelefono: _clavePais,
        telefono: _tel.text.trim(),
      );
      ref.invalidate(clientePerfilProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: SozuColors.emerald400),
            SizedBox(width: 8),
            Expanded(child: Text('Datos personales actualizados')),
          ],
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo guardar. Intenta de nuevo.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.person_outline,
      title: 'Datos personales',
      subtitle: 'Actualiza tu información de identificación',
      children: [
        _FieldLabel('Nombre completo *'),
        TextField(
          controller: _nombre,
          decoration:
              const InputDecoration(hintText: 'Nombre completo o razón social'),
        ),
        const SizedBox(height: 14),
        _FieldLabel('RFC con homoclave'),
        TextField(
          controller: _rfc,
          maxLength: 13,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              hintText: 'AAAA######AAA', counterText: ''),
        ),
        const SizedBox(height: 14),
        _FieldLabel('CURP'),
        TextField(
          controller: _curp,
          maxLength: 18,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              hintText: '18 caracteres', counterText: ''),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Teléfono'),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                initialValue: _clavePais,
                items: [
                  for (final (clave, bandera) in _claves)
                    DropdownMenuItem(value: clave, child: Text('$bandera $clave')),
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
                    hintText: '10 dígitos', counterText: ''),
              ),
            ),
          ],
        ),
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
  late final _numExt =
      TextEditingController(text: widget.perfil.numExt ?? '');
  late final _numInt =
      TextEditingController(text: widget.perfil.numInt ?? '');
  late final _colonia =
      TextEditingController(text: widget.perfil.colonia ?? '');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final c = await fetchPerfilCatalogos();
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
        : '${match.first.id} — ${match.first.nombre}';
  }

  String? get _usoCfdiLabel {
    if (_usoCfdi == null) return null;
    final match =
        _catalogos?.usoCfdi.where((u) => u.codigo == _usoCfdi).toList() ?? [];
    return match.isEmpty
        ? (widget.perfil.usoCfdiDisplay ?? _usoCfdi)
        : '${match.first.codigo} — ${match.first.nombre}';
  }

  Future<void> _save() async {
    if (!await ensurePerfilPwAuth(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await updatePerfilFiscal(
        regimen: _regimen,
        usoCfdi: _usoCfdi,
        codigoPostal: _cp.text.trim(),
        calle: _calle.text.trim(),
        numExt: _numExt.text.trim(),
        numInt: _numInt.text.trim(),
        colonia: _colonia.text.trim(),
      );
      ref.invalidate(clientePerfilProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 18, color: SozuColors.emerald400),
            SizedBox(width: 8),
            Expanded(child: Text('Datos fiscales actualizados')),
          ],
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar. Intenta de nuevo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.business_outlined,
      title: 'Datos fiscales',
      subtitle: 'Régimen, CFDI y dirección fiscal',
      children: [
        _FieldLabel('Régimen fiscal'),
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
                  (value: r.id, label: '${r.id} — ${r.nombre}'),
              ],
              selected: _regimen,
            );
            if (sel != null) setState(() => _regimen = sel);
          },
        ),
        const SizedBox(height: 14),
        _FieldLabel('Uso CFDI'),
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
                  (value: u.codigo, label: '${u.codigo} — ${u.nombre}'),
              ],
              selected: _usoCfdi,
            );
            if (sel != null) setState(() => _usoCfdi = sel);
          },
        ),
        const SizedBox(height: 14),
        _FieldLabel('Código postal'),
        TextField(
          controller: _cp,
          maxLength: 5,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration:
              const InputDecoration(hintText: '00000', counterText: ''),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Calle'),
        TextField(
          controller: _calle,
          decoration:
              const InputDecoration(hintText: 'Nombre de la calle'),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Núm. exterior'),
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
                  _FieldLabel('Núm. interior'),
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
        _FieldLabel('Colonia'),
        TextField(
          controller: _colonia,
          decoration:
              const InputDecoration(hintText: 'Nombre de la colonia'),
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
}) =>
    _showPerfilModal<void>(context, _CuentaSheet(cuenta: cuenta));

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
  late final _clabe = TextEditingController(text: widget.cuenta?.clabe ?? '');
  late final _titular =
      TextEditingController(text: widget.cuenta?.titular ?? '');
  bool _busy = false;

  bool get _isEdit => widget.cuenta != null;
  bool get _valid =>
      _idBanco != null && _clabe.text.length == 18 && _titular.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  Future<void> _loadCatalogos() async {
    try {
      final c = await fetchPerfilCatalogos();
      if (mounted) setState(() => _catalogos = c);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _clabe.dispose();
    _titular.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid) return;
    // El portal exige contraseña al EDITAR una cuenta existente; el alta no.
    if (_isEdit && !await ensurePerfilPwAuth(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await updateCuentaBancaria(
          id: widget.cuenta!.id,
          idBanco: _idBanco!,
          cuentaClabe: _clabe.text,
          titular: _titular.text.trim(),
        );
      } else {
        await addCuentaBancaria(
          idBanco: _idBanco!,
          cuentaClabe: _clabe.text,
          titular: _titular.text.trim(),
        );
      }
      ref.invalidate(clientePerfilProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text(_isEdit
              ? 'Cuenta bancaria actualizada'
              : 'Cuenta bancaria registrada')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar. Intenta de nuevo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      icon: Icons.credit_card_outlined,
      title: _isEdit ? 'Editar cuenta bancaria' : 'Agregar cuenta bancaria',
      subtitle: _isEdit
          ? 'Corrige los datos de tu cuenta'
          : 'SOZU usará esta cuenta para depósitos',
      children: [
        _FieldLabel('Banco *'),
        _PickerField(
          value: _bancoNombre,
          placeholder: _loadError
              ? 'Catálogo no disponible'
              : (_catalogos == null ? 'Cargando bancos...' : 'Buscar banco...'),
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
        const SizedBox(height: 14),
        _FieldLabel('CLABE interbancaria *'),
        TextField(
          controller: _clabe,
          maxLength: 18,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration:
              const InputDecoration(hintText: '18 dígitos', counterText: ''),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Titular de la cuenta *'),
        TextField(
          controller: _titular,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              hintText: 'Nombre completo del titular'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (!_valid || _busy) ? null : _save,
          child: Text(_busy
              ? 'Guardando...'
              : (_isEdit ? 'Guardar cambios' : 'Guardar cuenta')),
        ),
        _CancelButton(onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ─── Cambiar contraseña (diálogo centrado en modo portal) ────────────────────

/// Abre el cambio de contraseña como diálogo centrado del portal (web ≥1024)
/// o bottom sheet en móvil — espejo del modal "Cambiar contraseña" de
/// ClientePerfil.tsx, en vez de una ruta full-page.
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
      passwordValida(_pwdValue) &&
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
      messenger.showSnackBar(const SnackBar(
        content: Text('Contraseña actualizada correctamente'),
      ));
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
    final tone = SozuTone.of(context);
    return _SheetShell(
      icon: Icons.lock_outline,
      title: 'Cambiar contraseña',
      subtitle: 'Actualiza tu contraseña de acceso',
      children: [
        _FieldLabel('Contraseña actual'),
        TextField(
          controller: _current,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        const SizedBox(height: 14),
        _FieldLabel('Nueva contraseña'),
        TextField(
          controller: _pwd,
          obscureText: true,
          onChanged: (v) => setState(() => _pwdValue = v),
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        const SizedBox(height: 10),
        PasswordRulesChecklist(value: _pwdValue),
        const SizedBox(height: 14),
        _FieldLabel('Confirmar nueva contraseña'),
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
            style: TextStyle(fontSize: 12, color: tone.negative),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tone.negative.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!,
                style: TextStyle(fontSize: 13, color: tone.negative)),
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

// ─── Piezas compartidas ──────────────────────────────────────────────────────

/// Selector con búsqueda (bottom sheet): catálogos de régimen/CFDI/bancos.
Future<String?> _pickOption(
  BuildContext context, {
  required String title,
  required List<({String value, String label})> options,
  String? selected,
}) =>
    _showPerfilModal<String>(
      context,
      _OptionPicker(title: title, options: options, selected: selected),
    );

class _OptionPicker extends StatefulWidget {
  final String title;
  final List<({String value, String label})> options;
  final String? selected;

  const _OptionPicker({
    required this.title,
    required this.options,
    this.selected,
  });

  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final filtered = _q.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tone.textPrimary)),
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
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final o = filtered[i];
                final isSel = o.value == widget.selected;
                return ListTile(
                  dense: true,
                  tileColor: isSel ? tone.primarySoft : null,
                  title: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? tone.primaryDark : tone.textPrimary,
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
    final tone = SozuTone.of(context);
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
            color: value != null ? tone.textPrimary : tone.textMuted,
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
    final tone = SozuTone.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      child:
                          Icon(icon, size: 18, color: tone.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: tone.textPrimary)),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 12, color: tone.textMuted)),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tone.textPrimary)),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NoteBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: tone.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: tone.textSecondary)),
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
    final tone = SozuTone.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: tone.negative),
        child: const Text('Cancelar',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
