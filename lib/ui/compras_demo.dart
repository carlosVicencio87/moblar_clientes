import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import 'widgets/adquirir_oferta.dart' show DemoAnticipos, ResultadoAnticipo, cuentaDemo, muebleDe;

// ---------------------------------------------------------------------------
// Compras de la DEMOSTRACIÓN (Carlos, 2026-10-09): una oferta adquirida en la
// app aparece en "Mi compra" igual que una compra real (línea de tiempo,
// estado de cuenta, abonar), marcada como demostración. Nada se guarda en el
// ERP. Y a una compra real del Preview se le suman, a la vista, los abonos de
// demostración (efectivo, transferencia o tarjeta aún no registrada).
// ---------------------------------------------------------------------------

const _etapas = [
  ('pedido', 'Pedido confirmado', 'Recibimos tu pedido.', 15),
  ('diseno', 'Diseño técnico', 'Estamos preparando los planos de fabricación de tu mueble.', 35),
  ('fabricacion', 'Fabricación', 'Tu mueble se está fabricando en nuestro taller.', 70),
  ('calidad', 'Control de calidad', 'Revisamos cada pieza antes de enviarla.', 80),
  ('instalacion', 'Instalación', 'Estamos preparando la instalación de tu mueble.', 95),
  ('entregado', 'Entregado', '¡Tu mueble está instalado! Gracias por tu confianza.', 100),
];

/// La compra de la demo para una oferta adquirida.
Compra compraDemo(OfertaVisita o, ResultadoAnticipo r, List<AbonoDemo> abonos) {
  final cuenta = cuentaDemo(o, r, abonos);
  final validado = r.metodo != 'transferencia';
  return Compra(
    id: 'demo-${o.citaId}',
    codigo: 'DEMO',
    mueble: muebleDe(o) == 'tu mueble' ? 'Mueble a la medida' : muebleDe(o),
    demoCitaId: o.citaId,
    lineaTiempo: LineaTiempo(
      etapaActual: 0,
      mensaje: validado ? 'Recibimos tu anticipo. ¡Comenzamos!' : 'Esperando tu anticipo para comenzar.',
      porcentaje: validado ? 5 : 0,
      etapas: [
        for (var i = 0; i < _etapas.length; i++)
          EtapaLineaTiempo(
            clave: _etapas[i].$1,
            titulo: _etapas[i].$2,
            descripcion: _etapas[i].$3,
            situacion: i == 0 ? Situacion.actual : Situacion.pendiente,
            desde: i == 0 ? r.fecha.toIso8601String() : null,
            meta: _etapas[i].$4,
          ),
      ],
    ),
    instalacion: null,
    pagos: Pagos(total: cuenta.total, pagado: cuenta.pagado, saldo: cuenta.saldo),
    marca: o.marca,
    cuenta: cuenta,
    pagoTarjeta: o.pagoTarjeta,
    abonoDemo: AbonoDemoConfig(transferencia: o.transferencia, arquitecto: o.arquitecto),
  );
}

/// Estado de cuenta real + abonos de demostración (solo a la vista).
CuentaCompra conAbonosDemo(CuentaCompra c, List<AbonoDemo> abonos) {
  if (abonos.isEmpty) return c;
  num pagado = c.pagado;
  num enRevision = c.enRevision;
  for (final a in abonos) {
    if (a.validado) {
      pagado += a.monto;
    } else {
      enRevision += a.monto;
    }
  }
  pagado = (pagado * 100).round() / 100;
  final saldo = ((c.total - pagado) * 100).round() / 100;
  return CuentaCompra(
    subtotal: c.subtotal,
    iva: c.iva,
    total: c.total,
    pagado: pagado,
    enRevision: (enRevision * 100).round() / 100,
    saldo: saldo < 0 ? 0 : saldo,
    conFactura: c.conFactura,
    visitaAbonada: c.visitaAbonada,
    pagos: [
      for (final a in abonos.reversed)
        PagoCliente(
          fecha: a.fecha.toIso8601String(),
          monto: a.monto,
          concepto: 'Abono (demostración)',
          metodo: a.metodo,
          validado: a.validado,
        ),
      ...c.pagos,
    ],
  );
}

/// Compras reales (con sus abonos de demo a la vista) + las de la demo.
List<Compra> todasLasCompras(BuildContext context, Inicio datos) {
  final app = AppScope.of(context);
  final anticipos = DemoAnticipos.resultados.value;
  final reales = [
    for (final c in datos.comprasOrdenadas)
      if (c.cuenta != null && (app.abonosDemo[c.id]?.isNotEmpty ?? false))
        Compra(
          id: c.id,
          codigo: c.codigo,
          mueble: c.mueble,
          lineaTiempo: c.lineaTiempo,
          instalacion: c.instalacion,
          pagos: c.pagos,
          marca: c.marca,
          cuenta: conAbonosDemo(c.cuenta!, app.abonosDe(c.id)),
          pagoTarjeta: c.pagoTarjeta,
          abonoDemo: c.abonoDemo,
        )
      else
        c,
  ];
  final demo = [
    for (final o in datos.ofertasVisita)
      if (anticipos[o.citaId] case final r?)
        compraDemo(o.variante(factura: r.factura), r, app.abonosDe(o.citaId)),
  ];
  return [...demo, ...reales];
}
