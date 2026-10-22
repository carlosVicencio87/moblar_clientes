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
// Oferta de la visita — ESQUELETO DE DEMOSTRACIÓN (paso C, 2026-10-02;
// rediseño C5, 2026-10-22: factura al momento, el precio más bajo en verde y
// "Otras opciones de pago").
//
// Es la versión temprana de la "cotización comercial" (misma etiqueta,
// imagen, vigencia, arquitecto e "incluye" que la tarjeta de Cotizaciones):
// la deja el arquitecto al terminar la visita y vive en la pestaña
// Cotizaciones (decisión de Carlos, 2026-10-02). Agrega el
// precio en el mismo orden que la pantalla del arquitecto ("Así lo verá el
// cliente"): precio de lista, 24 MSI, descuento por contado y precio de
// contado. Los números vienen del servidor; aquí no se recalcula nada.
// ---------------------------------------------------------------------------

class TarjetaOfertaVisita extends StatefulWidget {
  const TarjetaOfertaVisita({
    super.key,
    required this.oferta,
    required this.contacto,
    this.nombre,
    this.montoVisita = 0,
  });

  final OfertaVisita oferta;
  final Contacto contacto;
  final String? nombre;

  /// Costo de la visita de la que salió la oferta (no se cobra si la adquiere).
  final num montoVisita;

  @override
  State<TarjetaOfertaVisita> createState() => _TarjetaOfertaVisitaState();
}

/// C5 (Carlos, 2026-10-22): "Requiero factura" cambia los precios al momento
/// (apagado = "descuento por no facturar") y "Otras opciones de pago" deja
/// elegir la forma de pago. Las dos elecciones pasan a "Inicia tu proyecto".
class _TarjetaOfertaVisitaState extends State<TarjetaOfertaVisita> {
  bool _factura = true;

  /// Forma de pago elegida: ver [AdquirirOfertaPage.plazo].
  int _plazo = plazoContado;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ResultadoAnticipo>>(
      valueListenable: DemoAnticipos.resultados,
      builder: (context, anticipos, _) => _tarjeta(context, anticipos[widget.oferta.citaId]),
    );
  }

  void _cambiarFactura(bool v) {
    setState(() {
      _factura = v;
      // Si el plazo elegido no existe en la otra variante, vuelve a contado.
      final plazos = plazosDe(widget.oferta.variante(factura: v)).map((x) => x.meses);
      if (_plazo != plazoContado && !plazos.contains(_plazo)) _plazo = plazoContado;
    });
  }

  Widget _tarjeta(BuildContext context, ResultadoAnticipo? adquirida) {
    final o = widget.oferta;
    // Ya adquirida: los precios de lo que compró; si no, lo que elige ahora.
    final factura = adquirida?.factura ?? (_factura || !o.eligeFactura);
    final v = o.variante(factura: factura);
    final vencida = !o.vigente && adquirida == null;
    final imagen = o.imagenDiseno;
    final visita = parseFecha(o.fechaVisita);
    final elige = adquirida == null && !vencida;
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
                // Información del mueble, antes de los precios.
                _InfoMueble(oferta: o, vencida: vencida, mostrarVigencia: adquirida == null),
                if (elige && o.eligeFactura) ...[
                  const SizedBox(height: 8),
                  _InterruptorFactura(
                    factura: _factura,
                    ahorro: menosAbono(o.precioContado, o.variante(factura: false).precioContado),
                    ivaPct: o.ivaPct,
                    onChanged: _cambiarFactura,
                  ),
                ],
                const SizedBox(height: 12),
                _Precios(
                  oferta: v,
                  // Sin factura: el precio con factura y el descuento por no facturar.
                  conFactura: o.eligeFactura && !factura ? o : null,
                ),
                if (elige) ...[
                  const SizedBox(height: 4),
                  _OtrasOpciones(
                    oferta: v,
                    plazo: _plazo,
                    onElegir: (p) => setState(() => _plazo = p),
                  ),
                ],
                if (adquirida != null) ...[
                  const SizedBox(height: 12),
                  ResumenCompraOferta(oferta: v, resultado: adquirida),
                ] else if (o.adquirible) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: Key('adquirirOferta-${o.citaId}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdquirirOfertaPage(
                          oferta: o,
                          montoVisita: widget.montoVisita,
                          factura: factura,
                          plazo: _plazo,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Adquirir esta cotización'),
                  ),
                ],
                const SizedBox(height: 8),
                BotonPreguntar(
                  key: Key('preguntarOfertaVisita-${o.citaId}'),
                  texto: vencida ? 'Pedir cotización actualizada' : 'Preguntar por esta cotización',
                  contacto: widget.contacto,
                  mensaje: mensajeOfertaVisita(o, widget.nombre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vigencia, arquitecto y lo que incluye el precio.
class _InfoMueble extends StatelessWidget {
  const _InfoMueble({required this.oferta, required this.vencida, required this.mostrarVigencia});

  final OfertaVisita oferta;
  final bool vencida;
  final bool mostrarVigencia;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final hasta = parseFecha(o.vigenteHasta);
    return Column(
      key: const Key('infoMuebleOferta'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasta != null && mostrarVigencia)
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
      ],
    );
  }
}

/// "Requiero factura": encendido por omisión. Apagado, todos los precios
/// pasan a la variante sin IVA que manda el servidor (SOLO DEMO: pendiente
/// de validar con el contador).
class _InterruptorFactura extends StatelessWidget {
  const _InterruptorFactura({
    required this.factura,
    required this.ahorro,
    required this.ivaPct,
    required this.onChanged,
  });

  final bool factura;
  final num ahorro;
  final num ivaPct;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Material (no Container con color): el ListTile pinta su toque en el
    // Material más cercano y un fondo intermedio lo taparía.
    return Material(
      color: MoblarColors.surfaceSubtle,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MoblarColors.border),
      ),
      child: SwitchListTile(
        key: const Key('facturaOferta'),
        value: factura,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: const Text('Requiero factura', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          factura
              ? 'Precios con IVA (${ivaPct.round()}%).'
              : 'Sin factura: descuento de ${dinero(ahorro)}.',
          key: const Key('detalleFacturaOferta'),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// Precio de lista y su mensualidad; abajo, en verde, el precio más bajo:
/// de contado (efectivo o transferencia), con su desglose.
class _Precios extends StatelessWidget {
  const _Precios({required this.oferta, this.conFactura});

  final OfertaVisita oferta;

  /// La oferta con factura, cuando el cliente la quitó: para mostrar el
  /// "descuento por no facturar" (decisión de Carlos, 2026-10-22).
  final OfertaVisita? conFactura;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final cf = conFactura;
    const verde = Color(0xFF065F46);
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
            fontSize: 22,
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
              _Renglon(
                clave: const Key('descuentoContadoOferta'),
                etiqueta: 'Descuento por pago de contado',
                valor: '−${dinero(o.descuento)} (${o.descuentoPct.toStringAsFixed(1)}%)',
                fuerte: true,
              ),
              if (o.iva > 0) ...[
                const SizedBox(height: 6),
                _Renglon(
                  clave: const Key('subtotalOferta'),
                  etiqueta: 'Precio de tu mueble',
                  valor: dinero(o.subtotal),
                ),
                _Renglon(
                  clave: const Key('ivaOferta'),
                  etiqueta: 'IVA (${o.ivaPct.round()}%)',
                  valor: dinero(o.iva),
                ),
              ] else if (cf != null) ...[
                const SizedBox(height: 6),
                _Renglon(
                  clave: const Key('precioConFacturaOferta'),
                  etiqueta: 'Precio con factura',
                  valor: dinero(cf.precioContado),
                ),
                _Renglon(
                  clave: const Key('descuentoFacturaOferta'),
                  etiqueta: 'Descuento por no facturar',
                  valor: '−${dinero(menosAbono(cf.precioContado, o.precioContado))}',
                ),
              ],
              const SizedBox(height: 6),
              // Etiqueta y monto en renglones distintos: a 28 el monto no cabe
              // junto a la etiqueta en pantallas angostas; si aun así no
              // cabe, se reduce.
              const Text(
                'Precio de contado',
                style: TextStyle(fontWeight: FontWeight.w700, color: verde),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    dinero(o.precioContado),
                    key: const Key('precioContadoOferta'),
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: verde,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'El precio más bajo: pagando en efectivo o por transferencia.',
                style: TextStyle(fontSize: 12, color: verde),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Renglón del desglose dentro del recuadro verde de contado.
class _Renglon extends StatelessWidget {
  const _Renglon({required this.clave, required this.etiqueta, required this.valor, this.fuerte = false});

  final Key clave;
  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 13,
      fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
      color: const Color(0xFF065F46),
    );
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

/// "Otras opciones de pago": contado y, con tarjeta, un solo pago y cada plazo
/// de MSI con su total (Clip cobra menos comisión entre menos meses). Se puede
/// elegir una; la elección pasa a "Inicia tu proyecto".
class _OtrasOpciones extends StatelessWidget {
  const _OtrasOpciones({required this.oferta, required this.plazo, required this.onElegir});

  final OfertaVisita oferta;
  final int plazo;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final tarjeta = plazosDe(o);
    final elegida = tarjeta.where((x) => x.meses == plazo).firstOrNull;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('otrasOpcionesPago'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: const Icon(Icons.payments_outlined, color: MoblarColors.primary),
        title: const Text(
          'Otras opciones de pago',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Elegiste: ${elegida == null ? 'de contado' : nombrePlazo(elegida.meses).toLowerCase()}',
          key: const Key('formaElegidaOferta'),
          style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
        ),
        children: [
          _FilaForma(
            clave: const Key('formaPago-0'),
            elegida: elegida == null,
            titulo: 'De contado',
            detalle: 'Efectivo o transferencia · el más bajo',
            monto: dinero(o.precioContado),
            verde: true,
            onTap: () => onElegir(plazoContado),
          ),
          for (final x in tarjeta)
            _FilaForma(
              clave: Key('formaPago-${x.meses}'),
              elegida: identical(x, elegida),
              titulo: nombrePlazo(x.meses),
              detalle: x.unPago ? 'Con tarjeta' : 'Total ${dinero(x.total)}',
              monto: x.unPago ? dinero(x.total) : '${x.meses} × ${dinero(x.mensualidad)}',
              onTap: () => onElegir(x.meses),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Con tarjeta, entre menos meses, menor precio.',
              style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaForma extends StatelessWidget {
  const _FilaForma({
    required this.clave,
    required this.elegida,
    required this.titulo,
    required this.detalle,
    required this.monto,
    required this.onTap,
    this.verde = false,
  });

  final Key clave;
  final bool elegida;
  final String titulo;
  final String detalle;
  final String monto;
  final VoidCallback onTap;
  final bool verde;

  @override
  Widget build(BuildContext context) {
    final color = verde ? const Color(0xFF065F46) : MoblarColors.textPrimary;
    return InkWell(
      key: clave,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: elegida ? MoblarColors.primary : MoblarColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
                  Text(detalle, style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
                ],
              ),
            ),
            Text(monto, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
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
