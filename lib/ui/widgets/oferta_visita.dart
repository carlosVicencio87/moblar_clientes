import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';
import 'contacto.dart';
import 'detalle_mueble.dart' show ampliarImagen;
import 'adquirir_oferta.dart';
import 'pago_visita.dart' show AvisoDemo;

// ---------------------------------------------------------------------------
// Oferta de la visita — ESQUELETO DE DEMOSTRACIÓN (paso C, 2026-10-02).
//
// Es la versión temprana de la "cotización comercial" (misma etiqueta,
// imagen, vigencia, arquitecto e "incluye" que la tarjeta de Cotizaciones):
// la deja el arquitecto al terminar la visita y vive en la pestaña
// Cotizaciones (decisión de Carlos, 2026-10-02). Agrega el
// precio en el mismo orden que la pantalla del arquitecto ("Así lo verá el
// cliente"): precio de lista, 18 MSI, descuento por contado y precio de
// contado. Los números vienen del servidor; aquí no se recalcula nada.
// ---------------------------------------------------------------------------

class TarjetaOfertaVisita extends StatelessWidget {
  const TarjetaOfertaVisita({
    super.key,
    required this.oferta,
    required this.contacto,
    this.nombre,
  });

  final OfertaVisita oferta;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ResultadoAnticipo>>(
      valueListenable: DemoAnticipos.resultados,
      builder: (context, anticipos, _) => _tarjeta(context, anticipos[oferta.citaId]),
    );
  }

  Widget _tarjeta(BuildContext context, ResultadoAnticipo? adquirida) {
    final o = oferta;
    final hasta = parseFecha(o.vigenteHasta);
    final vencida = !o.vigente && adquirida == null;
    final imagen = o.imagenDiseno;
    final visita = parseFecha(o.fechaVisita);
    return Card(
      key: Key('ofertaVisita-${o.citaId}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: MarcaEncabezado(
              marca: o.marca,
              trailing: adquirida != null
                  ? const EstadoChip(
                      texto: 'Adquirida',
                      color: Color(0xFF065F46),
                      fondo: Color(0xFFD1FAE5),
                    )
                  : vencida
                      ? const EstadoChip(
                          texto: 'Vencida',
                          color: Color(0xFF991B1B),
                          fondo: Color(0xFFFEE2E2),
                        )
                      : null,
            ),
          ),
          if (o.demo)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                const Text(
                  'COTIZACIÓN COMERCIAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: MoblarColors.primary,
                  ),
                ),
                Text(
                  o.muebles.isEmpty ? 'Mueble a la medida' : o.muebles.join(', '),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MoblarColors.textPrimary,
                  ),
                ),
                Text(
                  visita == null
                      ? 'Propuesta de tu visita'
                      : 'Propuesta de tu visita del ${fechaLarga(visita)}',
                  style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                ),
                const SizedBox(height: 12),
                _Precios(oferta: o),
                if (adquirida != null) ...[
                  const SizedBox(height: 12),
                  ResumenCompraOferta(oferta: o.variante(factura: adquirida.factura), resultado: adquirida),
                ] else if (o.adquirible) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: Key('adquirirOferta-${o.citaId}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => AdquirirOfertaPage(oferta: o)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Adquirir esta cotización'),
                  ),
                ],
                if (hasta != null && adquirida == null)
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
                  key: Key('preguntarOfertaVisita-${o.citaId}'),
                  texto: vencida ? 'Pedir cotización actualizada' : 'Preguntar por esta cotización',
                  contacto: contacto,
                  mensaje: mensajeOfertaVisita(o, nombre),
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
        Text(
          o.iva > 0 ? 'Precio de lista (IVA incluido)' : 'Precio de lista',
          style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
        ),
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
        if (o.opcionesTarjeta.isNotEmpty) ...[
          const SizedBox(height: 10),
          _OpcionesTarjeta(opciones: o.opcionesTarjeta),
        ],
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
              if (o.iva > 0) ...[
                const SizedBox(height: 6),
                _RenglonIva(
                  clave: const Key('subtotalOferta'),
                  etiqueta: 'Precio de tu mueble',
                  valor: dinero(o.subtotal),
                ),
                _RenglonIva(
                  clave: const Key('ivaOferta'),
                  etiqueta: 'IVA (${o.ivaPct.round()}%)',
                  valor: dinero(o.iva),
                ),
              ],
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
              if (o.eligeFactura)
                Text(
                  'Precios con factura. Si no la necesitas, al adquirir puedes quitar el IVA.',
                  key: const Key('avisoFacturaOferta'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renglón del desglose de IVA dentro del recuadro de contado.
class _RenglonIva extends StatelessWidget {
  const _RenglonIva({required this.clave, required this.etiqueta, required this.valor});

  final Key clave;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 13, color: Color(0xFF065F46));
    return Padding(
      key: clave,
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

/// Con tarjeta: un solo pago y cada plazo con su total. Clip cobra menos
/// comisión entre menos meses, así que cada plazo tiene su propio precio.
class _OpcionesTarjeta extends StatelessWidget {
  const _OpcionesTarjeta({required this.opciones});

  final List<OpcionTarjeta> opciones;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('opcionesTarjeta'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: const Icon(Icons.credit_card, color: MoblarColors.primary),
        title: const Text(
          'Opciones con tarjeta',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Entre menos meses, menor precio.',
          style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
        ),
        children: [
          for (final x in opciones)
            Padding(
              key: Key('opcionTarjeta-${x.meses}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x.unPago ? 'Un solo pago' : '${x.meses} meses sin intereses',
                      style: const TextStyle(color: MoblarColors.textPrimary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        x.unPago ? dinero(x.total) : '${x.meses} × ${dinero(x.mensualidad)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (!x.unPago)
                        Text(
                          'Total ${dinero(x.total)}',
                          style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
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
