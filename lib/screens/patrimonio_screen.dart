import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../providers/data_providers.dart';
import '../widgets/common.dart';
import '../widgets/fx.dart';
import '../widgets/portal_top_bar.dart';
import '../widgets/property_card.dart';

/// Mi patrimonio: propiedades entregadas + KPIs.
class PatrimonioScreen extends ConsumerWidget {
  const PatrimonioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = SozuTone.of(context);
    final props = ref.watch(clientePropiedadesProvider);

    return Scaffold(
      appBar: const PortalTopBar(title: 'Mi patrimonio'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientePropiedadesProvider);
          try {
            await ref.read(clientePropiedadesProvider.future);
          } catch (_) {}
        },
        child: props.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(
                child: Column(
                  children: [
                    Skeleton(height: 160, radius: 12),
                    SizedBox(height: 12),
                    Skeleton(height: 16),
                  ],
                ),
              ),
            ],
          ),
          error: (_, __) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorCard(
                title: 'No pudimos cargar tus propiedades',
                onRetry: () => ref.invalidate(clientePropiedadesProvider),
              ),
            ],
          ),
          data: (data) => ContentFrame(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text('Tus propiedades entregadas',
                  style: TextStyle(fontSize: 14, color: tone.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Valor actual',
                              style: TextStyle(
                                  fontSize: 11, color: tone.textMuted)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatMXN(data.totalActivo),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: tone.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Unidades activas',
                              style: TextStyle(
                                  fontSize: 11, color: tone.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            '${data.patrimonioActivo.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tone.positive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (data.patrimonioActivo.isEmpty)
                const EmptyCard(
                  icon: Icons.account_balance_wallet_outlined,
                  text: 'Aún no tienes propiedades entregadas.',
                )
              else
                ResponsiveCardGrid(
                  children: [
                    for (final it in data.patrimonioActivo)
                      PropertyCardWidget(
                          item: it,
                          onTap: () => context.push('/propiedad/${it.id}')),
                  ],
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
