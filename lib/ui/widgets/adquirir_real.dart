import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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
    this.factura = true,
    this.cotizar,
    this.adquirir,
    this.abrir,
  });

  /// La oferta completa (con sus opciones y compras).
  final OfertaVisita oferta;

  /// La opción que se marca al abrir (1..3).
  final int inicial;
  final bool factura;

  /// Inyectables para pruebas.
  final Future<CotizacionCompra> Function(PedidoCompra p)? cotizar;
  final Future<ResultadoCompra> Function(PedidoCompra p)? adquirir;
  final Future<void> Function(Uri url)? abrir;

  @override
  State<AdquirirOpcionesPage> createState() => _AdquirirOpcionesPageState();
}

class _AdquirirOpcionesPageState extends State<AdquirirOpcionesPage> {
  late final Set<int> _marcadas = {widget.inicial};
  late bool _factura = widget.factura;
  String _modalidad = 'fabricacion';
  String _metodo = 'transferencia';
  int _plazo = 12;
  final _monto = TextEditingController();
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
        metodo: _modalidad == 'msi' ? 'tarjeta' : _metodo,
        factura: _factura,
        plazo: _modalidad == 'msi' ? _plazo : 0,
        monto: _modalidad == 'apartado' ? num.tryParse(_monto.text.replaceAll(RegExp(r'[^0-9]'), '')) : null,
        requestId: _requestId,
      );

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
    final vuelta = ++_vuelta;
    setState(() => _cotizando = true);
    try {
      final c = widget.cotizar != null
          ? await widget.cotizar!(_pedido)
          : await AppScope.read(context).cotizarCompra(widget.oferta.citaId, _pedido);
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

  Future<void> _confirmar() async {
    if (_cot == null || _enviando) return;
    setState(() => _enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    final app = widget.adquirir == null ? AppScope.read(context) : null;
    try {
      final r = widget.adquirir != null
          ? await widget.adquirir!(_pedido)
          : await app!.adquirir(widget.oferta.citaId, _pedido);
      if (!mounted) return;
      final link = r.link;
      if (link == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(r.compra.metodo == 'tarjeta'
              ? 'Tu compra ya estaba registrada.'
              : 'Registramos tu compra. Te avisamos en cuanto validemos tu pago.'),
        ));
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
      appBar: AppBar(title: const Text('Adquirir')),
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
    final metodo = _modalidad == 'msi' ? 'tarjeta' : _metodo;
    return ListView(
      key: const Key('adquirirOpciones'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
        const _Titulo('¿Cómo quieres iniciar?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Eleccion(clave: 'modo-fabricacion', texto: 'Iniciar fabricación · 50 %', elegida: _modalidad == 'fabricacion', onTap: () => _cambiar(() => _modalidad = 'fabricacion')),
            _Eleccion(clave: 'modo-apartado', texto: 'Apartar', elegida: _modalidad == 'apartado', onTap: () => _cambiar(() => _modalidad = 'apartado')),
            _Eleccion(clave: 'modo-msi', texto: 'A meses sin intereses', elegida: _modalidad == 'msi', onTap: () => _cambiar(() => _modalidad = 'msi')),
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
        if (_modalidad == 'msi') ...[
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
        if (_modalidad != 'msi') ...[
          const _Titulo('¿Cómo pagas?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Eleccion(clave: 'metodo-transferencia', texto: 'Transferencia', elegida: _metodo == 'transferencia', onTap: () => _cambiar(() => _metodo = 'transferencia')),
              _Eleccion(clave: 'metodo-efectivo', texto: 'Efectivo', elegida: _metodo == 'efectivo', onTap: () => _cambiar(() => _metodo = 'efectivo')),
              _Eleccion(clave: 'metodo-tarjeta', texto: 'Tarjeta', elegida: _metodo == 'tarjeta', onTap: () => _cambiar(() => _metodo = 'tarjeta')),
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
                      _modalidad == 'msi' ? 'Se cargará a tu tarjeta ($_plazo meses)' : 'Se cargará a tu tarjeta',
                      dinero(c.cobro),
                      fuerte: true,
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
        if (metodo == 'efectivo' && c != null)
          Text(
            'Entrégale ${dinero(c.pago)} a tu arquitecto. Lo confirmamos y te avisamos.',
            style: const TextStyle(color: MoblarColors.textSecondary),
          ),
        if (metodo == 'tarjeta')
          const Text(
            'Sin comisión pagando en efectivo o por transferencia.',
            style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('confirmarCompra'),
          onPressed: c == null || _enviando || _cotizando ? null : _confirmar,
          icon: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(metodo == 'tarjeta' ? Icons.credit_card : Icons.check),
          label: Text(switch (metodo) {
            'tarjeta' => c == null ? 'Pagar con Clip' : 'Pagar ${dinero(c.cobro)} con Clip',
            'transferencia' => 'Ya hice la transferencia',
            _ => 'Confirmar',
          }),
        ),
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
  const ResumenComprasReales({super.key, required this.compras});

  final List<CompraOferta> compras;

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
