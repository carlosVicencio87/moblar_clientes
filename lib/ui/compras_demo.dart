import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../util/formato.dart';
import 'widgets/adquirir_oferta.dart' show DemoAnticipos, ResultadoAnticipo, cuentaDemo, metaFabricacionDe, muebleDe;
import 'widgets/oferta_visita.dart' show indiceOpcionFormal;

// ---------------------------------------------------------------------------
// Compras de la DEMOSTRACIÓN (Carlos, 2026-10-09): una oferta adquirida en la
// app aparece en "Mi compra" igual que una compra real (línea de tiempo,
// estado de cuenta, abonar), marcada como demostración. Nada se guarda en el
// ERP. Y a una compra real del Preview se le suman, a la vista, los abonos de
// demostración (efectivo, transferencia o tarjeta aún no registrada).
// ---------------------------------------------------------------------------

// Con el anticipo todavía no empieza nada (Carlos, 2026-10-26): primero el
// arquitecto termina la cotización formal y el cliente la firma. Con la firma
// y el 50 % cubierto empieza el proyecto.
const _etapas = [
  ('cotizacion', 'Cotización formal', 'Tu arquitecto prepara tu cotización formal; tú la revisas y la firmas.', 10),
  ('diseno', 'Diseño técnico', 'Estamos preparando los planos de fabricación de tu mueble.', 35),
  ('fabricacion', 'Fabricación', 'Tu mueble se está fabricando en nuestro taller.', 70),
  ('calidad', 'Control de calidad', 'Revisamos cada pieza antes de enviarla.', 80),
  ('instalacion', 'Instalación', 'Estamos preparando la instalación de tu mueble.', 95),
  ('entregado', 'Entregado', '¡Tu mueble está instalado! Gracias por tu confianza.', 100),
];

/// La compra de la demo para una oferta adquirida. [formal] es su cotización
/// formal en el ERP, si el arquitecto ya terminó el levantamiento.
Compra compraDemo(OfertaVisita o, ResultadoAnticipo r, List<AbonoDemo> abonos, {Cotizacion? formal}) {
  final cuenta = cuentaDemo(o, r, abonos);
  final meta = metaFabricacionDe(o, r);
  // Apartado: el anticipo se cubre cuando lo pagado (validado) llega al 50%.
  final apartadoSinCubrir = meta != null && cuenta.pagado < meta;
  // En la demo una transferencia queda en revisión.
  final pagoValidado = r.metodo != 'transferencia';
  final lista = formal?.tienePdf ?? false;
  final firmada = lista && (formal?.firmada ?? false);
  final comienza = pagoValidado && firmada && !apartadoSinCubrir;
  final falta = apartadoSinCubrir ? dinero(((meta - cuenta.pagado) * 100).round() / 100) : '';
  final String mensaje;
  if (!pagoValidado) {
    mensaje = 'Estamos validando tu pago. Te avisaremos en cuanto quede confirmado.';
  } else if (!lista) {
    mensaje = 'Recibimos tu pago. Tu arquitecto está preparando tu cotización formal; '
        'te avisaremos en cuanto esté lista.';
  } else if (!firmada) {
    mensaje = 'Tu cotización formal está lista. Empezaremos tu proyecto en cuanto la firmes '
        '(en Cotizaciones) y confirmes que todo está en orden.';
  } else if (apartadoSinCubrir) {
    mensaje = 'Firmaste tu cotización. Proyecto apartado: te faltan $falta para iniciar '
        'la fabricación (${o.anticipoPct.round()}%). Tu precio queda respetado.';
  } else {
    mensaje = 'Firmaste tu cotización y tu anticipo está cubierto. ¡Comenzamos con tu proyecto!';
  }
  final actual = comienza ? 1 : 0;
  return Compra(
    id: 'demo-${o.clave}',
    codigo: 'DEMO',
    mueble: (muebleDe(o) == 'tu mueble' ? 'Mueble a la medida' : muebleDe(o)) +
        (o.opcion >= 1 ? ' · Opción ${o.opcion}' : ''),
    demoCitaId: o.citaId,
    demoClave: o.clave,
    lineaTiempo: LineaTiempo(
      etapaActual: actual,
      mensaje: mensaje,
      porcentaje: comienza ? _etapas[0].$4 : 0,
      etapas: [
        for (var i = 0; i < _etapas.length; i++)
          EtapaLineaTiempo(
            clave: _etapas[i].$1,
            titulo: _etapas[i].$2,
            descripcion: _etapas[i].$3,
            situacion: i < actual
                ? Situacion.hecha
                : i == actual
                    ? Situacion.actual
                    : Situacion.pendiente,
            desde: i == 0
                ? r.fecha.toIso8601String()
                : i == actual
                    ? (formal?.firmadaEl ?? r.fecha.toIso8601String())
                    : null,
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
    metaFabricacion: meta,
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

/// Cotizaciones formales de la cita para una opción: la que trae ese número,
/// o (oferta de una sola opción) la que haya.
List<Cotizacion> _formalesDe(Inicio datos, OfertaVisita base, int opcion) {
  final deCita = [for (final c in datos.cotizaciones) if (c.citaId == base.citaId) c];
  final exactas = [for (final c in deCita) if (c.opcion == opcion) c];
  if (exactas.isNotEmpty) return exactas;
  final sinOpcion = [for (final c in deCita) if (c.opcion == null) c];
  return base.opciones.length < 2 ? sinOpcion : const [];
}

/// ¿Alguna de estas opciones ya es un proyecto en marcha del ERP (sale en
/// `compras`)? Entonces manda esa tarjeta y no la de la compra de la app.
bool _yaEnErp(Inicio datos, OfertaVisita base, CompraOferta k) {
  final proyectos = {for (final c in datos.compras) c.id};
  for (final f in datos.cotizaciones) {
    if (f.citaId != base.citaId || !proyectos.contains(f.id)) continue;
    if (f.opcion == null || k.opciones.contains(f.opcion)) return true;
  }
  return false;
}

/// "Mi compra" de una compra REAL hecha en la app (2026-10-29): qué adquirió,
/// cuánto pagó, en qué va (pago → cotización formal → firma → anticipo) y su
/// estado de cuenta. Cuando el taller programa el proyecto, el ERP lo manda en
/// `compras` y esta tarjeta deja su lugar a la del proyecto.
Compra compraDeLaApp(Inicio datos, OfertaVisita base, CompraOferta k) {
  final opciones = [...k.opciones]..sort();
  final formales = [for (final n in opciones) _formalesDe(datos, base, n)];
  final lista = formales.every((l) => l.any((f) => f.tienePdf));
  final firmada = lista && formales.every((l) => l.any((f) => f.tienePdf && f.firmada));
  final validada = k.validada;
  final cubre = k.cubreAnticipo;
  final meta = k.modalidad == 'apartado' ? ((k.total / 2) * 100).ceil() / 100 : null;
  final falta = meta == null ? 0 : ((meta - (validada ? k.pago : 0)) * 100).round() / 100;
  final String mensaje;
  if (k.faltaComprobante) {
    mensaje = 'Falta tu comprobante: súbelo en Cotizaciones para que validemos tu transferencia.';
  } else if (!validada) {
    mensaje = 'Estamos validando tu pago. Te avisaremos en cuanto quede confirmado.';
  } else if (!lista) {
    mensaje = 'Recibimos tu pago. Tu arquitecto está preparando tu cotización formal; '
        'te avisaremos en cuanto esté lista.';
  } else if (!firmada) {
    mensaje = 'Tu cotización formal está lista. Fírmala en Cotizaciones para que empecemos tu proyecto.';
  } else if (!cubre) {
    mensaje = 'Firmaste tu cotización. Proyecto apartado: te faltan ${dinero(falta)} para iniciar la fabricación (50 %).';
  } else {
    mensaje = 'Firmaste tu cotización y tu anticipo está cubierto. En cuanto el taller programe tu proyecto, '
        'verás aquí cada etapa.';
  }
  final listo = validada && firmada && cubre;
  final codigo = formales.expand((l) => l).map((f) => f.codigo).whereType<String>().firstOrNull;
  final nombre = muebleDe(base) == 'tu mueble' ? 'Mueble a la medida' : muebleDe(base);
  final cuales = base.opciones.length < 2
      ? ''
      : (opciones.length > 1 ? ' · Opciones ${opciones.join(' y ')}' : ' · Opción ${opciones.first}');
  final pagado = validada ? k.pago : 0;
  final enRevision = validada ? 0 : k.pago;
  final saldo = ((k.total - pagado) * 100).round() / 100;
  final subtotal = k.factura ? ((k.total / 1.16) * 100).round() / 100 : k.total;
  return Compra(
    id: 'app-${k.id}',
    codigo: codigo,
    mueble: '$nombre$cuales',
    compraAppId: k.id,
    lineaTiempo: LineaTiempo(
      etapaActual: 0,
      mensaje: mensaje,
      porcentaje: listo ? _etapas[0].$4 : 0,
      etapas: [
        for (var i = 0; i < _etapas.length; i++)
          EtapaLineaTiempo(
            clave: _etapas[i].$1,
            titulo: _etapas[i].$2,
            descripcion: _etapas[i].$3,
            situacion: i == 0 ? Situacion.actual : Situacion.pendiente,
            desde: i == 0 ? k.fecha : null,
            meta: _etapas[i].$4,
          ),
      ],
    ),
    instalacion: null,
    pagos: Pagos(total: k.total, pagado: pagado, saldo: saldo < 0 ? 0 : saldo),
    marca: base.marca,
    cuenta: CuentaCompra(
      subtotal: subtotal,
      iva: ((k.total - subtotal) * 100).round() / 100,
      total: k.total,
      pagado: pagado,
      enRevision: enRevision,
      saldo: saldo < 0 ? 0 : saldo,
      conFactura: k.factura,
      pagos: [
        PagoCliente(
          id: k.id,
          fecha: k.fecha,
          monto: k.pago,
          concepto: k.resumen.split(' · ').first,
          metodo: k.metodo,
          validado: validada,
        ),
      ],
    ),
    metaFabricacion: meta,
  );
}

/// Las compras de la app que van en "Mi compra": activas, sin el pago con
/// tarjeta que no se terminó, y solo mientras no sean un proyecto en marcha.
List<Compra> comprasDeLaApp(Inicio datos) => [
      for (final base in datos.ofertasVisita)
        if (base.compraReal)
          for (final k in base.compras)
            if (k.activa && !k.tarjetaSinTerminar && !_yaEnErp(datos, base, k)) compraDeLaApp(datos, base, k),
    ];

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
    for (final base in datos.ofertasVisita)
      for (final (i, o) in (base.opciones.isEmpty ? [base] : base.opciones).indexed)
        if (anticipos[o.clave] case final r?)
          compraDemo(
            o.variante(factura: r.factura),
            r,
            app.abonosDe(o.clave),
            formal: formalDeOpcion(datos, base, i),
          ),
  ];
  return [...comprasDeLaApp(datos), ...demo, ...reales];
}

/// La cotización formal de la opción [i] de la oferta [base]: la de su cita,
/// si corresponde a esa opción (o si no se puede saber a cuál corresponde).
Cotizacion? formalDeOpcion(Inicio datos, OfertaVisita base, int i) {
  final todas = [for (final c in datos.cotizaciones) if (c.citaId == base.citaId) c];
  if (todas.isEmpty) return null;
  final opciones = base.opciones.isEmpty ? [base] : base.opciones;
  if (opciones.length < 2) return todas.first;
  for (final f in todas) {
    if (indiceOpcionFormal(opciones, f) == i) return f;
  }
  final f = todas.first;
  return todas.length == 1 && indiceOpcionFormal(opciones, f) == null ? f : null;
}
