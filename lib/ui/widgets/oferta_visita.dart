import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';
import 'contacto.dart';
import 'detalle_mueble.dart' show ampliarImagen;
import 'pago_visita.dart' show AvisoDemo;

// ---------------------------------------------------------------------------
// Oferta de la visita — ESQUELETO DE DEMOSTRACIÓN (paso C, 2026-10-02).
//
// Es la versión temprana de la "cotización comercial" (misma etiqueta,
// imagen, vigencia, arquitecto e "incluye" que la tarjeta de Cotizaciones),
// ligada a la CITA: la deja el arquitecto al terminar la visita. Agrega el
// precio en el mismo orden que la pantalla del arquitecto ("Así lo verá el
// cliente"): precio de lista, 18 MSI, descuento por contado y precio de
// contado. Los números vienen del servidor; aquí no se recalcula nada.
// ---------------------------------------------------------------------------

class TarjetaOfertaVisita extends StatelessWidget {
  const TarjetaOfertaVisita({
    super.key,
    required this.cita,
    required this.oferta,
    required this.contacto,
    this.nombre,
  });

  final Cita cita;
  final OfertaVisita oferta;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final hasta = parseFecha(o.vigenteHasta);
    final vencida = !o.vigente;
    final imagen = o.imagenDiseno;
    return Card(
      key: const Key('tarjetaOfertaVisita'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (o.demo)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AvisoDemo(),
            ),
          const SizedBox(height: 12),
          // La foto del diseño es lo primero que ve el cliente.
          if (imagen != null)
            InkWell(
              key: const Key('imagenOfertaVisita'),
              onTap: () => ampliarImagen(context, imagen, titulo: 'Tu diseño'),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: MoblarColors.surfaceSubtle,
                  child: Image.network(
                    imagen,
                    fit: BoxFit.contain,
                    semanticLabel: 'Diseño de tu mueble',
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: MoblarColors.textMuted),
                    ),
                  ),
                ),
              ),
            )
          else
            const _FotoPendiente(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'COTIZACIÓN COMERCIAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: MoblarColors.primary,
                        ),
                      ),
                    ),
                    if (vencida)
                      const EstadoChip(
                        texto: 'Vencida',
                        color: Color(0xFF991B1B),
                        fondo: Color(0xFFFEE2E2),
                      ),
                  ],
                ),
                const Text(
                  'La propuesta de tu visita',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MoblarColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _Precios(oferta: o),
                if (hasta != null)
                  Dato(
                    icono: vencida ? Icons.event_busy_outlined : Icons.event_available_outlined,
                    texto: vencida
                        ? 'Venció el ${fechaLarga(hasta)}. Pídenos una actualización.'
                        : 'Válida hasta el ${fechaLarga(hasta)}',
                  ),
                if (o.arquitecto != null)
                  Dato(icono: Icons.person_outline, texto: 'Tu arquitecto: ${o.arquitecto}'),
                if (o.incluye.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'INCLUYE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: MoblarColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final t in o.incluye) _ChipIncluye(texto: t)],
                  ),
                ],
                const SizedBox(height: 8),
                BotonPreguntar(
                  key: const Key('preguntarOfertaVisita'),
                  texto: vencida ? 'Pedir cotización actualizada' : 'Preguntar por esta cotización',
                  contacto: contacto,
                  mensaje: mensajeOfertaVisita(cita, nombre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Precio de lista grande, la mensualidad, el descuento y el precio de
/// contado resaltado: el beneficio de pagar en efectivo o transferencia.
class _Precios extends StatelessWidget {
  const _Precios({required this.oferta});

  final OfertaVisita oferta;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Precio de lista', style: TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
        Text(
          dinero(o.precioLista),
          key: const Key('precioListaOferta'),
          style: const TextStyle(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: MoblarColors.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'o ${o.meses} meses sin intereses de ${dinero(o.mensualidad)}',
          key: const Key('mensualidadOferta'),
          style: const TextStyle(color: MoblarColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('contadoOferta'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Descuento por pago de contado',
                      style: TextStyle(fontSize: 13, color: Color(0xFF065F46)),
                    ),
                  ),
                  Text(
                    '−${dinero(o.descuento)} (${o.descuentoPct.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Precio de contado',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                    ),
                  ),
                  Text(
                    dinero(o.precioContado),
                    key: const Key('precioContadoOferta'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pagando en efectivo o por transferencia.',
                style: TextStyle(fontSize: 12, color: Color(0xFF065F46)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lugar de la foto mientras no hay una real (en la demo, siempre).
class _FotoPendiente extends StatelessWidget {
  const _FotoPendiente();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: const Key('fotoPendienteOferta'),
      aspectRatio: 4 / 3,
      child: Container(
        color: MoblarColors.surfaceSubtle,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chair_outlined, size: 48, color: MoblarColors.textMuted),
            SizedBox(height: 8),
            Text(
              'Aquí verás la foto del diseño que te dejó tu arquitecto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MoblarColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipIncluye extends StatelessWidget {
  const _ChipIncluye({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MoblarColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: MoblarColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(texto, style: const TextStyle(fontSize: 12, color: MoblarColors.primaryDark)),
          ),
        ],
      ),
    );
  }
}
