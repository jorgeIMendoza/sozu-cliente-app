import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Placeholder de pago. La pasarela real (STP/Stripe) se define aparte.
class PagarScreen extends StatelessWidget {
  final String? referencia;

  const PagarScreen({super.key, this.referencia});

  @override
  Widget build(BuildContext context) {
    final tone = SozuTone.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: tone.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.credit_card_outlined,
                    size: 30, color: SozuColors.emerald600),
              ),
              const SizedBox(height: 16),
              Text('Pago en línea próximamente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tone.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'La pasarela de pago (SPEI/tarjeta) estará disponible pronto. '
                'Mientras tanto, contacta a tu asesor SOZU para liquidar este cargo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: tone.textSecondary),
              ),
              if (referencia != null) ...[
                const SizedBox(height: 16),
                Text('Referencia de cargo: #$referencia',
                    style: TextStyle(fontSize: 12, color: tone.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
