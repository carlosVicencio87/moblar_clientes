import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';
import 'widgets/detalle_pago.dart';

/// Estado de cuenta de UNA compra (decisión de Carlos, 2026-10-02): cada
/// pago queda ligado a su mueble, aunque el cliente tenga varios proyectos.
class EstadoCuentaCompra extends StatelessWidget {
  const EstadoCuentaCompra({super.key, required this.cuenta});

  final CuentaCompra cuenta;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final liquidado = c.saldo <= 0;
    return Card(
      key: const Key('estadoCuentaCompra'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: MoblarColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Estado de cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              liquidado ? 'Liquidado' : 'Saldo pendiente',
              style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
            ),
            Text(
              dinero(c.saldo),
              key: const Key('saldoPendiente'),
              style: TextStyle(
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: liquidado ? const Color(0xFF065F46) : MoblarColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: c.avance,
                minHeight: 8,
                backgroundColor: MoblarColors.primaryTint,
                color: liquidado ? MoblarColors.success : MoblarColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (c.conFactura) ...[
              _Renglon('Subtotal', dinero(c.subtotal)),
              _Renglon('IVA (16%)', dinero(c.iva)),
            ],
            _Renglon(c.conFactura ? 'Total con IVA' : 'Total', dinero(c.total), fuerte: true),
            _Renglon('Pagado', dinero(c.pagado)),
            if (c.visitaAbonada != null)
              _Renglon(
                'Incluye costo de la visita',
                dinero(c.visitaAbonada!),
                clave: const Key('visitaAbonada'),
                sutil: true,
              ),
            _Renglon('Saldo', dinero(c.saldo), fuerte: true),
            if (c.enRevision > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${dinero(c.enRevision)} en revisión: se sumará cuando lo validemos.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ],
            if (c.pagos.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'PAGOS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: MoblarColors.textMuted,
                ),
              ),
              for (var i = 0; i < c.pagos.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _Pago(p: c.pagos[i], indice: i),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Línea compacta para la tarjeta de la compra en la lista.
class SaldoCompra extends StatelessWidget {
  const SaldoCompra({super.key, required this.cuenta});

  final CuentaCompra cuenta;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        key: const Key('saldoCompra'),
        c.saldo <= 0
            ? TextSpan(
                text: 'Liquidado · ${dinero(c.total)}',
                style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w600),
              )
            : TextSpan(
                children: [
                  const TextSpan(text: 'Saldo '),
                  TextSpan(
                    text: dinero(c.saldo),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: MoblarColors.textPrimary),
                  ),
                  TextSpan(text: ' de ${dinero(c.total)}'),
                ],
                style: const TextStyle(color: MoblarColors.textSecondary),
              ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.fuerte = false, this.sutil = false, this.clave});

  final String etiqueta;
  final String valor;
  final bool fuerte;
  final bool sutil;
  final Key? clave;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: sutil ? 13 : 14,
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
      color: fuerte
          ? MoblarColors.textPrimary
          : sutil
              ? MoblarColors.textMuted
              : MoblarColors.textSecondary,
    );
    return Padding(
      key: clave,
      padding: EdgeInsets.only(top: 4, left: sutil ? 12 : 0),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo),
        ],
      ),
    );
  }
}

class _Pago extends StatelessWidget {
  const _Pago({required this.p, required this.indice});

  final PagoCliente p;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFechaCalendario(p.fecha) ?? parseFecha(p.fecha);
    final linea2 = [
      if (fecha != null) fechaCorta(fecha),
      ?p.metodo,
    ].join(' · ');
    return InkWell(
      key: Key('pago-$indice'),
      onTap: () => mostrarDetallePago(context, p),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.concepto, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (linea2.isNotEmpty)
                  Text(linea2, style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
                if (p.visitaIncluida != null)
                  Text(
                    'Incluye costo de la visita (${dinero(p.visitaIncluida!)})',
                    style: const TextStyle(fontSize: 12, color: MoblarColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dinero(p.monto),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.validado ? MoblarColors.textPrimary : MoblarColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              p.validado
                  ? const EstadoChip(texto: 'Validado', color: Color(0xFF065F46), fondo: Color(0xFFD1FAE5))
                  : const EstadoChip(texto: 'En revisión', color: Color(0xFF92400E), fondo: MoblarColors.amberSoft),
            ],
          ),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right, color: MoblarColors.textMuted),
          ),
        ],
      ),
      ),
    );
  }
}
