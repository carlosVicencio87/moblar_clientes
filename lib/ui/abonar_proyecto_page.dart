import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'abono_tarjeta_page.dart';
import 'widgets/adquirir_real.dart' show ArchivoComprobante;
import 'widgets/comunes.dart';
import 'widgets/pago_visita.dart' show AvisoDemo, EfectivoPinPage, TransferenciaPagoPage;

// ---------------------------------------------------------------------------
// "Abonar a mi proyecto" (Carlos, 2026-10-09): mismas formas de pago que al
// adquirir. El cliente escribe cuánto (o liquida su saldo) y elige:
//   - Efectivo: lo recibe el arquitecto y lo confirma con SU PIN.
//   - Transferencia: datos de la cuenta de Moblar + comprobante → en revisión.
//   - Tarjeta: link de Clip (un solo pago).
// Desde 2026-11-11 (gerencia) los tres son REALES (`opciones`): efectivo y
// tarjeta entran validados a los pagos del proyecto; la transferencia entra
// en revisión y la valida Pagos. El cliente no ve comisión.
// Sin `opciones` (Preview viejo) queda la demostración que no guarda nada.
// ---------------------------------------------------------------------------

String _nuevoRequestId() {
  final r = Random.secure();
  const letras = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'abono-${List.generate(20, (_) => letras[r.nextInt(letras.length)]).join()}';
}

class AbonarProyectoPage extends StatefulWidget {
  const AbonarProyectoPage({
    super.key,
    required this.destino,
    this.tarjeta = false,
    this.transferencia,
    this.arquitecto,
    this.demo = false,
    this.opciones,
  });

  final DestinoAbono destino;

  /// Formas de abonar de verdad (ERP); null = demostración.
  final OpcionesAbono? opciones;

  /// Hay pago con tarjeta (Clip configurado).
  final bool tarjeta;

  /// Datos para transferir (solo demo).
  final DatosTransferencia? transferencia;

  /// Quién recibe el efectivo (solo demo).
  final String? arquitecto;
  final bool demo;

  @override
  State<AbonarProyectoPage> createState() => _AbonarProyectoPageState();
}

class _AbonarProyectoPageState extends State<AbonarProyectoPage> {
  final _monto = TextEditingController();
  bool _liquidar = false;

  /// Un abono = un requestId: si el teléfono reintenta, el ERP no lo duplica.
  String _requestId = _nuevoRequestId();

  num get _saldo => widget.destino.saldo;

  /// Monto elegido (pesos) o null si todavía no es válido.
  num? get _elegido {
    if (_liquidar) return _saldo;
    final m = int.tryParse(_monto.text.trim());
    if (m == null || m <= 0 || m > _saldo) return null;
    return m;
  }

  String? get _aviso {
    if (_liquidar) return null;
    final t = _monto.text.trim();
    if (t.isEmpty) return null;
    final m = int.tryParse(t);
    if (m == null || m <= 0) return 'Escribe cuánto quieres abonar.';
    if (m > _saldo) return 'Tu saldo es ${dinero(_saldo)}: no puedes abonar más.';
    return null;
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _abrir(Widget pagina) async {
    final listo = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => pagina));
    if (listo == true && mounted) Navigator.of(context).pop();
  }

  void _registrar(num monto, String metodo, {required bool validado}) {
    if (widget.opciones != null) {
      // Real: el ERP ya lo registró; el siguiente abono es otro.
      _requestId = _nuevoRequestId();
      return;
    }
    AppScope.read(context).registrarAbonoDemo(
      widget.destino.claveLocal,
      AbonoDemo(fecha: DateTime.now(), monto: monto, metodo: metodo, validado: validado),
    );
  }

  Future<String> _efectivoReal(String pin, num monto) => AppScope.read(context).abonoEfectivo(
        widget.destino.id,
        monto: _liquidar ? null : monto,
        liquidar: _liquidar,
        pin: pin,
        requestId: _requestId,
      );

  Future<String> _transferenciaReal(ArchivoComprobante a, num monto) => AppScope.read(context).abonoTransferencia(
        widget.destino.id,
        monto: _liquidar ? null : monto,
        liquidar: _liquidar,
        requestId: _requestId,
        bytes: a.bytes,
        extension: a.extension,
      );

  @override
  Widget build(BuildContext context) {
    final m = _elegido;
    final real = widget.opciones;
    final demo = real == null && widget.demo;
    final efectivo = real != null ? real.efectivo : demo;
    final transferencia = real != null ? real.transferencia : (demo ? widget.transferencia : null);
    final arquitecto = real != null ? real.arquitecto : widget.arquitecto;
    final conTarjeta = real != null ? real.tarjeta != null : widget.tarjeta;
    return Scaffold(
      appBar: AppBar(title: const Text('Abonar a mi proyecto')),
      body: ListView(
        key: const Key('paginaAbonarProyecto'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          const Text('Tu saldo', style: TextStyle(color: MoblarColors.textMuted)),
          Text(
            dinero(_saldo),
            key: const Key('saldoProyecto'),
            style: const TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w700, color: MoblarColors.primaryDark),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('montoProyecto'),
            controller: _monto,
            enabled: !_liquidar,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '¿Cuánto quieres abonar?',
              prefixText: r'$ ',
              errorText: _aviso,
              border: const OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            key: const Key('liquidarProyecto'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _liquidar,
            onChanged: (v) => setState(() => _liquidar = v ?? false),
            title: Text('Liquidar todo mi saldo (${dinero(_saldo)})'),
          ),
          const SizedBox(height: 8),
          const Text('¿Cómo quieres pagar?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (efectivo)
            _Forma(
              clave: const Key('abonoEfectivo'),
              icono: Icons.payments_outlined,
              titulo: m == null ? 'Efectivo' : 'Efectivo · ${dinero(m)}',
              texto: 'Se lo entregas a tu arquitecto y él lo confirma con su PIN en tu pantalla.',
              onTap: m == null
                  ? null
                  : () => _abrir(EfectivoPinPage(
                        titulo: 'Abono en efectivo',
                        monto: m,
                        arquitecto: arquitecto,
                        demo: demo,
                        confirmarReal: real == null ? null : (pin) => _efectivoReal(pin, m),
                        onConfirmado: () => _registrar(m, 'Efectivo', validado: true),
                      )),
            ),
          if (transferencia != null)
            _Forma(
              clave: const Key('abonoTransferencia'),
              icono: Icons.account_balance_outlined,
              titulo: m == null ? 'Transferencia' : 'Transferencia · ${dinero(m)}',
              texto: 'Te damos los datos de la cuenta y subes tu comprobante.',
              onTap: m == null
                  ? null
                  : () => _abrir(TransferenciaPagoPage(
                        titulo: 'Abono por transferencia',
                        monto: m,
                        datos: transferencia,
                        demo: demo,
                        paraQue: 'del abono a tu mueble',
                        enviarReal: real == null ? null : (a) => _transferenciaReal(a, m),
                        onEnviado: (_) => _registrar(m, 'Transferencia', validado: false),
                      )),
            ),
          if (conTarjeta)
            _Forma(
              clave: const Key('abonoTarjeta'),
              icono: Icons.credit_card,
              titulo: 'Tarjeta',
              texto: 'Débito o crédito en un solo pago, en la página segura de Clip.',
              onTap: m == null
                  ? null
                  : () => _abrir(AbonoTarjetaPage(
                        destino: widget.destino,
                        montoInicial: _liquidar ? null : m.toInt(),
                        liquidarInicial: _liquidar,
                      )),
            ),
          if (!efectivo && transferencia == null)
            const Dato(
              icono: Icons.info_outline,
              texto: 'Para abonar por transferencia o depósito, escríbenos y te damos los datos.',
            ),
        ],
      ),
    );
  }
}

class _Forma extends StatelessWidget {
  const _Forma({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activa = onTap != null;
    return Opacity(
      opacity: activa ? 1 : 0.55,
      child: Card(
        key: clave,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: MoblarColors.primarySoft,
                  child: Icon(icono, color: MoblarColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(texto, style: const TextStyle(color: MoblarColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
