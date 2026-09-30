import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';

/// Fila de 5 estrellas en medios (4.5 = cuatro llenas y media).
class Estrellas extends StatelessWidget {
  const Estrellas({super.key, required this.valor, this.tamano = 20});

  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final v = valor.clamp(0, 5);
    return Semantics(
      label: '${_legible(v.toDouble())} de 5 estrellas',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              v >= i
                  ? Icons.star_rounded
                  : v >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: tamano,
              color: MoblarColors.amber,
            ),
        ],
      ),
    );
  }

  static String _legible(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Renglón de una habilidad: título, estrellas (o "Aún sin calificaciones")
/// y de dónde sale la calificación.
class RenglonHabilidad extends StatelessWidget {
  const RenglonHabilidad({super.key, required this.habilidad});

  final Habilidad habilidad;

  @override
  Widget build(BuildContext context) {
    final e = habilidad.estrellas;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habilidad.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: MoblarColors.textPrimary,
                  ),
                ),
              ),
              if (e != null)
                Estrellas(valor: e)
              else
                const Text(
                  'Sin calificar',
                  style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                ),
            ],
          ),
          if (habilidad.detalle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              habilidad.detalle,
              style: const TextStyle(fontSize: 12, color: MoblarColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
