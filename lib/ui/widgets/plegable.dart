import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../util/formato.dart';

// ---------------------------------------------------------------------------
// Tarjetas que se abren y se cierran (Carlos, 2026-10-26): cerradas solo
// enseñan lo esencial (foto, mueble, estado y precio) para no ocupar toda la
// pantalla; al tocarlas se abren con todo.
// ---------------------------------------------------------------------------

/// La flecha del encabezado: abajo = cerrada, arriba = abierta.
class FlechaPlegable extends StatelessWidget {
  const FlechaPlegable({super.key, required this.abierta, required this.onTap});

  final bool abierta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      tooltip: abierta ? 'Ocultar detalles' : 'Ver detalles',
      icon: AnimatedRotation(
        turns: abierta ? 0.5 : 0,
        duration: const Duration(milliseconds: 200),
        child: const Icon(Icons.expand_more, color: MoblarColors.textSecondary),
      ),
    );
  }
}

/// Lo que se ve con la tarjeta cerrada. Tocarla la abre.
class ResumenPlegado extends StatelessWidget {
  const ResumenPlegado({
    super.key,
    required this.titulo,
    required this.estado,
    required this.onTap,
    this.precio,
    this.imagen,
    this.estadoColor = MoblarColors.textSecondary,
  });

  final String titulo;
  final String estado;
  final Color estadoColor;
  final num? precio;
  final String? imagen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = imagen;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: MoblarColors.surfaceSubtle,
                child: img == null
                    ? const Icon(Icons.chair_outlined, color: MoblarColors.textMuted)
                    : Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported_outlined, color: MoblarColors.textMuted),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MoblarColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estado,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: estadoColor),
                  ),
                ],
              ),
            ),
            if (precio != null) ...[
              const SizedBox(width: 8),
              Text(
                dinero(precio!),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MoblarColors.primaryDark),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
