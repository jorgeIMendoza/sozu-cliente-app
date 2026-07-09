import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/impersonation_provider.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';

/// Selector de cliente para super administradores (solo web).
/// El admin elige un cliente y navega el portal viendo sus datos.
class SeleccionarClienteScreen extends ConsumerStatefulWidget {
  const SeleccionarClienteScreen({super.key});

  @override
  ConsumerState<SeleccionarClienteScreen> createState() =>
      _SeleccionarClienteScreenState();
}

class _SeleccionarClienteScreenState
    extends ConsumerState<SeleccionarClienteScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _minQueryLength = 2;

  bool get _queryTooShort => _query.trim().length < _minQueryLength;

  List<AdminCliente> _filtrar(List<AdminCliente> clientes) {
    final q = _query.trim().toLowerCase();
    if (q.length < _minQueryLength) return const [];
    return clientes
        .where(
          (c) =>
              c.nombre.toLowerCase().contains(q) ||
              (c.email ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    final auth = ref.watch(authProvider);
    final imp = ref.watch(impersonationProvider);
    final clientes = ref.watch(adminClientesProvider);

    return Scaffold(
      backgroundColor: tone.surface,
      appBar: AppBar(
        title: const Text('Selecciona un cliente'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/admin-avisos'),
            icon: Icon(
              Icons.campaign_outlined,
              size: 18,
              color: tone.primaryDark,
            ),
            label: Text(
              'Enviar avisos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tone.primaryDark,
              ),
            ),
          ),
          if (imp.active)
            TextButton(
              onPressed: () => context.go('/inicio'),
              child: Text(
                'Volver al portal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tone.primaryDark,
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider).signOut();
            },
            child: Text(
              'Cerrar sesión',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tone.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: WebFrame(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso administrador · ${auth.profile?.nombre ?? auth.profile?.email ?? ''}',
                    style: TextStyle(fontSize: 13, color: tone.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o correo…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: clientes.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(height: 18),
                          SizedBox(height: 8),
                          Skeleton(width: 200, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                error: (_, __) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorCard(
                      title: 'No pudimos cargar la lista de clientes',
                      onRetry: () => ref.invalidate(adminClientesProvider),
                    ),
                  ],
                ),
                data: (data) {
                  if (_queryTooShort) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: tone.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_search_outlined,
                              size: 30,
                              color: tone.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Busca un cliente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tone.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Escribe al menos $_minQueryLength letras del '
                            'nombre o correo.',
                            style: TextStyle(
                              fontSize: 14,
                              color: tone.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final lista = _filtrar(data.clientes);
                  if (lista.isEmpty) {
                    return Center(
                      child: Text(
                        'Sin resultados para "$_query".',
                        style: TextStyle(
                          fontSize: 14,
                          color: tone.textSecondary,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = lista[i];
                      final seleccionado = imp.idPersona == c.idPersona;
                      return AppCard(
                        borderColor: seleccionado ? tone.primaryDark : null,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            c.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tone.textPrimary,
                            ),
                          ),
                          subtitle: c.email == null
                              ? null
                              : Text(
                                  c.email!,
                                  style: TextStyle(color: tone.textSecondary),
                                ),
                          trailing: seleccionado
                              ? const StatusBadge(
                                  label: 'Viendo',
                                  tone: BadgeTone.positive,
                                )
                              : Icon(
                                  Icons.chevron_right,
                                  color: tone.textMuted,
                                ),
                          onTap: () {
                            ref
                                .read(impersonationProvider)
                                .select(c.idPersona, c.nombre, c.email);
                            context.go('/inicio');
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
