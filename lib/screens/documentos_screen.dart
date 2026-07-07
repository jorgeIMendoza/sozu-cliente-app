import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/open_media.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/portal_top_bar.dart';

/// Documentos del cliente agrupados por tipo; abre URL firmada temporal.
class DocumentosScreen extends ConsumerWidget {
  const DocumentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final docs = ref.watch(clienteDocumentosProvider);

    return Scaffold(
      appBar: const PortalTopBar(title: 'Documentos'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clienteDocumentosProvider);
          try {
            await ref.read(clienteDocumentosProvider.future);
          } catch (_) {}
        },
        child: docs.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18),
                    SizedBox(height: 10),
                    Skeleton(width: 200, height: 14),
                    SizedBox(height: 10),
                    Skeleton(width: 260, height: 14),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus documentos',
                onRetry: () => ref.invalidate(clienteDocumentosProvider),
              ),
            ],
          ),
          data: (data) {
            if (data.documentos.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyCard(
                    icon: Icons.folder_open_outlined,
                    text: 'Aún no tienes documentos disponibles.',
                  ),
                ],
              );
            }
            // Agrupar por tipo.
            final grupos = <String, List<DocumentoItem>>{};
            for (final d in data.documentos) {
              grupos.putIfAbsent(d.tipo, () => []).add(d);
            }
            return ContentFrame(
              maxWidth: 900,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Text(
                  '${data.total} documento${data.total == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 14, color: tone.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final e in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      e.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tone.textMuted,
                      ),
                    ),
                  ),
                  for (final d in e.value) ...[
                    _DocRow(d: d),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final DocumentoItem d;

  const _DocRow({required this.d});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return GestureDetector(
      onTap: () => openMedia(context, d.urlFirmada, titulo: d.nombre),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: tone.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.description_outlined,
                  size: 20, color: SozuColors.emerald600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tone.textPrimary)),
                  Text(formatDate(d.fecha),
                      style:
                          TextStyle(fontSize: 12, color: tone.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 20, color: SozuColors.emerald600),
          ],
        ),
      ),
    );
  }
}
