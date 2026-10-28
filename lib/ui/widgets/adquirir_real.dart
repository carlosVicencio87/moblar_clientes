import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api_client.dart' show ApiException, SesionTerminada;
import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';

// ---------------------------------------------------------------------------
// Compra REAL de opciones de la oferta (Carlos, 2026-10-26/27): el cliente
// marca una o varias opciones y paga una vez. La compra queda en el ERP
// (POST /api/cliente/citas/:id/adquirir); con tarjeta, el link de Clip es
// real y Clip confirma el pago. Levantamiento y compra son independientes:
// la producción arranca con la firma de la cotización formal y el 50 %.
// Todos los montos los calcula el servidor.
// ---------------------------------------------------------------------------

const _plazosMsi = [3, 6, 9, 12, 18, 24];

/// El comprobante de una transferencia (foto o PDF), ya leído.
class ArchivoComprobante {
  const ArchivoComprobante({required this.nombre, required this.bytes, required this.extension});

  final String nombre;
  final Uint8List bytes;

  /// jpg | png | webp | heic | pdf
  final String extension;
}

const extensionesComprobante = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'];
const maxComprobanteBytes = 10 * 1024 * 1024;

/// Revisa tipo y tamaño. null = válido; si no, el mensaje para el cliente.
String? problemaComprobante(String nombre, int bytes) {
  final punto = nombre.lastIndexOf('.');
  final ext = punto < 0 ? '' : nombre.substring(punto + 1).toLowerCase();
  if (!extensionesComprobante.contains(ext)) return 'Sube una captura de pantalla (JPG o PNG) o un PDF.';
  if (bytes <= 0) return 'El archivo está vacío.';
  if (bytes > maxComprobanteBytes) return 'El archivo pesa más de 10 MB. Sube una captura de pantalla.';
  return null;
}

/// Primero pregunta qué va a subir (Carlos, 2026-10-28): una captura de
/// pantalla (se abre la galería del teléfono, donde están las capturas) o el
/// PDF del banco (se abre el explorador de archivos). null si el cliente
/// cancela; si el archivo no sirve, avisa y regresa null.
Future<ArchivoComprobante?> elegirComprobante(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final pdf = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('comprobanteCaptura'),
            leading: const Icon(Icons.image_outlined),
            title: const Text('Captura de pantalla o foto'),
            subtitle: const Text('De tu galería'),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          ListTile(
            key: const Key('comprobantePdf'),
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF del banco'),
            subtitle: const Text('De tus archivos'),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (pdf == null) return null;
  final r = pdf
      ? await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], withData: true)
      : await FilePicker.pickFiles(type: FileType.image, withData: true);
  final f = r?.files.firstOrNull;
  if (f == null) return null;
  final bytes = f.bytes;
  final problema = bytes == null ? 'No pudimos leer el archivo.' : problemaComprobante(f.name, bytes.length);
  if (problema != null) {
    messenger.showSnackBar(SnackBar(content: Text(problema)));
    return null;
  }
  final ext = f.name.substring(f.name.lastIndexOf('.') + 1).toLowerCase();
  return ArchivoComprobante(nombre: f.name, bytes: bytes!, extension: ext == 'jpeg' ? 'jpg' : ext);
}

String _nuevoRequestId() {
  final r = Random.secure();
  const letras = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'app-${List.generate(20, (_) => letras[r.nextInt(letras.length)]).join()}';
}

class AdquirirOpcionesPage extends StatefulWidget {
  const AdquirirOpcionesPage({
    super.key,
    required this.oferta,
    required this.inicial,
    this.iniciales,
    this.factura = true,
    this.cotizar,
    this.adquirir,
    this.abrir,
    this.elegirArchivo,
    this.subirComprobante,
    this.titulo = 'Adquirir',
    this.encabezado = const [],
    this.pie = const [],
  });

  /// La oferta completa (con sus opciones y compras).
  final OfertaVisita oferta;

  /// La opción que se marca al abrir (1..3).
  final int inicial;

  /// Varias marcadas al abrir (retomar un pago que no se terminó).
  final Set<int>? iniciales;
  final bool factura;

  /// Inyectables para pruebas.
  final Future<CotizacionCompra> Function(PedidoCompra p)? cotizar;
  final Future<ResultadoCompra> Function(PedidoCompra p)? adquirir;
  final Future<void> Function(Uri url)? abrir;
  final Future<ArchivoComprobante?> Function()? elegirArchivo;
  final Future<void> Function(String compraId, ArchivoComprobante a)? subirComprobante;

  /// Para usar esta misma pantalla al terminar la visita (Carlos, 2026-10-28):
  /// título propio, lo que va antes de las opciones y lo que va al final.
  final String titulo;
  final List<Widget> encabezado;
  final List<Widget> pie;

  @override
  State<AdquirirOpcionesPage> createState() => _AdquirirOpcionesPageState();
}

class _AdquirirOpcionesPageState extends State<AdquirirOpcionesPage> {
  late final Set<int> _marcadas = {...?widget.iniciales, if (widget.iniciales == null) widget.inicial};
  late bool _factura = widget.factura;
  /// Cuánto paga hoy: liquidar (todo) | fabricacion (50 %) | apartado.
  String _modalidad = 'fabricacion';

  /// transferencia | efectivo | tarjeta (una exhibición) | meses (tarjeta a
  /// meses sin intereses: para todo o el 50 %, nunca para apartar).
  String _metodo = 'transferencia';
  int _plazo = 12;
  final _monto = TextEditingController();
  final _pin = TextEditingController();
  ArchivoComprobante? _archivo;
  String _requestId = _nuevoRequestId();

  CotizacionCompra? _cot;
  String? _error;
  bool _cotizando = false;
  bool _enviando = false;
  int _vuelta = 0;
  Timer? _espera;

  /// Con tarjeta: el link ya está abierto y se espera la confirmación de Clip.
  LinkPagoTarjeta? _link;
  Timer? _revision;

  List<OfertaVisita> get _ofertas => widget.oferta.opciones.isEmpty ? [widget.oferta] : widget.oferta.opciones;
  int _num(OfertaVisita o) => o.opcion < 1 ? 1 : o.opcion;

  PedidoCompra get _pedido => PedidoCompra(
        opciones: (_marcadas.toList()..sort()),
        modalidad: _modalidad,
        metodo: _metodoActual,
        factura: _factura,
        plazo: _aMeses ? _plazo : 0,
        monto: _modalidad == 'apartado' ? num.tryParse(_monto.text.replaceAll(RegExp(r'[^0-9]'), '')) : null,
        requestId: _requestId,
        pin: _metodoActual == 'efectivo' ? _pin.text : null,
      );

  bool get _aMeses => _metodo == 'meses' && _modalidad != 'apartado';
  String get _metodoActual => _metodo == 'meses' ? 'tarjeta' : _metodo;

  /// Transferencia: con su comprobante. Efectivo: con el PIN del arquitecto.
  bool get _completo => switch (_metodoActual) {
        'transferencia' => _archivo != null,
        'efectivo' => RegExp(r'^\d{4}$').hasMatch(_pin.text),
        _ => true,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recotizar());
  }

  @override
  void dispose() {
    _espera?.cancel();
    _revision?.cancel();
    _monto.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _cambiar(VoidCallback f) {
    setState(f);
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), _recotizar);
  }

  Future<void> _recotizar() async {
    if (!mounted) return;
    if (_marcadas.isEmpty) {
      setState(() {
        _cot = null;
        _error = 'Elige al menos una opción.';
      });
      return;
    }
    if (_modalidad == 'apartado' && (_pedido.monto ?? 0) <= 0) {
      setState(() {
        _cot = null;
        _error = null;
      });
      return;
    }
    final app = AppScope.maybeRead(context);
    if (widget.cotizar == null && app == null) return;
    final vuelta = ++_vuelta;
    setState(() => _cotizando = true);
    try {
      final c = widget.cotizar != null
          ? await widget.cotizar!(_pedido)
          : await app!.cotizarCompra(widget.oferta.citaId, _pedido);
      if (!mounted || vuelta != _vuelta) return;
      setState(() {
        _cot = c;
        _error = null;
      });
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      if (!mounted || vuelta != _vuelta) return;
      setState(() {
        _cot = null;
        _error = e.mensaje;
      });
    } finally {
      if (mounted && vuelta == _vuelta) setState(() => _cotizando = false);
    }
  }

  Future<void> _adjuntar() async {
    final a = widget.elegirArchivo != null ? await widget.elegirArchivo!() : await elegirComprobante(context);
    if (a != null && mounted) setState(() => _archivo = a);
  }

  Future<void> _confirmar() async {
    if (_cot == null || _enviando || !_completo) return;
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = AppScope.maybeRead(context);
    try {
      final r = widget.adquirir != null
          ? await widget.adquirir!(_pedido)
          : await app!.adquirir(widget.oferta.citaId, _pedido);
      if (!mounted) return;
      final link = r.link;
      if (link == null) {
        var aviso = switch (r.compra.metodo) {
          'tarjeta' => 'Tu compra ya estaba registrada.',
          'efectivo' => '¡Listo! Tu arquitecto confirmó tu pago en efectivo.',
          _ => 'Recibimos tu comprobante. Te avisamos en cuanto validemos tu pago.',
        };
        final archivo = _archivo;
        if (r.compra.metodo == 'transferencia' && archivo != null && !r.compra.comprobante) {
          try {
            if (widget.subirComprobante != null) {
              await widget.subirComprobante!(r.compra.id, archivo);
            } else if (app != null) {
              await app.subirComprobante(r.compra.id, archivo.bytes, archivo.extension);
            }
          } on SesionTerminada {
            return;
          } on ApiException {
            aviso = 'Registramos tu compra, pero tu comprobante no se subió. Súbelo desde tu cotización.';
          }
        }
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(aviso)));
        Navigator.of(context).pop(true);
        return;
      }
      // Un nuevo intento después de este debe generar otro link.
      _requestId = _nuevoRequestId();
      setState(() => _link = link);
      await _abrirLink(link);
      _revision?.cancel();
      _revision = Timer.periodic(const Duration(seconds: 5), (_) => _revisar());
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      // Un PIN equivocado se borra para que el arquitecto lo escriba de nuevo.
      if (_metodoActual == 'efectivo') _pin.clear();
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrirLink(LinkPagoTarjeta l) async {
    final uri = Uri.parse(l.url);
    if (widget.abrir != null) return widget.abrir!(uri);
    await abrirEnlace(context, uri);
  }

  Future<void> _revisar() async {
    final l = _link;
    if (l == null || !mounted) return;
    final app = AppScope.read(context);
    final e = await app.revisarPago(PagoPendiente(
      id: l.id,
      ticket: l.ticket,
      compraId: 'compra',
      neto: l.cotizacion.neto,
      cobro: l.cotizacion.cobro,
    ));
    if (e == null || e.pendiente || !mounted) return;
    _revision?.cancel();
    if (e.pagado) {
      await app.refrescar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Listo! Recibimos tu pago con tarjeta.')),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _link = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El link venció sin pagarse. Puedes generar otro.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: link != null ? _esperandoClip(link) : _formulario(),
    );
  }

  Widget _esperandoClip(LinkPagoTarjeta l) {
    return ListView(
      key: const Key('esperandoClip'),
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.lock_outline, size: 48, color: MoblarColors.primary),
        const SizedBox(height: 12),
        Text(
          'Paga ${dinero(l.cotizacion.cobro)} en la página segura de Clip',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cuando termines, regresa aquí: revisamos tu pago cada pocos segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: MoblarColors.textSecondary),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('abrirClip'),
          onPressed: () => _abrirLink(l),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir la página de pago'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('revisarClip'),
          onPressed: _revisar,
          child: const Text('Ya pagué: revisar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('otraFormaDePago'),
          onPressed: () {
            _revision?.cancel();
            setState(() => _link = null);
          },
          child: const Text('No pagué: elegir otra forma de pago'),
        ),
        const Text(
          'Si eliges otra forma, este link deja de contar. Si ya pagaste en Clip, toca «Ya pagué»: no se te cobra dos veces.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
        ),
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _formulario() {
    final o = widget.oferta;
    final adquiridas = o.opcionesAdquiridas;
    final c = _cot;
    final t = o.transferencia;
    final metodo = _metodoActual;
    return ListView(
      key: const Key('adquirirOpciones'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ...widget.encabezado,
        if (_ofertas.length > 1) ...[
          const _Titulo('¿Qué opciones quieres?'),
          for (final x in _ofertas)
            CheckboxListTile(
              key: Key('marcarOpcion-${_num(x)}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: adquiridas.contains(_num(x)) || _marcadas.contains(_num(x)),
              onChanged: adquiridas.contains(_num(x))
                  ? null
                  : (v) => _cambiar(() => v == true ? _marcadas.add(_num(x)) : _marcadas.remove(_num(x))),
              title: Text('Opción ${_num(x)} · ${dinero(x.variante(factura: _factura).precioContado)}'),
              subtitle: adquiridas.contains(_num(x))
                  ? const Text('Ya la adquiriste')
                  : (x.notas == null ? null : Text(x.notas!, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ),
          const SizedBox(height: 8),
        ],
        if (o.eligeFactura)
          SwitchListTile(
            key: const Key('facturaCompra'),
            contentPadding: EdgeInsets.zero,
            value: _factura,
            onChanged: (v) => _cambiar(() => _factura = v),
            title: const Text('Requiero factura'),
          ),
        const _Titulo('¿Cuánto pagas hoy?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Eleccion(clave: 'modo-liquidar', texto: 'Todo el mueble', elegida: _modalidad == 'liquidar', onTap: () => _cambiar(() => _modalidad = 'liquidar')),
            _Eleccion(clave: 'modo-fabricacion', texto: '50 % · inicia fabricación', elegida: _modalidad == 'fabricacion', onTap: () => _cambiar(() => _modalidad = 'fabricacion')),
            _Eleccion(
              clave: 'modo-apartado',
              texto: 'Apartar',
              elegida: _modalidad == 'apartado',
              // Apartar no va a meses: pasa a tarjeta en una exhibición.
              onTap: () => _cambiar(() {
                _modalidad = 'apartado';
                if (_metodo == 'meses') _metodo = 'tarjeta';
              }),
            ),
          ],
        ),
        if (_modalidad == 'apartado') ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('montoApartadoReal'),
            controller: _monto,
            keyboardType: TextInputType.number,
            onChanged: (_) => _cambiar(() {}),
            decoration: InputDecoration(
              labelText: '¿Con cuánto apartas? (pesos)',
              helperText: c == null ? 'Desde el 10 % del precio.' : 'Desde ${dinero(c.apartadoMinimo)} y menos de ${dinero(c.anticipo)}.',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const _Titulo('¿Cómo pagas?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Eleccion(clave: 'metodo-transferencia', texto: 'Transferencia', elegida: _metodo == 'transferencia', onTap: () => _cambiar(() => _metodo = 'transferencia')),
            _Eleccion(clave: 'metodo-efectivo', texto: 'Efectivo', elegida: _metodo == 'efectivo', onTap: () => _cambiar(() => _metodo = 'efectivo')),
            _Eleccion(clave: 'metodo-tarjeta', texto: 'Tarjeta · una exhibición', elegida: _metodo == 'tarjeta', onTap: () => _cambiar(() => _metodo = 'tarjeta')),
            if (_modalidad != 'apartado')
              _Eleccion(clave: 'metodo-meses', texto: 'Tarjeta a meses sin intereses', elegida: _metodo == 'meses', onTap: () => _cambiar(() => _metodo = 'meses')),
          ],
        ),
        if (_aMeses) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _plazosMsi)
                _Eleccion(clave: 'plazo-$m', texto: '$m meses', elegida: _plazo == m, onTap: () => _cambiar(() => _plazo = m)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, key: const Key('errorCompra'), style: const TextStyle(color: MoblarColors.danger))
        else if (_cotizando && c == null)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (c != null)
          Card(
            key: const Key('desgloseCompra'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Renglon('Total de tu proyecto', dinero(c.total)),
                  _Renglon(c.liquida ? 'Lo liquidas hoy' : 'Pagas hoy', dinero(c.pago)),
                  if (c.comision > 0) _Renglon('Comisión de la tarjeta', dinero(c.comision)),
                  if (c.cobro != c.pago) ...[
                    const Divider(height: 20),
                    _Renglon(
                      _aMeses ? 'Se cargará a tu tarjeta ($_plazo meses)' : 'Se cargará a tu tarjeta',
                      dinero(c.cobro),
                      fuerte: true,
                    ),
                    if (_aMeses)
                      Text(
                        '$_plazo pagos de ${dinero(c.cobro / _plazo)} sin intereses',
                        key: const Key('mensualidadCompra'),
                        style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary),
                      ),
                  ],
                  if (c.faltaFabricacion > 0 && !c.liquida) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Para iniciar la fabricación te faltarán ${dinero(c.faltaFabricacion)} (50 %) y firmar tu cotización formal.',
                      style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (metodo == 'transferencia' && t != null && c != null) ...[
          Card(
            key: const Key('datosTransferenciaCompra'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transfiere ${dinero(c.pago)} a:', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${t.banco} · ${t.beneficiario}'),
                  SelectableText('CLABE ${t.clabeLegible}'),
                  SelectableText('Concepto: ${t.concepto}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (metodo == 'transferencia' && c != null) ...[
          OutlinedButton.icon(
            key: const Key('adjuntarComprobante'),
            onPressed: _enviando ? null : _adjuntar,
            icon: Icon(_archivo == null ? Icons.attach_file : Icons.check_circle_outline),
            label: Text(_archivo == null ? 'Adjuntar comprobante' : 'Cambiar comprobante'),
          ),
          const SizedBox(height: 4),
          Text(
            _archivo?.nombre ?? 'Una captura de pantalla de tu transferencia o el PDF del banco (máx. 10 MB).',
            key: const Key('nombreComprobante'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
          ),
          const SizedBox(height: 4),
        ],
        if (metodo == 'efectivo' && c != null) ...[
          Text(
            'Entrégale ${dinero(c.pago)} a tu arquitecto. Él escribe aquí su PIN para confirmar que lo recibió.',
            style: const TextStyle(color: MoblarColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('pinArquitecto'),
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 12),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'PIN de tu arquitecto',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (metodo == 'tarjeta')
          const Text(
            'Sin comisión pagando en efectivo o por transferencia.',
            style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('confirmarCompra'),
          onPressed: c == null || _enviando || _cotizando || !_completo ? null : _confirmar,
          icon: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(metodo == 'tarjeta' ? Icons.credit_card : Icons.check),
          label: Text(switch (metodo) {
            'tarjeta' => c == null ? 'Pagar con Clip' : 'Pagar ${dinero(c.cobro)} con Clip',
            'transferencia' => 'Ya hice la transferencia',
            _ => 'Confirmar pago en efectivo',
          }),
        ),
        ...widget.pie,
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );
}

class _Eleccion extends StatelessWidget {
  const _Eleccion({required this.clave, required this.texto, required this.elegida, required this.onTap});

  final String clave;
  final String texto;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        key: Key(clave),
        label: Text(texto),
        selected: elegida,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      );
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.fuerte = false});

  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500,
      color: MoblarColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

/// Las compras reales de esta opción: qué pagó, cómo y en qué va.
class ResumenComprasReales extends StatelessWidget {
  const ResumenComprasReales({super.key, required this.compras, this.onSubirComprobante});

  final List<CompraOferta> compras;

  /// Transferencia sin comprobante: subirlo después.
  final Future<void> Function(CompraOferta c)? onSubirComprobante;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('comprasReales'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in compras)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Dato(
              icono: c.validada ? Icons.check_circle_outline : Icons.schedule,
              texto: '${c.opciones.length > 1 ? 'Opciones ${c.opciones.join(', ')}' : 'Opción ${c.opciones.first}'}'
                  ' · ${dinero(c.pago)} · ${c.resumen}',
            ),
          ),
        for (final c in compras.where((c) => c.faltaComprobante && onSubirComprobante != null))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('subirComprobante-${c.id}'),
              onPressed: () => onSubirComprobante!(c),
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir comprobante'),
            ),
          ),
      ],
    );
  }
}

/// "Para iniciar tu proyecto" (Carlos, 2026-10-26): la firma de la cotización
/// formal y el 50 % pagado. Levantamiento y compra van por separado.
class ParaIniciar extends StatelessWidget {
  const ParaIniciar({super.key, required this.firmada, required this.anticipo, required this.adquirida});

  final bool firmada;
  final bool anticipo;
  final bool adquirida;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF065F46);
    Widget renglon(bool hecho, String texto) => Row(
          children: [
            Icon(hecho ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: hecho ? verde : MoblarColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: TextStyle(color: hecho ? verde : MoblarColors.textPrimary))),
          ],
        );
    final listo = firmada && anticipo;
    return Container(
      key: const Key('paraIniciar'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: listo ? const Color(0xFFD1FAE5) : MoblarColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listo ? '¡Todo listo! Empezamos con tu proyecto.' : 'Para iniciar tu proyecto',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          renglon(firmada, firmada ? 'Cotización formal firmada' : 'Firma tu cotización formal'),
          const SizedBox(height: 4),
          renglon(anticipo, anticipo ? 'Anticipo del 50 % pagado' : (adquirida ? 'Completa tu anticipo del 50 %' : 'Paga tu anticipo del 50 %')),
        ],
      ),
    );
  }
}

/// Un pago con tarjeta que se empezó y no se terminó (el cliente abrió Clip y
/// regresó sin pagar). No aparta nada: puede pagar de nuevo con cualquier forma.
class PagoSinTerminar extends StatelessWidget {
  const PagoSinTerminar({super.key, required this.compra});

  final CompraOferta compra;

  @override
  Widget build(BuildContext context) {
    final que = compra.opciones.length > 1 ? 'las opciones ${compra.opciones.join(', ')}' : 'la opción ${compra.opciones.first}';
    return Container(
      key: const Key('pagoSinTerminar'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Tu pago con tarjeta de ${dinero(compra.cobro ?? compra.pago)} por $que no se completó. '
        'No se te cobró nada: puedes pagar de nuevo con tarjeta, efectivo o transferencia. '
        'Si sí lo pagaste en Clip, en unos minutos aparecerá como pagado.',
        style: const TextStyle(fontSize: 13, color: MoblarColors.textPrimary),
      ),
    );
  }
}
