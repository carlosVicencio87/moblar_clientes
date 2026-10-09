import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';

// ---------------------------------------------------------------------------
// Abonar con tarjeta (Carlos, 2026-10-08/09; claude/CLIP_LINK_PAGO_PLAN.md).
//
// El cliente escribe cuánto quiere abonar (o liquida su saldo) y ve en vivo
// el desglose que calcula el servidor: lo que se aplica a su saldo, la
// comisión de la tarjeta (la paga él) y lo que se le carga. Al confirmar, el
// ERP genera un link de Clip con ese monto exacto y se abre la página segura
// de Clip. Solo un pago (sin MSI): los MSI son para el precio total al
// adquirir. Con transferencia o depósito no hay comisión, y se le recuerda.
// ---------------------------------------------------------------------------

class AbonoTarjetaPage extends StatefulWidget {
  const AbonoTarjetaPage({
    super.key,
    required this.compra,
    this.espera = const Duration(milliseconds: 450),
    this.intervalo = const Duration(seconds: 5),
  });

  final Compra compra;

  /// Pausa tras teclear antes de pedir el desglose.
  final Duration espera;

  /// Cada cuánto se revisa el pago mientras está abierto Clip.
  final Duration intervalo;

  @override
  State<AbonoTarjetaPage> createState() => _AbonoTarjetaPageState();
}

class _AbonoTarjetaPageState extends State<AbonoTarjetaPage> {
  final _monto = TextEditingController();
  bool _liquidar = false;
  CotizacionAbono? _cot;
  String? _error;
  bool _cotizando = false;
  bool _creando = false;
  int _pedido = 0;
  Timer? _debounce;

  LinkPagoTarjeta? _link;
  EstadoPagoTarjeta? _estado;
  Timer? _sondeo;
  bool _revisando = false;

  num get _saldo => widget.compra.cuenta?.saldo ?? 0;
  num get _minimo {
    final m = widget.compra.pagoTarjeta?.abonoMinimo ?? 1000;
    return m < _saldo ? m : _saldo;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sondeo?.cancel();
    _monto.dispose();
    super.dispose();
  }

  void _alEscribir(String _) {
    _debounce?.cancel();
    _debounce = Timer(widget.espera, _cotizar);
  }

  Future<void> _cotizar() async {
    final texto = _monto.text.trim();
    final monto = int.tryParse(texto);
    if (!_liquidar && (texto.isEmpty || monto == null || monto <= 0)) {
      setState(() {
        _cot = null;
        _error = null;
      });
      return;
    }
    final pedido = ++_pedido;
    setState(() => _cotizando = true);
    try {
      final c = await AppScope.read(context).cotizarAbono(
        widget.compra.id,
        monto: _liquidar ? null : monto,
        liquidar: _liquidar,
      );
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _cot = c;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _cot = null;
        _error = e.mensaje;
      });
    } finally {
      if (mounted && pedido == _pedido) setState(() => _cotizando = false);
    }
  }

  Future<void> _pagar() async {
    final c = _cot;
    if (c == null) return;
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      final l = await AppScope.read(context).crearPagoTarjeta(
        widget.compra.id,
        monto: _liquidar ? null : int.tryParse(_monto.text.trim()),
        liquidar: _liquidar,
      );
      if (!mounted) return;
      setState(() => _link = l);
      _sondeo = Timer.periodic(widget.intervalo, (_) => _revisar());
      await abrirEnlace(context, Uri.parse(l.url), trasEspera: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _revisar() async {
    if (_revisando || !mounted) return;
    _revisando = true;
    try {
      final e = await AppScope.read(context).revisarPagoPendiente();
      if (!mounted || e == null) return;
      setState(() => _estado = e);
      if (!e.pendiente) _sondeo?.cancel();
    } finally {
      _revisando = false;
    }
  }

  Future<void> _cancelar() async {
    _sondeo?.cancel();
    await AppScope.read(context).olvidarPagoPendiente();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonar con tarjeta')),
      body: ListView(
        key: const Key('abonoTarjeta'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text('Tu saldo', style: TextStyle(color: MoblarColors.textMuted)),
          Text(
            dinero(_saldo),
            key: const Key('saldoAbono'),
            style: const TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w700, color: MoblarColors.primaryDark),
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('sinComision'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              children: [
                Icon(Icons.savings_outlined, color: Color(0xFF065F46)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin comisión pagando por transferencia o depósito. Con tarjeta se suma la comisión del banco.',
                    style: TextStyle(color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_link == null) ..._formulario() else ..._enCurso(_link!),
        ],
      ),
    );
  }

  List<Widget> _formulario() {
    final c = _cot;
    return [
      TextField(
        key: const Key('montoAbono'),
        controller: _monto,
        enabled: !_liquidar,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        onChanged: _alEscribir,
        decoration: InputDecoration(
          labelText: '¿Cuánto quieres abonar?',
          prefixText: r'$ ',
          helperText: 'Mínimo ${dinero(_minimo)} · máximo tu saldo',
          border: const OutlineInputBorder(),
        ),
      ),
      CheckboxListTile(
        key: const Key('liquidarSaldo'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _liquidar,
        onChanged: (v) {
          setState(() => _liquidar = v ?? false);
          _cotizar();
        },
        title: Text('Liquidar todo mi saldo (${dinero(_saldo)})'),
      ),
      if (_cotizando)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(_error!, key: const Key('errorAbono'), style: const TextStyle(color: MoblarColors.danger)),
        ),
      if (c != null) ...[
        Card(
          key: const Key('desgloseAbono'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Fila(c.liquida ? 'Se liquida tu saldo' : 'Se aplica a tu saldo', dinero(c.neto)),
                _Fila('Comisión de la tarjeta', dinero(c.comision)),
                const Divider(height: 20),
                _Fila('Se cargará a tu tarjeta', dinero(c.cobro), fuerte: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('pagarTarjeta'),
          onPressed: _cotizando || _creando ? null : _pagar,
          icon: _creando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.credit_card),
          label: Text('Pagar ${dinero(c.cobro)} con tarjeta'),
        ),
      ],
      const SizedBox(height: 12),
      const Dato(
        icono: Icons.lock_outline,
        texto: 'Pagas en la página segura de Clip, en un solo pago con débito o crédito. '
            'Los meses sin intereses son solo para el precio total al adquirir tu mueble.',
      ),
    ];
  }

  List<Widget> _enCurso(LinkPagoTarjeta l) {
    final e = _estado;
    final pagado = e?.pagado == true;
    final terminado = e != null && !e.pendiente;
    return [
      Card(
        key: const Key('pagoEnCurso'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    pagado ? Icons.verified_outlined : (terminado ? Icons.timer_off_outlined : Icons.hourglass_top),
                    color: pagado ? MoblarColors.success : MoblarColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pagado
                          ? '¡Pago recibido!'
                          : terminado
                              ? 'Este link ya no está disponible'
                              : 'Completa tu pago en la página de Clip',
                      key: const Key('estadoPagoTarjeta'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pagado
                    ? 'Se aplicarán ${dinero(l.cotizacion.neto)} a tu saldo.'
                    : 'Se cargarán ${dinero(l.cotizacion.cobro)} a tu tarjeta; a tu saldo se aplican ${dinero(l.cotizacion.neto)}.',
                style: const TextStyle(color: MoblarColors.textSecondary),
              ),
              if (!terminado) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('abrirClip'),
                  onPressed: () => abrirEnlace(context, Uri.parse(l.url)),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir la página de pago'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('revisarPago'),
                  onPressed: _revisar,
                  child: const Text('Ya pagué: revisar'),
                ),
                TextButton(
                  key: const Key('cancelarPago'),
                  onPressed: _cancelar,
                  child: const Text('Cancelar este pago'),
                ),
              ] else
                FilledButton(
                  key: const Key('listoPago'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor, {this.fuerte = false});

  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontSize: fuerte ? 17 : 14, fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400);
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
