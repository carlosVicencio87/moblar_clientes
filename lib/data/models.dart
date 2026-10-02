/// Modelos de lo que devuelve GET /api/cliente/inicio.
///
/// ESPEJO de los DTO de src/lib/repositories/clientePortal.ts del ERP. El
/// servidor ya decide qué ve el cliente (etapas traducidas, montos apagados,
/// nada interno); aquí solo se lee. Todo campo es tolerante a null para que
/// un cambio menor del servidor no tumbe la app.
library;

String _s(Object? v) => v is String ? v : '';
String? _sn(Object? v) => v is String && v.isNotEmpty ? v : null;
num? _n(Object? v) => v is num ? v : null;
List<Map<String, dynamic>> _lista(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
Map<String, dynamic> _mapa(Object? v) =>
    v is Map<String, dynamic> ? v : const {};

class Marca {
  const Marca({required this.clave, required this.nombre, this.logo});

  final String clave;
  final String nombre;

  /// Nombre de archivo del logo ("logo-voreal.jpeg"); la app trae los mismos.
  final String? logo;

  static const _logosIncluidos = {
    'logo-moblar.png',
    'logo-voreal.jpeg',
    'logo-osmon.jpeg',
    'logo-mmd.png',
  };

  /// Ruta del asset. Si el servidor manda una marca que esta versión de la
  /// app no conoce, se usa el logo de Moblar (marca central de la app).
  String get asset => 'assets/brand/${_logosIncluidos.contains(logo) ? logo : 'logo-moblar.png'}';

  factory Marca.fromJson(Map<String, dynamic> j) => Marca(
        clave: _s(j['clave']).isEmpty ? 'moblar' : _s(j['clave']),
        nombre: _s(j['nombre']).isEmpty ? 'MOBLAR' : _s(j['nombre']),
        logo: _sn(j['logo']),
      );

  static const moblar = Marca(clave: 'moblar', nombre: 'MOBLAR', logo: 'logo-moblar.png');
}

class EstadoCita {
  const EstadoCita({required this.clave, required this.titulo});

  /// por_confirmar | confirmada | en_camino | en_visita | realizada | cancelada
  final String clave;
  final String titulo;

  factory EstadoCita.fromJson(Map<String, dynamic> j) => EstadoCita(
        clave: _s(j['clave']),
        titulo: _s(j['titulo']),
      );
}

class Cita {
  const Cita({
    required this.id,
    required this.fecha,
    required this.horario,
    required this.estado,
    required this.arquitecto,
    required this.muebles,
    required this.costoVisita,
    required this.marca,
    this.arquitectoFoto,
    this.arquitectoHabilidades = const [],
    this.arquitectoTelefono,
    this.agendoPor,
    this.direccion,
    this.mapsUrl,
    this.pagoVisita,
  });

  final String id;
  final String fecha; // ISO
  final String? horario;
  final EstadoCita estado;
  final String? arquitecto;

  /// URL firmada temporal (vence en ~1 h); se pide de nuevo al refrescar.
  /// Solo llega en citas vigentes.
  final String? arquitectoFoto;

  /// Estrellas solo con datos reales; vacío en canceladas o servidor viejo.
  final List<Habilidad> arquitectoHabilidades;

  /// 10 dígitos; solo en citas vigentes o realizadas.
  final String? arquitectoTelefono;

  /// Quién agendó la cita en atención a clientes.
  final String? agendoPor;
  final String? direccion;
  final String? mapsUrl;
  final List<String> muebles;
  final num? costoVisita;
  final Marca marca;

  /// Pago de la visita; null = la sección no se muestra (por ahora solo
  /// llega en el deployment de prueba, modo demostración).
  final PagoVisita? pagoVisita;

  factory Cita.fromJson(Map<String, dynamic> j) => Cita(
        id: _s(j['id']),
        fecha: _s(j['fecha']),
        horario: _sn(j['horario']),
        estado: EstadoCita.fromJson(_mapa(j['estado'])),
        arquitecto: _sn(j['arquitecto']),
        arquitectoFoto: _sn(j['arquitectoFoto']),
        arquitectoHabilidades: _lista(j['arquitectoHabilidades']).map(Habilidad.fromJson).toList(),
        arquitectoTelefono: _sn(j['arquitectoTelefono']),
        agendoPor: _sn(j['agendoPor']),
        direccion: _sn(j['direccion']),
        mapsUrl: _sn(j['mapsUrl']),
        muebles: j['muebles'] is List
            ? (j['muebles'] as List).whereType<String>().toList()
            : const [],
        costoVisita: _n(j['costoVisita']),
        marca: Marca.fromJson(_mapa(j['marca'])),
        pagoVisita: j['pagoVisita'] is Map<String, dynamic>
            ? PagoVisita.fromJson(j['pagoVisita'] as Map<String, dynamic>)
            : null,
      );

  /// Todavía puede pasar algo (no realizada ni cancelada).
  bool get vigente => estado.clave != 'realizada' && estado.clave != 'cancelada';
}

/// Pago de la visita (clientePagoVisita.ts del ERP). Monto fijo; solo
/// transferencia o efectivo.
class PagoVisita {
  const PagoVisita({
    required this.demo,
    required this.monto,
    required this.estado,
    required this.promesaRegistrada,
    required this.metodos,
    this.transferencia,
  });

  /// Modo demostración: nada se guarda todavía.
  final bool demo;
  final num monto;

  /// pendiente (por ahora el servidor no manda otro).
  final String estado;

  /// Contact center registró la promesa de pago al agendar.
  final bool promesaRegistrada;

  /// "transferencia" | "efectivo" (los que el servidor permite).
  final List<String> metodos;
  final DatosTransferencia? transferencia;

  bool get aceptaTransferencia => metodos.contains('transferencia') && transferencia != null;
  bool get aceptaEfectivo => metodos.contains('efectivo');

  factory PagoVisita.fromJson(Map<String, dynamic> j) => PagoVisita(
        demo: j['demo'] == true,
        monto: _n(j['monto']) ?? 0,
        estado: _s(j['estado']).isEmpty ? 'pendiente' : _s(j['estado']),
        promesaRegistrada: j['promesaRegistrada'] == true,
        metodos: j['metodos'] is List
            ? (j['metodos'] as List).whereType<String>().toList()
            : const [],
        transferencia: j['transferencia'] is Map<String, dynamic>
            ? DatosTransferencia.fromJson(j['transferencia'] as Map<String, dynamic>)
            : null,
      );
}

/// Oferta de la visita (clienteOfertaVisita.ts del ERP). El arquitecto captura
/// el precio de contado; el servidor calcula el precio de lista (18 MSI en
/// Clip) con la única fórmula aprobada. Aquí solo se lee: nunca se recalcula.
/// Es una cotización comercial temprana: va en la pestaña Cotizaciones.
class OfertaVisita {
  const OfertaVisita({
    this.citaId = '',
    this.fechaVisita = '',
    this.muebles = const [],
    this.marca = Marca.moblar,
    required this.demo,
    required this.precioLista,
    required this.mensualidad,
    required this.meses,
    required this.descuento,
    required this.descuentoPct,
    required this.precioContado,
    required this.emitida,
    required this.vigenteHasta,
    required this.vigente,
    this.imagenDiseno,
    this.arquitecto,
    this.incluye = const [],
  });

  /// Cita de la que salió (id de appointments).
  final String citaId;

  /// Fecha de la visita (ISO).
  final String fechaVisita;
  final List<String> muebles;
  final Marca marca;
  final bool demo;
  final num precioLista;
  final num mensualidad;
  final int meses;
  final num descuento;
  final num descuentoPct;
  final num precioContado;

  /// URL firmada temporal de la foto del diseño; null en la demo.
  final String? imagenDiseno;
  final String? arquitecto;
  final String emitida;
  final String vigenteHasta;
  final bool vigente;
  final List<String> incluye;

  /// Solo se muestra si el servidor mandó los tres precios.
  bool get completa => precioLista > 0 && precioContado > 0 && meses > 0;

  factory OfertaVisita.fromJson(Map<String, dynamic> j) => OfertaVisita(
        citaId: _s(j['citaId']),
        fechaVisita: _s(j['fechaVisita']),
        muebles: j['muebles'] is List
            ? (j['muebles'] as List).whereType<String>().toList()
            : const [],
        marca: Marca.fromJson(_mapa(j['marca'])),
        demo: j['demo'] == true,
        precioLista: _n(j['precioLista']) ?? 0,
        mensualidad: _n(j['mensualidad']) ?? 0,
        meses: (_n(j['meses']) ?? 0).toInt(),
        descuento: _n(j['descuento']) ?? 0,
        descuentoPct: _n(j['descuentoPct']) ?? 0,
        precioContado: _n(j['precioContado']) ?? 0,
        imagenDiseno: _sn(j['imagenDiseno']),
        arquitecto: _sn(j['arquitecto']),
        emitida: _s(j['emitida']),
        vigenteHasta: _s(j['vigenteHasta']),
        vigente: j['vigente'] != false,
        incluye: j['incluye'] is List
            ? (j['incluye'] as List).whereType<String>().where((t) => t.trim().isNotEmpty).toList()
            : const [],
      );
}

class DatosTransferencia {
  const DatosTransferencia({
    required this.banco,
    required this.beneficiario,
    required this.clabe,
    required this.concepto,
    this.ejemplo = false,
  });

  final String banco;
  final String beneficiario;

  /// 18 dígitos sin espacios.
  final String clabe;
  final String concepto;

  /// Datos de ejemplo (faltan los reales en el servidor).
  final bool ejemplo;

  /// "012 180 00123456789 1" → grupos 3-3-11-1 como en el estado de cuenta.
  String get clabeLegible => clabe.length == 18
      ? '${clabe.substring(0, 3)} ${clabe.substring(3, 6)} ${clabe.substring(6, 17)} ${clabe.substring(17)}'
      : clabe;

  factory DatosTransferencia.fromJson(Map<String, dynamic> j) => DatosTransferencia(
        banco: _s(j['banco']),
        beneficiario: _s(j['beneficiario']),
        clabe: _s(j['clabe']),
        concepto: _s(j['concepto']),
        ejemplo: j['ejemplo'] == true,
      );
}

/// Habilidad del arquitecto (arquitectoHabilidades.ts del ERP).
class Habilidad {
  const Habilidad({
    required this.clave,
    required this.titulo,
    required this.estrellas,
    required this.detalle,
  });

  final String clave;
  final String titulo;

  /// 0–5 en medios; null = aún sin calificaciones (nunca se inventa).
  final double? estrellas;
  final String detalle;

  factory Habilidad.fromJson(Map<String, dynamic> j) {
    final e = _n(j['estrellas'])?.toDouble();
    return Habilidad(
      clave: _s(j['clave']),
      titulo: _s(j['titulo']),
      estrellas: e?.clamp(0, 5).toDouble(),
      detalle: _s(j['detalle']),
    );
  }
}

class Cotizacion {
  const Cotizacion({
    required this.id,
    required this.codigo,
    required this.mueble,
    required this.tienePdf,
    required this.precio,
    required this.comprado,
    required this.marca,
    this.comercial,
  });

  final String id;
  final String? codigo;
  final String? mueble;
  final bool tienePdf;
  final num? precio;
  final bool comprado;
  final Marca marca;

  /// Cotización comercial (null si el servidor aún no la manda).
  final CotizacionComercial? comercial;

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        id: _s(j['id']),
        codigo: _sn(j['codigo']),
        mueble: _sn(j['mueble']),
        tienePdf: j['tienePdf'] == true,
        precio: _n(j['precio']),
        comprado: j['comprado'] == true,
        marca: Marca.fromJson(_mapa(j['marca'])),
        comercial: j['comercial'] is Map<String, dynamic>
            ? CotizacionComercial.fromJson(j['comercial'] as Map<String, dynamic>)
            : null,
      );
}

/// Cotización comercial: resumen sencillo con imagen, precio, vigencia de 15
/// días, arquitecto y qué incluye (clienteEstadoCuenta.ts del ERP).
class CotizacionComercial {
  const CotizacionComercial({
    this.imagenDiseno,
    this.precio,
    this.conIva = false,
    this.arquitecto,
    required this.emitida,
    required this.vigenteHasta,
    required this.vigente,
    this.incluye = const [],
  });

  /// URL firmada temporal (≈1 h).
  final String? imagenDiseno;
  final num? precio;
  final bool conIva;
  final String? arquitecto;
  final String emitida;
  final String vigenteHasta;
  final bool vigente;
  final List<String> incluye;

  factory CotizacionComercial.fromJson(Map<String, dynamic> j) => CotizacionComercial(
        imagenDiseno: _sn(j['imagenDiseno']),
        precio: _n(j['precio']),
        conIva: j['conIva'] == true,
        arquitecto: _sn(j['arquitecto']),
        emitida: _s(j['emitida']),
        vigenteHasta: _s(j['vigenteHasta']),
        vigente: j['vigente'] != false,
        incluye: j['incluye'] is List
            ? (j['incluye'] as List).whereType<String>().where((t) => t.trim().isNotEmpty).toList()
            : const [],
      );
}

// ---------------------------------------------------------------------------
// Estado de cuenta de UNA compra (cuentaDeCompra en clienteEstadoCuenta.ts)
// ---------------------------------------------------------------------------

class PagoCliente {
  const PagoCliente({
    this.id,
    required this.fecha,
    required this.monto,
    required this.concepto,
    this.metodo,
    required this.validado,
    this.visitaIncluida,
    this.referencia,
    this.tieneComprobante = false,
  });

  /// Para pedir el comprobante (URL firmada aparte).
  final String? id;

  /// "2026-09-01" (fecha del pago).
  final String fecha;

  /// Lo que se le acredita al cliente (incluye la visita si aplica).
  final num monto;
  final String concepto;
  final String? metodo;

  /// false = Pagos todavía lo revisa (no suma al pagado).
  final bool validado;

  /// Parte del monto que corresponde al costo de la visita.
  final num? visitaIncluida;

  /// Número de referencia de la transferencia o depósito.
  final String? referencia;

  /// Hay foto o PDF del comprobante.
  final bool tieneComprobante;

  factory PagoCliente.fromJson(Map<String, dynamic> j) => PagoCliente(
        id: _sn(j['id']),
        fecha: _s(j['fecha']),
        monto: _n(j['monto']) ?? 0,
        concepto: _s(j['concepto']).isEmpty ? 'Pago' : _s(j['concepto']),
        metodo: _sn(j['metodo']),
        validado: j['estado'] == 'validado',
        visitaIncluida: _n(j['visitaIncluida']),
        referencia: _sn(j['referencia']),
        tieneComprobante: j['tieneComprobante'] == true,
      );
}

class CuentaCompra {
  const CuentaCompra({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.pagado,
    required this.enRevision,
    required this.saldo,
    required this.conFactura,
    this.visitaAbonada,
    this.pagos = const [],
  });

  final num subtotal;
  final num iva;
  final num total;
  final num pagado;
  final num enRevision;
  final num saldo;
  final bool conFactura;

  /// Costo de visita abonado a esta compra (pago validado).
  final num? visitaAbonada;
  final List<PagoCliente> pagos;

  /// 0–1 para la barra (pagado / total).
  double get avance => total <= 0 ? 0 : (pagado / total).clamp(0, 1).toDouble();

  factory CuentaCompra.fromJson(Map<String, dynamic> j) => CuentaCompra(
        subtotal: _n(j['subtotal']) ?? 0,
        iva: _n(j['iva']) ?? 0,
        total: _n(j['total']) ?? 0,
        pagado: _n(j['pagado']) ?? 0,
        enRevision: _n(j['enRevision']) ?? 0,
        saldo: _n(j['saldo']) ?? 0,
        conFactura: j['conFactura'] == true,
        visitaAbonada: _n(j['visitaAbonada']),
        pagos: _lista(j['pagos']).map(PagoCliente.fromJson).toList(),
      );
}

enum Situacion { hecha, actual, pendiente }

class EtapaLineaTiempo {
  const EtapaLineaTiempo({
    required this.clave,
    required this.titulo,
    required this.descripcion,
    required this.situacion,
    required this.desde,
    int? meta,
  }) : _meta = meta;

  final String clave;
  final String titulo;
  final String descripcion;
  final Situacion situacion;
  final String? desde; // ISO o null
  final int? _meta;

  /// Porcentajes al terminar cada etapa (decisión de Carlos, 2026-10-01).
  /// Respaldo si el servidor todavía no manda `meta`.
  static const metasPorOmision = {
    'pedido': 15,
    'diseno': 35,
    'fabricacion': 70,
    'calidad': 80,
    'instalacion': 95,
    'entregado': 100,
  };

  /// Porcentaje al terminar esta etapa (se pinta junto a su bolita).
  int? get meta => _meta ?? metasPorOmision[clave];

  factory EtapaLineaTiempo.fromJson(Map<String, dynamic> j) => EtapaLineaTiempo(
        clave: _s(j['clave']),
        titulo: _s(j['titulo']),
        descripcion: _s(j['descripcion']),
        situacion: switch (j['situacion']) {
          'hecha' => Situacion.hecha,
          'actual' => Situacion.actual,
          _ => Situacion.pendiente,
        },
        desde: _sn(j['desde']),
        meta: _n(j['meta'])?.round().clamp(0, 100).toInt(),
      );
}

class LineaTiempo {
  const LineaTiempo({
    required this.etapaActual,
    required this.mensaje,
    required this.etapas,
    int? porcentaje,
  }) : _porcentaje = porcentaje;

  final int etapaActual;
  final String mensaje;
  final List<EtapaLineaTiempo> etapas;
  final int? _porcentaje;

  /// Avance 0–100 que calcula el ERP (tramos por estado + días en el
  /// estado). Si el servidor aún no lo manda, se estima por etapas.
  int get porcentaje {
    final p = _porcentaje;
    if (p != null) return p.clamp(0, 100).toInt();
    if (etapas.isEmpty) return 0;
    if (entregado) return 100;
    final hechas = etapas.where((e) => e.situacion == Situacion.hecha).length;
    return ((hechas + 0.5) / etapas.length * 100).floor().clamp(0, 99).toInt();
  }

  bool get entregado => etapas.isNotEmpty && etapas.every((e) => e.situacion == Situacion.hecha);

  /// Título de la etapa en la que está (o la última si ya se entregó).
  String get tituloActual {
    if (etapas.isEmpty) return '';
    final i = etapaActual.clamp(0, etapas.length - 1);
    return etapas[i].titulo;
  }

  factory LineaTiempo.fromJson(Map<String, dynamic> j) => LineaTiempo(
        etapaActual: _n(j['etapaActual'])?.toInt() ?? 0,
        mensaje: _s(j['mensaje']),
        etapas: _lista(j['etapas']).map(EtapaLineaTiempo.fromJson).toList(),
        porcentaje: _n(j['porcentaje'])?.round(),
      );
}

class Pagos {
  const Pagos({this.total, this.pagado, this.saldo});

  final num? total;
  final num? pagado;
  final num? saldo;

  /// El servidor manda los tres en null mientras los montos estén apagados.
  bool get visibles => total != null || pagado != null || saldo != null;

  factory Pagos.fromJson(Map<String, dynamic> j) => Pagos(
        total: _n(j['total']),
        pagado: _n(j['pagado']),
        saldo: _n(j['saldo']),
      );
}

class Instalacion {
  const Instalacion({required this.fecha, this.horario});

  final String fecha; // yyyy-mm-dd
  final String? horario;

  static Instalacion? fromJsonOrNull(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    final f = _sn(v['fecha']);
    return f == null ? null : Instalacion(fecha: f, horario: _sn(v['horario']));
  }
}

class Compra {
  const Compra({
    required this.id,
    required this.codigo,
    required this.mueble,
    required this.lineaTiempo,
    required this.instalacion,
    required this.pagos,
    required this.marca,
    this.cuenta,
  });

  final String id;
  final String? codigo;
  final String? mueble;
  final LineaTiempo lineaTiempo;
  final Instalacion? instalacion;
  final Pagos pagos;
  final Marca marca;

  /// Estado de cuenta de esta compra; null con montos apagados.
  final CuentaCompra? cuenta;

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
        id: _s(j['id']),
        codigo: _sn(j['codigo']),
        mueble: _sn(j['mueble']),
        lineaTiempo: LineaTiempo.fromJson(_mapa(j['lineaTiempo'])),
        instalacion: Instalacion.fromJsonOrNull(j['instalacion']),
        pagos: Pagos.fromJson(_mapa(j['pagos'])),
        marca: Marca.fromJson(_mapa(j['marca'])),
        cuenta: j['cuenta'] is Map<String, dynamic>
            ? CuentaCompra.fromJson(j['cuenta'] as Map<String, dynamic>)
            : null,
      );
}

class Contacto {
  const Contacto({required this.empresa, required this.telefono, required this.whatsapp});

  final String empresa;

  /// 10 dígitos nacionales.
  final String telefono;
  final String whatsapp;

  factory Contacto.fromJson(Map<String, dynamic> j) => Contacto(
        empresa: _s(j['empresa']).isEmpty ? 'MOBLAR' : _s(j['empresa']),
        telefono: _s(j['telefono']),
        whatsapp: _s(j['whatsapp']),
      );
}

class Inicio {
  const Inicio({
    required this.nombre,
    required this.contacto,
    required this.citas,
    required this.cotizaciones,
    required this.compras,
    this.ofertasVisita = const [],
  });

  final String? nombre;
  final Contacto contacto;
  final List<Cita> citas;
  final List<Cotizacion> cotizaciones;
  final List<Compra> compras;

  /// Ofertas que dejó el arquitecto al terminar cada visita (solo las
  /// completas). Por ahora solo llegan en el deployment de prueba.
  final List<OfertaVisita> ofertasVisita;

  /// Compras en curso primero (lo que el cliente quiere ver), luego las
  /// entregadas; dentro de cada grupo, en el orden del servidor.
  List<Compra> get comprasOrdenadas => [
        ...compras.where((c) => !c.lineaTiempo.entregado),
        ...compras.where((c) => c.lineaTiempo.entregado),
      ];

  factory Inicio.fromJson(Map<String, dynamic> j) => Inicio(
        nombre: _sn(_mapa(j['cliente'])['nombre']),
        contacto: Contacto.fromJson(_mapa(j['contacto'])),
        citas: _lista(j['citas']).map(Cita.fromJson).toList(),
        cotizaciones: _lista(j['cotizaciones']).map(Cotizacion.fromJson).toList(),
        compras: _lista(j['compras']).map(Compra.fromJson).toList(),
        ofertasVisita: _lista(j['ofertasVisita'])
            .map(OfertaVisita.fromJson)
            .where((o) => o.completa)
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Detalle del mueble: GET /api/cliente/proyectos/:id/detalle
// (espejo de clienteProyectoDetalle.ts del ERP)
// ---------------------------------------------------------------------------

class Tono {
  const Tono({required this.nombre, this.hex});

  final String nombre;

  /// "#RRGGBB" o null si el catálogo no trae muestra.
  final String? hex;

  factory Tono.fromJson(Map<String, dynamic> j) =>
      Tono(nombre: _s(j['nombre']), hex: _sn(j['hex']));
}

class PiezaPedido {
  const PiezaPedido({
    required this.nombre,
    required this.cantidad,
    this.medidas,
    this.fondo,
    this.tono,
  });

  final String nombre;
  final int cantidad;
  final String? medidas;
  final String? fondo;
  final String? tono;

  factory PiezaPedido.fromJson(Map<String, dynamic> j) => PiezaPedido(
        nombre: _s(j['nombre']),
        cantidad: (_n(j['cantidad'])?.toInt() ?? 1).clamp(1, 9999).toInt(),
        medidas: _sn(j['medidas']),
        fondo: _sn(j['fondo']),
        tono: _sn(j['tono']),
      );
}

class DetalleProyecto {
  const DetalleProyecto({
    required this.id,
    this.mueble,
    this.imagenDiseno,
    this.medidas,
    this.piezas = const [],
    this.tonos = const [],
    this.incluye = const [],
    this.porTuCuenta = const [],
  });

  final String id;
  final String? mueble;

  /// URL firmada temporal (≈1 h) de la imagen del diseño en Moblo.
  final String? imagenDiseno;
  final String? medidas;
  final List<PiezaPedido> piezas;
  final List<Tono> tonos;
  final List<String> incluye;
  final List<String> porTuCuenta;

  bool get tieneContenido =>
      imagenDiseno != null ||
      medidas != null ||
      piezas.isNotEmpty ||
      tonos.isNotEmpty ||
      incluye.isNotEmpty ||
      porTuCuenta.isNotEmpty;

  static List<String> _textos(Object? v) =>
      v is List ? v.whereType<String>().where((t) => t.trim().isNotEmpty).toList() : const [];

  factory DetalleProyecto.fromJson(Map<String, dynamic> j) => DetalleProyecto(
        id: _s(j['id']),
        mueble: _sn(j['mueble']),
        imagenDiseno: _sn(j['imagenDiseno']),
        medidas: _sn(j['medidas']),
        piezas: _lista(j['piezas']).map(PiezaPedido.fromJson).where((p) => p.nombre.isNotEmpty).toList(),
        tonos: _lista(j['tonos']).map(Tono.fromJson).where((t) => t.nombre.isNotEmpty).toList(),
        incluye: _textos(j['incluye']),
        porTuCuenta: _textos(j['porTuCuenta']),
      );
}

/// URL firmada (vence en minutos) del comprobante de un pago.
class Comprobante {
  const Comprobante({required this.url, required this.esPdf});

  final Uri url;
  final bool esPdf;
}
