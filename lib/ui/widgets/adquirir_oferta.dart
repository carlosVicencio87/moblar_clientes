import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';
import 'pago_visita.dart' show AvisoDemo, EfectivoPinPage, TransferenciaPagoPage;

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
// Los montos vienen del servidor (clienteOfertaVisita.ts). Nada se guarda:
// el resultado vive en memoria (DemoAnticipos) mientras la app está abierta.
// ---------------------------------------------------------------------------

class ResultadoAnticipo {
  const ResultadoAnticipo({
    required this.metodo,
    required this.monto,
    required this.fecha,
    this.arquitecto,
  });

  /// "efectivo" | "transferencia" | "tarjeta"
  final String metodo;
  final num monto;
  final DateTime fecha;

  /// Quién confirmó con su PIN (efectivo).
  final String? arquitecto;

  bool get conTarjeta => metodo == 'tarjeta';

  String get metodoLegible => switch (metodo) {
        'efectivo' => 'Efectivo',
        'transferencia' => 'Transferencia',
        _ => 'Tarjeta (Clip)',
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

String muebleDe(OfertaVisita o) => o.muebles.isEmpty ? 'tu mueble' : o.muebles.join(', ');

/// Pantalla "Inicia tu proyecto": por qué el anticipo, cuánto y cómo pagarlo.
class AdquirirOfertaPage extends StatelessWidget {
  const AdquirirOfertaPage({super.key, required this.oferta});

  final OfertaVisita oferta;

  Future<void> _abrir(BuildContext context, Widget pagina) async {
    final listo = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => pagina),
    );
    if (listo == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final pct = o.anticipoPct.round();
    void registrar(String metodo, num monto, {String? arquitecto}) => DemoAnticipos.registrar(
          o.citaId,
          ResultadoAnticipo(metodo: metodo, monto: monto, fecha: DateTime.now(), arquitecto: arquitecto),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Resumen(
            clave: const Key('resumenContado'),
            titulo: 'De contado (efectivo o transferencia)',
            precio: o.precioContado,
            anticipo: o.anticipoContado,
            pct: pct,
            destacado: true,
          ),
          const SizedBox(height: 8),
          _Resumen(
            clave: const Key('resumenTarjeta'),
            titulo: 'Con tarjeta, en un solo pago',
            precio: o.precioTarjeta,
            anticipo: o.anticipoTarjeta,
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
            titulo: 'Efectivo · ${dinero(o.anticipoContado)}',
            texto: 'Se lo entregas a tu arquitecto y él lo confirma con su PIN en tu pantalla.',
            onTap: () => _abrir(
              context,
              EfectivoPinPage(
                titulo: 'Anticipo en efectivo',
                monto: o.anticipoContado,
                arquitecto: o.arquitecto,
                demo: o.demo,
                onConfirmado: () => registrar('efectivo', o.anticipoContado, arquitecto: o.arquitecto),
              ),
            ),
          ),
          if (o.transferencia != null)
            _Opcion(
              clave: const Key('anticipoTransferencia'),
              icono: Icons.account_balance_outlined,
              titulo: 'Transferencia · ${dinero(o.anticipoContado)}',
              texto: 'Te damos los datos de la cuenta y subes tu comprobante.',
              onTap: () => _abrir(
                context,
                TransferenciaPagoPage(
                  titulo: 'Anticipo por transferencia',
                  monto: o.anticipoContado,
                  datos: o.transferencia!,
                  demo: o.demo,
                  paraQue: 'del anticipo de tu mueble',
                  onEnviado: (_) => registrar('transferencia', o.anticipoContado),
                ),
              ),
            ),
          _Opcion(
            clave: const Key('anticipoTarjeta'),
            icono: Icons.credit_card,
            titulo: 'Tarjeta · ${dinero(o.anticipoTarjeta)}',
            texto: 'Débito o crédito con Clip, en un solo pago. Aplica el precio con tarjeta '
                '(incluye la comisión de Clip).',
            onTap: () => _abrir(
              context,
              _TarjetaClipPage(
                oferta: o,
                onPagado: () => registrar('tarjeta', o.anticipoTarjeta),
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
    this.destacado = false,
  });

  final Key clave;
  final String titulo;
  final num precio;
  final num anticipo;
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
          _Fila('Anticipo ($pct%)', dinero(anticipo), color: color, fuerte: true),
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

/// Tarjeta con Clip. En la demo solo explica y simula: el link real (por
/// cobro, con el monto exacto) se habilita cuando lo aprueben.
class _TarjetaClipPage extends StatelessWidget {
  const _TarjetaClipPage({required this.oferta, required this.onPagado});

  final OfertaVisita oferta;
  final VoidCallback onPagado;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    return Scaffold(
      appBar: AppBar(title: const Text('Anticipo con tarjeta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (o.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          Card(
            key: const Key('detalleTarjeta'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Pagarás tu anticipo de', style: TextStyle(color: MoblarColors.textMuted)),
                  Text(
                    dinero(o.anticipoTarjeta),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: MoblarColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Dato(
                    icono: Icons.lock_outline,
                    texto: 'En la página segura de Clip, con tarjeta de débito o crédito.',
                  ),
                  const Dato(
                    icono: Icons.looks_one_outlined,
                    texto: 'El anticipo se paga en una sola exhibición.',
                  ),
                  Dato(
                    icono: Icons.info_outline,
                    texto: 'Con tarjeta aplica el precio con tarjeta (${dinero(o.precioTarjeta)}), '
                        'que incluye la comisión de Clip. De contado pagarías ${dinero(o.precioContado)}.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('pagarConClip'),
            onPressed: () {
              onPagado();
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

/// Bloque "Tu compra" en la tarjeta de la oferta, ya con el anticipo.
class ResumenCompraOferta extends StatelessWidget {
  const ResumenCompraOferta({super.key, required this.oferta, required this.resultado});

  final OfertaVisita oferta;
  final ResultadoAnticipo resultado;

  @override
  Widget build(BuildContext context) {
    final o = oferta;
    final r = resultado;
    final total = r.conTarjeta ? o.precioTarjeta : o.precioContado;
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
          Dato(
            icono: Icons.sell_outlined,
            texto: r.conTarjeta
                ? 'Precio con tarjeta: ${dinero(total)}'
                : 'Precio de contado: ${dinero(total)}',
          ),
          Dato(
            icono: Icons.payments_outlined,
            texto: 'Anticipo: ${dinero(r.monto)} · ${r.metodoLegible} · $estado',
          ),
          Dato(icono: Icons.account_balance_wallet_outlined, texto: 'Saldo: ${dinero(total - r.monto)}'),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: Key('verCompraOferta-${o.citaId}'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Tu compra'),
                content: const Text(
                  'Tu compra aparecerá en «Mi compra» en cuanto validemos tu anticipo. '
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
