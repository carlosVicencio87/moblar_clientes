import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';

/// Resumen del estado de cuenta arriba de "Mi compra": saldo pendiente,
/// total y pagado de todos los muebles. Al tocarlo abre el detalle de pagos.
class TarjetaEstadoCuenta extends StatelessWidget {
  const TarjetaEstadoCuenta({super.key, required this.cuenta, this.abreDetalle = true});

  final EstadoCuenta cuenta;

  /// false dentro del propio detalle (no se abre a sí mismo).
  final bool abreDetalle;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    final liquidado = c.saldo <= 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Card(
        key: const Key('tarjetaEstadoCuenta'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: abreDetalle
              ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const EstadoCuentaPage()),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: MoblarColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tu estado de cuenta',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (abreDetalle) const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _Cifra(etiqueta: 'Pagado', valor: dinero(c.pagado))),
                    Expanded(
                      child: _Cifra(
                        etiqueta: c.conIva ? 'Total (con IVA)' : 'Total',
                        valor: dinero(c.total),
                        alinearDerecha: true,
                      ),
                    ),
                  ],
                ),
                if (c.enRevision > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${dinero(c.enRevision)} en revisión: se sumará cuando lo validemos.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor, this.alinearDerecha = false});

  final String etiqueta;
  final String valor;
  final bool alinearDerecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alinearDerecha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
        Text(
          valor,
          style: const TextStyle(fontWeight: FontWeight.w600, color: MoblarColors.textPrimary),
        ),
      ],
    );
  }
}

/// Detalle: resumen, cuánto lleva cada mueble y la lista de pagos.
/// Lee del estado para redibujarse al jalar para actualizar.
class EstadoCuentaPage extends StatelessWidget {
  const EstadoCuentaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final datos = AppScope.of(context).datos;
    final c = datos?.estadoCuenta;
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de cuenta')),
      body: datos == null || c == null
          ? const VistaVacia(
              icono: Icons.account_balance_wallet_outlined,
              titulo: 'Sin movimientos',
              texto: 'Aquí verás tus pagos cuando los registremos.',
            )
          : ListaRefrescable(
              onRefrescar: AppScope.read(context).refrescar,
              children: [
                TarjetaEstadoCuenta(cuenta: c, abreDetalle: false),
                if (c.muebles.length > 1 || c.conIva) ...[
                  const TituloSeccion('Por mueble'),
                  for (final m in c.muebles) _Mueble(m: m),
                ],
                const TituloSeccion('Pagos'),
                if (c.pagos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Todavía no hay pagos registrados.',
                      style: TextStyle(color: MoblarColors.textMuted),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < c.pagos.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          _Pago(p: c.pagos[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                BotonPreguntar(
                  key: const Key('preguntarPagos'),
                  texto: '¿Dudas sobre tus pagos?',
                  contacto: datos.contacto,
                  mensaje: mensajeContacto(
                    etiqueta: MotivoContacto.pagos,
                    nombre: datos.nombre,
                    texto: 'Tengo una duda sobre mi estado de cuenta.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Mueble extends StatelessWidget {
  const _Mueble({required this.m});

  final CuentaMueble m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.mueble ?? 'Tu mueble',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (m.codigo != null)
                Text('Pedido ${m.codigo}', style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
              const SizedBox(height: 8),
              if (m.conFactura) ...[
                _Renglon('Subtotal', dinero(m.subtotal)),
                _Renglon('IVA (16%)', dinero(m.iva)),
              ],
              _Renglon('Total', dinero(m.total), fuerte: true),
              _Renglon('Pagado', dinero(m.pagado)),
              _Renglon('Saldo', dinero(m.saldo), fuerte: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.fuerte = false});

  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
      color: fuerte ? MoblarColors.textPrimary : MoblarColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
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
  const _Pago({required this.p});

  final PagoCliente p;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFechaCalendario(p.fecha) ?? parseFecha(p.fecha);
    final linea2 = [
      if (fecha != null) fechaCorta(fecha),
      ?p.metodo,
      if (p.mueble != null) p.mueble!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
        ],
      ),
    );
  }
}
