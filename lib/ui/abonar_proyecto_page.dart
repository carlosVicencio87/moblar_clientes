import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'abono_tarjeta_page.dart';
import 'widgets/comunes.dart';
import 'widgets/pago_visita.dart' show AvisoDemo, EfectivoPinPage, TransferenciaPagoPage;

// ---------------------------------------------------------------------------
// "Abonar a mi proyecto" (Carlos, 2026-10-09): mismas formas de pago que al
// adquirir. El cliente escribe cuánto (o liquida su saldo) y elige:
//   - Efectivo: lo recibe el arquitecto y lo confirma con SU PIN.
//   - Transferencia: datos de la cuenta de Moblar + comprobante → en revisión.
//   - Tarjeta: link de Clip; se suma la comisión (la paga el cliente).
// Efectivo y transferencia solo en la demostración (oferta adquirida): para
// una compra real del ERP se registran en Pagos cuando gerencia lo apruebe.
// ---------------------------------------------------------------------------

class AbonarProyectoPage extends StatefulWidget {
  const AbonarProyectoPage({
    super.key,
    required this.destino,
    this.tarjeta = false,
    this.transferencia,
    this.arquitecto,
    this.demo = false,
  });

  final DestinoAbono destino;

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
    AppScope.read(context).registrarAbonoDemo(
      widget.destino.id,
      AbonoDemo(fecha: DateTime.now(), monto: monto, metodo: metodo, validado: validado),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _elegido;
    final demo = widget.demo && widget.destino.oferta;
    final efectivo = demo;
    final transferencia = demo ? widget.transferencia : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Abonar a mi proyecto')),
      body: ListView(
        key: const Key('abonarProyecto'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.demo) ...[
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
              texto: 'Se lo entregas a tu arquitecto y él lo confirma con su PIN en tu pantalla. Sin comisión.',
              onTap: m == null
                  ? null
                  : () => _abrir(EfectivoPinPage(
                        titulo: 'Abono en efectivo',
                        monto: m,
                        arquitecto: widget.arquitecto,
                        demo: widget.demo,
                        onConfirmado: () => _registrar(m, 'Efectivo', validado: true),
                      )),
            ),
          if (transferencia != null)
            _Forma(
              clave: const Key('abonoTransferencia'),
              icono: Icons.account_balance_outlined,
              titulo: m == null ? 'Transferencia' : 'Transferencia · ${dinero(m)}',
              texto: 'Te damos los datos de la cuenta y subes tu comprobante. Sin comisión.',
              onTap: m == null
                  ? null
                  : () => _abrir(TransferenciaPagoPage(
                        titulo: 'Abono por transferencia',
                        monto: m,
                        datos: transferencia,
                        demo: widget.demo,
                        paraQue: 'del abono a tu mueble',
                        onEnviado: (_) => _registrar(m, 'Transferencia', validado: false),
                      )),
            ),
          if (widget.tarjeta)
            _Forma(
              clave: const Key('abonoTarjeta'),
              icono: Icons.credit_card,
              titulo: 'Tarjeta',
              texto: 'Débito o crédito en un solo pago, en la página segura de Clip. '
                  'Se suma la comisión de la tarjeta.',
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
              texto: 'Para abonar por transferencia o depósito sin comisión, escríbenos y te damos los datos.',
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
