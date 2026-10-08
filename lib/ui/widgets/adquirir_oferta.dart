import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';
import 'pago_visita.dart' show AvisoDemo, DemoPagosVisita, EfectivoPinPage, TransferenciaPagoPage;

// ---------------------------------------------------------------------------
// Adquirir la cotización de la visita — ESQUELETO DE DEMOSTRACIÓN
// (Carlos, 2026-10-05).
//
// Para iniciar el proyecto se requiere el 40% de anticipo (el mismo umbral
// con el que el ERP pasa un proyecto a "anticipo validado"). Tres formas:
//   - Efectivo: el arquitecto confirma con SU PIN en la pantalla del cliente.
//   - Transferencia: datos de la cuenta + comprobante → en revisión.
//   - Tarjeta con Clip, en un solo pago: sobre el precio con tarjeta (contado +
//     solo la comisión base de Clip; Carlos, 2026-10-05). En la demo
//     NO se abre ningún link: el link de Clip sigue apagado hasta que los
//     stakeholders lo aprueben.
// Factura (Carlos, 2026-10-05): "Requiero factura" viene marcada (precios con
// IVA). Si el cliente la desmarca, todos los montos pasan a la variante sin
// IVA que manda el servidor. SOLO DEMO: pendiente de validar con el contador.
// Los montos vienen del servidor (clienteOfertaVisita.ts). Nada se guarda:
// el resultado vive en memoria (DemoAnticipos) mientras la app está abierta.
//
// La visita al comprar (Carlos, 2026-10-08): si el cliente inicia su
// proyecto, la visita NO se cobra. Si ya la había pagado, ese monto se le
// abona a lo que paga hoy (el anticipo o, a meses, el cobro completo). En
// cualquier caso termina pagando el precio del mueble: ni más ni menos.
// En la demo el pago de la visita vive en memoria (DemoPagosVisita), por eso
// el abono se resta aquí; con el registro real lo calculará el servidor.
// ---------------------------------------------------------------------------

class ResultadoAnticipo {
  const ResultadoAnticipo({
    required this.metodo,
    required this.monto,
    required this.fecha,
    this.arquitecto,
    this.meses = 1,
    this.totalMueble,
    this.liquida = false,
    this.factura = true,
    this.abonoVisita = 0,
  });

  /// Lo que ya había pagado de su visita y se abonó a este pago.
  final num abonoVisita;

  /// Pidió factura (precios con IVA).
  final bool factura;

  /// "efectivo" | "transferencia" | "tarjeta"
  final String metodo;
  final num monto;
  final DateTime fecha;

  /// Quién confirmó con su PIN (efectivo).
  final String? arquitecto;

  /// Con tarjeta: 1 = un solo pago; si no, meses sin intereses.
  final int meses;

  /// Con tarjeta: precio del mueble en el plazo elegido.
  final num? totalMueble;

  /// A meses: se pagó el mueble completo (no es un anticipo).
  final bool liquida;

  bool get conTarjeta => metodo == 'tarjeta';

  String get metodoLegible => switch (metodo) {
        'efectivo' => 'Efectivo',
        'transferencia' => 'Transferencia',
        _ => meses > 1 ? 'Tarjeta, $meses MSI' : 'Tarjeta, un solo pago',
      };
}

/// Anticipos de la demostración, por id de cita. Solo en memoria.
class DemoAnticipos {
  DemoAnticipos._();

  static final resultados = ValueNotifier<Map<String, ResultadoAnticipo>>(const {});

  static void registrar(String citaId, ResultadoAnticipo r) {
    resultados.value = {...resultados.value, citaId: r};
  }

  static void reiniciar(String citaId) {
    resultados.value = {...resultados.value}..remove(citaId);
  }
}

int _centavos(num x) => (x * 100).round();

/// [monto] menos [abono], al centavo y nunca negativo.
num menosAbono(num monto, num abono) {
  final c = _centavos(monto) - _centavos(abono);
  return c <= 0 ? 0 : c / 100;
}

/// Lo que se abona de la visita al iniciar el proyecto: su monto si ya la
/// pagó (efectivo o transferencia); 0 si no (entonces simplemente no se cobra).
num abonoVisita(String citaId, num montoVisita) =>
    montoVisita > 0 && DemoPagosVisita.resultados.value.containsKey(citaId) ? montoVisita : 0;

/// Una forma de pago con tarjeta con el abono de la visita ya descontado del
/// cobro. El precio del mueble ([OpcionTarjeta.total]) no cambia.
OpcionTarjeta conAbono(OpcionTarjeta x, num abono) {
  if (abono <= 0) return x;
  final cobro = menosAbono(x.cobro, abono);
  return OpcionTarjeta(
    meses: x.meses,
    total: x.total,
    mensualidad: x.liquida ? (_centavos(cobro) / x.meses).ceil() / 100 : x.mensualidad,
    cobro: cobro,
    liquida: x.liquida,
  );
}

String muebleDe(OfertaVisita o) => o.muebles.isEmpty ? 'tu mueble' : o.muebles.join(', ');

/// Pantalla "Inicia tu proyecto": por qué el anticipo, cuánto y cómo pagarlo.
class AdquirirOfertaPage extends StatefulWidget {
  const AdquirirOfertaPage({super.key, required this.oferta, this.montoVisita = 0});

  final OfertaVisita oferta;

  /// Costo de la visita de esta cita (0 si no aplica).
  final num montoVisita;

  @override
  State<AdquirirOfertaPage> createState() => _AdquirirOfertaPageState();
}

class _AdquirirOfertaPageState extends State<AdquirirOfertaPage> {
  bool _factura = true;

  Future<void> _abrir(BuildContext context, Widget pagina) async {
    final listo = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => pagina),
    );
    if (listo == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.oferta;
    final factura = _factura || !base.eligeFactura;
    final o = base.variante(factura: factura);
    final pct = o.anticipoPct.round();
    final abono = abonoVisita(o.citaId, widget.montoVisita);
    final hoyContado = menosAbono(o.anticipoContado, abono);
    final hoyTarjeta = menosAbono(o.anticipoTarjeta, abono);
    void registrar(String metodo, num monto, {String? arquitecto}) => DemoAnticipos.registrar(
          o.citaId,
          ResultadoAnticipo(
            metodo: metodo,
            monto: monto,
            fecha: DateTime.now(),
            arquitecto: arquitecto,
            factura: factura,
            abonoVisita: abono,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Inicia tu proyecto')),
      body: ListView(
        key: const Key('adquirirOferta'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (o.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Para empezar a trabajar en ${muebleDe(o)} requerimos el $pct% de anticipo.',
                    key: const Key('mensajeAnticipo'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Con tu anticipo apartamos tu lugar en producción y comenzamos el diseño '
                    'final. El saldo lo verás en el estado de cuenta de tu compra.',
                    style: TextStyle(color: MoblarColors.textSecondary),
                  ),
                  if (widget.montoVisita > 0) ...[
                    const SizedBox(height: 8),
                    Dato(
                      key: const Key('avisoVisitaAnticipo'),
                      icono: Icons.home_work_outlined,
                      texto: abono > 0
                          ? 'Ya pagaste tu visita (${dinero(abono)}): se descuenta de lo que pagas hoy.'
                          : 'Tu visita (${dinero(widget.montoVisita)}) no tiene costo al iniciar tu proyecto.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (base.eligeFactura) ...[
            const SizedBox(height: 12),
            Card(
              child: CheckboxListTile(
                key: const Key('requiereFactura'),
                value: _factura,
                onChanged: (v) => setState(() => _factura = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Requiero factura', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _factura
                      ? 'Precio de tu mueble ${dinero(base.subtotal)} + IVA '
                          '(${base.ivaPct.round()}%) ${dinero(base.iva)}.'
                      : 'Sin factura no se cobra IVA: pagas ${dinero(base.iva)} menos.',
                  key: const Key('detalleFactura'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Resumen(
            clave: const Key('resumenContado'),
            titulo: 'De contado (efectivo o transferencia)',
            precio: o.precioContado,
            anticipo: o.anticipoContado,
            abono: abono,
            pct: pct,
            destacado: true,
          ),
          const SizedBox(height: 8),
          _Resumen(
            clave: const Key('resumenTarjeta'),
            titulo: 'Con tarjeta, en un solo pago',
            precio: o.precioTarjeta,
            anticipo: o.anticipoTarjeta,
            abono: abono,
            pct: pct,
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Cómo quieres pagar tu anticipo?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _Opcion(
            clave: const Key('anticipoEfectivo'),
            icono: Icons.payments_outlined,
            titulo: 'Efectivo · ${dinero(hoyContado)}',
            texto: 'Se lo entregas a tu arquitecto y él lo confirma con su PIN en tu pantalla.',
            onTap: () => _abrir(
              context,
              EfectivoPinPage(
                titulo: 'Anticipo en efectivo',
                monto: hoyContado,
                arquitecto: o.arquitecto,
                demo: o.demo,
                onConfirmado: () => registrar('efectivo', hoyContado, arquitecto: o.arquitecto),
              ),
            ),
          ),
          if (o.transferencia != null)
            _Opcion(
              clave: const Key('anticipoTransferencia'),
              icono: Icons.account_balance_outlined,
              titulo: 'Transferencia · ${dinero(hoyContado)}',
              texto: 'Te damos los datos de la cuenta y subes tu comprobante.',
              onTap: () => _abrir(
                context,
                TransferenciaPagoPage(
                  titulo: 'Anticipo por transferencia',
                  monto: hoyContado,
                  datos: o.transferencia!,
                  demo: o.demo,
                  paraQue: 'del anticipo de tu mueble',
                  onEnviado: (_) => registrar('transferencia', hoyContado),
                ),
              ),
            ),
          _Opcion(
            clave: const Key('anticipoTarjeta'),
            icono: Icons.credit_card,
            titulo: 'Tarjeta · desde ${dinero(hoyTarjeta)}',
            texto: 'Un solo pago (anticipo) o a meses sin intereses (pagas tu mueble completo '
                'y lo difieres). Cada plazo incluye la comisión que cobra Clip.',
            onTap: () => _abrir(
              context,
              _TarjetaClipPage(
                oferta: o,
                abono: abono,
                onPagado: (x) => DemoAnticipos.registrar(
                  o.citaId,
                  ResultadoAnticipo(
                    metodo: 'tarjeta',
                    monto: x.cobro,
                    fecha: DateTime.now(),
                    meses: x.meses,
                    totalMueble: x.total,
                    liquida: x.liquida,
                    factura: factura,
                    abonoVisita: abono,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.clave,
    required this.titulo,
    required this.precio,
    required this.anticipo,
    required this.pct,
    this.abono = 0,
    this.destacado = false,
  });

  final Key clave;
  final String titulo;
  final num precio;
  final num anticipo;

  /// Visita ya pagada que se descuenta de lo que paga hoy.
  final num abono;
  final int pct;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF065F46);
    final color = destacado ? verde : MoblarColors.textPrimary;
    return Container(
      key: clave,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destacado ? const Color(0xFFD1FAE5) : MoblarColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: destacado ? null : Border.all(color: MoblarColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          _Fila('Precio total', dinero(precio), color: color),
          _Fila('Anticipo ($pct%)', dinero(anticipo), color: color, fuerte: abono <= 0),
          if (abono > 0) ...[
            _Fila('Ya pagaste tu visita', '−${dinero(abono)}', color: color),
            _Fila('Pagas hoy', dinero(menosAbono(anticipo, abono)), color: color, fuerte: true),
          ],
          _Fila('Saldo después del anticipo', dinero(precio - anticipo), color: color),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor, {required this.color, this.fuerte = false});

  final String etiqueta;
  final String valor;
  final Color color;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: fuerte ? 16 : 13,
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}

/// Tarjeta con Clip: se despliegan el pago único y nuestros MSI, cada uno con
/// su precio (Clip cobra menos comisión entre menos meses) y su anticipo. En la
/// demo solo simula: el link real (por cobro, con el monto exacto) se habilita
/// cuando lo aprueben.
class _TarjetaClipPage extends StatefulWidget {
  const _TarjetaClipPage({required this.oferta, required this.onPagado, this.abono = 0});

  final OfertaVisita oferta;

  /// Visita ya pagada: se descuenta del cobro de cada opción.
  final num abono;
  final void Function(OpcionTarjeta opcion) onPagado;

  @override
  State<_TarjetaClipPage> createState() => _TarjetaClipPageState();
}

class _TarjetaClipPageState extends State<_TarjetaClipPage> {
  late final List<OpcionTarjeta> _opciones = (widget.oferta.opcionesTarjeta.isNotEmpty
          ? widget.oferta.opcionesTarjeta
          : [
          // Servidor viejo sin plazos: solo el pago único.
          OpcionTarjeta(
            meses: 1,
            total: widget.oferta.precioTarjeta,
            mensualidad: widget.oferta.precioTarjeta,
            cobro: widget.oferta.anticipoTarjeta,
          ),
        ])
      .map((x) => conAbono(x, widget.abono))
      .toList();
  late OpcionTarjeta _elegida = _opciones.first;

  @override
  Widget build(BuildContext context) {
    final o = widget.oferta;
    final x = _elegida;
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar con tarjeta')),
      body: ListView(
        key: const Key('detalleTarjeta'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (o.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          const Text(
            '¿Cómo quieres pagar?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'En un solo pago cubres el anticipo. A meses pagas tu mueble completo y lo '
            'difieres con tu tarjeta de crédito. Entre menos meses, menor precio.',
            style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
          ),
          const SizedBox(height: 10),
          for (final op in _opciones) _FilaPlazo(
            opcion: op,
            elegida: identical(op, _elegida),
            onTap: () => setState(() => _elegida = op),
          ),
          const SizedBox(height: 12),
          Card(
            key: const Key('resumenPlazo'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    x.liquida ? 'Pagas tu mueble completo en' : 'Pagarás tu anticipo de',
                    style: const TextStyle(color: MoblarColors.textMuted),
                  ),
                  Text(
                    x.liquida ? '${x.meses} × ${dinero(x.mensualidad)}' : dinero(x.cobro),
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: MoblarColors.primaryDark,
                    ),
                  ),
                  if (x.liquida)
                    Text(
                      'Se cobra ${dinero(x.cobro)} a tu tarjeta y tu banco lo difiere en '
                      '${x.meses} meses sin intereses. No hay anticipo ni saldo pendiente.',
                      style: const TextStyle(color: MoblarColors.textSecondary),
                    ),
                  const SizedBox(height: 10),
                  Dato(
                    icono: Icons.sell_outlined,
                    texto: 'Precio de tu mueble con esta forma de pago: ${dinero(x.total)}. '
                        'De contado pagarías ${dinero(o.precioContado)}.',
                  ),
                  if (widget.abono > 0)
                    Dato(
                      key: const Key('abonoVisitaTarjeta'),
                      icono: Icons.home_work_outlined,
                      texto: 'Ya pagaste tu visita: se descontaron ${dinero(widget.abono)} de este cobro.',
                    ),
                  const Dato(
                    icono: Icons.lock_outline,
                    texto: 'En la página segura de Clip, con tarjeta de débito o crédito '
                        '(los meses sin intereses, solo con crédito).',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('pagarConClip'),
            onPressed: () {
              widget.onPagado(_elegida);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Demostración: aquí se abriría el pago seguro de Clip.'),
                ),
              );
              Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.credit_card),
            label: const Text('Pagar con Clip'),
          ),
        ],
      ),
    );
  }
}

class _FilaPlazo extends StatelessWidget {
  const _FilaPlazo({required this.opcion, required this.elegida, required this.onTap});

  final OpcionTarjeta opcion;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final x = opcion;
    return Card(
      key: Key('opcionAnticipo-${x.meses}'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: elegida ? MoblarColors.primary : MoblarColors.border,
          width: elegida ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                elegida ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: elegida ? MoblarColors.primary : MoblarColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      x.meses > 1 ? '${x.meses} meses sin intereses' : 'Un solo pago',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Precio del mueble ${dinero(x.total)}',
                      style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    x.liquida ? '${x.meses} × ${dinero(x.mensualidad)}' : dinero(x.cobro),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    x.liquida ? 'mueble completo' : 'anticipo',
                    style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloque "Tu compra" en la tarjeta de la oferta, ya con el anticipo.
class ResumenCompraOferta extends StatelessWidget {
  const ResumenCompraOferta({super.key, required this.oferta, required this.resultado});

  final OfertaVisita oferta;
  final ResultadoAnticipo resultado;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final r = resultado;
    final total = r.conTarjeta ? (r.totalMueble ?? o.precioTarjeta) : o.precioContado;
    final estado = r.metodo == 'efectivo'
        ? 'recibido por ${r.arquitecto ?? 'tu arquitecto'}'
        : r.metodo == 'transferencia'
            ? 'en revisión'
            : 'pagado con Clip';
    return Container(
      key: Key('compraOferta-${o.citaId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoblarColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TU COMPRA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: MoblarColors.primary,
            ),
          ),
          Dato(icono: Icons.chair_outlined, texto: 'Adquiriste: ${muebleDe(o)}'),
          if (o.subtotal > 0)
            Dato(
              icono: Icons.receipt_long_outlined,
              texto: r.factura ? 'Con factura (IVA incluido)' : 'Sin factura (sin IVA)',
            ),
          Dato(
            icono: Icons.sell_outlined,
            texto: r.conTarjeta
                ? (r.meses > 1
                    ? 'Precio con tarjeta (${r.meses} MSI): ${dinero(total)}'
                    : 'Precio con tarjeta: ${dinero(total)}')
                : 'Precio de contado: ${dinero(total)}',
          ),
          Dato(
            icono: Icons.payments_outlined,
            texto: r.liquida
                ? 'Pagado completo: ${dinero(r.monto + r.abonoVisita)} · ${r.metodoLegible} · $estado'
                : 'Anticipo: ${dinero(r.monto + r.abonoVisita)} · ${r.metodoLegible} · $estado',
          ),
          if (r.abonoVisita > 0)
            Dato(
              icono: Icons.home_work_outlined,
              texto: 'Incluye ${dinero(r.abonoVisita)} que ya habías pagado de tu visita.',
            ),
          Dato(
            icono: Icons.account_balance_wallet_outlined,
            texto: r.liquida
                ? 'Saldo: ${dinero(0)} · Liquidado'
                : 'Saldo: ${dinero(menosAbono(total - r.monto, r.abonoVisita))}',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: Key('verCompraOferta-${o.citaId}'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Tu compra'),
                content: Text(
                  'Tu compra aparecerá en «Mi compra» en cuanto validemos tu '
                  '${r.liquida ? 'pago' : 'anticipo'}. '
                  'Ahí verás el avance de tu mueble y tu estado de cuenta.\n\n'
                  '(Demostración: todavía no se crea la compra.)',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendido')),
                ],
              ),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Ver mi compra'),
          ),
          if (o.demo)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('reiniciarAnticipo-${o.citaId}'),
                onPressed: () => DemoAnticipos.reiniciar(o.citaId),
                child: const Text('Reiniciar demostración'),
              ),
            ),
        ],
      ),
    );
  }
}
