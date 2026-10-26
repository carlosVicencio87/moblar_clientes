import 'package:flutter/material.dart';

import '../../data/api_client.dart' show ApiException, SesionTerminada;
import '../../data/models.dart';
import '../../state/app_scope.dart';
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
    this.formal,
  });

  final OfertaVisita oferta;
  final Contacto contacto;
  final String? nombre;

  /// Paso 2a: la cotización formal (proyecto completado en el ERP) de esta
  /// cita, si ya existe. null = el arquitecto todavía no termina el levantamiento.
  final Cotizacion? formal;

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

  /// A3: la opción que se está viendo (índice en `oferta.opciones`).
  int _sel = 0;

  /// Las opciones de la oferta; con una sola, la oferta misma.
  List<OfertaVisita> get _ofertas =>
      widget.oferta.opciones.isEmpty ? [widget.oferta] : widget.oferta.opciones;

  /// La opción que se ve ahora.
  OfertaVisita get _actual => _ofertas[_sel.clamp(0, _ofertas.length - 1)];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ResultadoAnticipo>>(
      valueListenable: DemoAnticipos.resultados,
      builder: (context, anticipos, _) => _tarjeta(context, anticipos),
    );
  }

  void _cambiarFactura(bool v) {
    setState(() {
      _factura = v;
      // Si el plazo elegido no existe en la otra variante, vuelve a contado.
      final plazos = plazosDe(_actual.variante(factura: v)).map((x) => x.meses);
      if (_plazo != plazoContado && !plazos.contains(_plazo)) _plazo = plazoContado;
    });
  }

  void _elegirOpcion(int i) {
    if (i == _sel) return;
    setState(() {
      _sel = i;
      _plazo = plazoContado; // cada opción tiene sus propios plazos y precios
    });
  }

  Widget _tarjeta(BuildContext context, Map<String, ResultadoAnticipo> anticipos) {
    final o = _actual;
    final adquirida = anticipos[o.clave];
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
          if (_ofertas.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SelectorOpciones(
                opciones: _ofertas,
                seleccion: _sel.clamp(0, _ofertas.length - 1),
                adquiridas: {for (final x in _ofertas) if (anticipos.containsKey(x.clave)) x.opcion},
                onElegir: _elegirOpcion,
              ),
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
                if (o.notas != null)
                  Padding(
                    key: const Key('notasOpcion'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(o.notas!, style: const TextStyle(color: MoblarColors.textSecondary)),
                  ),
                // Información del mueble, antes de los precios.
                _InfoMueble(oferta: o, vencida: vencida, mostrarVigencia: adquirida == null),
                if (o.notasGenerales != null)
                  Dato(
                    key: const Key('notasGeneralesOferta'),
                    icono: Icons.notes_outlined,
                    texto: o.notasGenerales!,
                  ),
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
                    key: Key('adquirirOferta-${o.clave}'),
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
                    label: Text(o.opcion >= 1 ? 'Adquirir la opción ${o.opcion}' : 'Adquirir esta cotización'),
                  ),
                ],
                if (!vencida || widget.formal != null) ...[
                  const SizedBox(height: 12),
                  TarjetaCotizacionFormal(formal: widget.formal),
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

/// "Tu cotización formal" (Carlos, 2026-10-26): mientras el arquitecto no
/// termina el levantamiento dice que ahí estará; cuando el ERP ya la tiene
/// (proyecto completado con su PDF), avisa que está lista y deja descargarla.
/// El PDF se pide al tocar: la URL es firmada y vence en minutos.
class TarjetaCotizacionFormal extends StatefulWidget {
  const TarjetaCotizacionFormal({super.key, this.formal});

  final Cotizacion? formal;

  @override
  State<TarjetaCotizacionFormal> createState() => _TarjetaCotizacionFormalState();
}

class _TarjetaCotizacionFormalState extends State<TarjetaCotizacionFormal> {
  bool _abriendo = false;

  Future<void> _verPdf(String id) async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await AppScope.read(context).urlPdf(id);
      if (mounted) await abrirEnlace(context, url, trasEspera: true);
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.formal;
    final lista = f?.tienePdf == true;
    const verde = Color(0xFF065F46);
    return Container(
      key: Key(lista ? 'cotizacionFormalLista' : 'cotizacionFormalPendiente'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lista ? const Color(0xFFD1FAE5) : MoblarColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: lista ? null : Border.all(color: MoblarColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                lista ? Icons.verified_outlined : Icons.hourglass_top_outlined,
                color: lista ? verde : MoblarColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lista
                      ? 'Tu cotización formal ya está lista${f?.codigo == null ? '' : ' (folio ${f?.codigo})'}'
                      : 'Tu cotización formal',
                  style: TextStyle(fontWeight: FontWeight.w700, color: lista ? verde : MoblarColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lista
                ? 'Revisa las medidas y lo que lleva tu mueble. Puedes descargarla cuando quieras.'
                : 'Aquí estará tu cotización formal en cuanto tu arquitecto termine el levantamiento. '
                    'La podrás descargar desde aquí.',
            style: TextStyle(fontSize: 13, color: lista ? verde : MoblarColors.textSecondary),
          ),
          if (lista) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: Key('verCotizacionFormal-${f!.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _abriendo ? null : () => _verPdf(f.id),
              icon: _abriendo
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Ver y descargar'),
            ),
            const SizedBox(height: 8),
            if (f.firmada)
              Row(
                key: const Key('cotizacionFirmada'),
                children: [
                  const Icon(Icons.draw_outlined, size: 18, color: verde),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      parseFecha(f.firmadaEl) == null
                          ? 'Ya firmaste tu cotización.'
                          : 'Firmaste tu cotización el ${fechaLarga(parseFecha(f.firmadaEl)!)}.',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: verde),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                key: Key('firmarCotizacion-${f.id}'),
                onPressed: () async {
                  final firmada = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(builder: (_) => FirmarCotizacionPage(cotizacion: f)),
                  );
                  if (firmada == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Listo! Tu cotización quedó firmada.')),
                    );
                  }
                },
                icon: const Icon(Icons.draw_outlined),
                label: const Text('Leer y firmar'),
              ),
          ],
        ],
      ),
    );
  }
}

/// 2b (Carlos, 2026-10-26): el cliente lee los requerimientos (su cotización
/// formal en PDF) y firma: confirma que está de acuerdo y escribe su nombre.
/// La firma queda en el ERP con la versión del PDF. Con la firma y el 50 %
/// pagado empieza la fabricación.
class FirmarCotizacionPage extends StatefulWidget {
  const FirmarCotizacionPage({super.key, required this.cotizacion, this.firmar, this.verPdf});

  final Cotizacion cotizacion;

  /// Inyectables para pruebas.
  final Future<void> Function(String nombre)? firmar;
  final Future<void> Function()? verPdf;

  @override
  State<FirmarCotizacionPage> createState() => _FirmarCotizacionPageState();
}

class _FirmarCotizacionPageState extends State<FirmarCotizacionPage> {
  final _nombre = TextEditingController();
  bool _acepto = false;
  bool _firmando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _listo => _acepto && _nombre.text.replaceAll(RegExp(r'\s+'), ' ').trim().length >= 3;

  Future<void> _verPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.verPdf != null) {
        await widget.verPdf!();
        return;
      }
      final url = await AppScope.read(context).urlPdf(widget.cotizacion.id);
      if (mounted) await abrirEnlace(context, url, trasEspera: true);
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _firmar() async {
    if (!_listo || _firmando) return;
    setState(() => _firmando = true);
    final messenger = ScaffoldMessenger.of(context);
    final nombre = _nombre.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    try {
      if (widget.firmar != null) {
        await widget.firmar!(nombre);
      } else {
        await AppScope.read(context).firmarCotizacion(widget.cotizacion.id, nombre);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _firmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cotizacion;
    return Scaffold(
      appBar: AppBar(title: const Text('Firma tu cotización')),
      body: ListView(
        key: const Key('paginaFirmarCotizacion'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            c.codigo == null ? 'Tu cotización formal' : 'Tu cotización formal · folio ${c.codigo}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Antes de firmar, revisa tu cotización: las medidas que tomó tu arquitecto, lo que lleva tu '
            'mueble y sus condiciones. Con tu firma y el 50 % pagado empezamos a fabricarlo.',
            style: TextStyle(color: MoblarColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('verPdfFirma'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: _verPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Ver mi cotización (PDF)'),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('aceptoCotizacion'),
            value: _acepto,
            onChanged: (v) => setState(() => _acepto = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Leí mi cotización formal y estoy de acuerdo con las medidas, lo que lleva mi mueble y sus condiciones.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('nombreFirma'),
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Tu nombre completo',
              helperText: 'Es tu firma.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('confirmarFirma'),
            onPressed: _listo && !_firmando ? _firmar : null,
            icon: _firmando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.draw_outlined),
            label: const Text('Firmar mi cotización'),
          ),
        ],
      ),
    );
  }
}

/// A3: "Opción 1 · Opción 2 · Opción 3", cada una con su precio de contado.
/// Las que ya adquirió llevan una palomita: puede adquirir una, varias o todas.
class _SelectorOpciones extends StatelessWidget {
  const _SelectorOpciones({
    required this.opciones,
    required this.seleccion,
    required this.adquiridas,
    required this.onElegir,
  });

  final List<OfertaVisita> opciones;
  final int seleccion;
  final Set<int> adquiridas;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu arquitecto te dejó ${opciones.length} opciones',
          style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < opciones.length; i++)
              ChoiceChip(
                key: Key('opcionOferta-${opciones[i].opcion}'),
                selected: i == seleccion,
                showCheckmark: false,
                onSelected: (_) => onElegir(i),
                avatar: adquiridas.contains(opciones[i].opcion)
                    ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF065F46))
                    : null,
                label: Text('Opción ${opciones[i].opcion} · ${dinero(opciones[i].precioContado)}'),
              ),
          ],
        ),
      ],
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
