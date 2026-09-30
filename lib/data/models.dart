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
      );

  /// Todavía puede pasar algo (no realizada ni cancelada).
  bool get vigente => estado.clave != 'realizada' && estado.clave != 'cancelada';
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
  });

  final String id;
  final String? codigo;
  final String? mueble;
  final bool tienePdf;
  final num? precio;
  final bool comprado;
  final Marca marca;

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        id: _s(j['id']),
        codigo: _sn(j['codigo']),
        mueble: _sn(j['mueble']),
        tienePdf: j['tienePdf'] == true,
        precio: _n(j['precio']),
        comprado: j['comprado'] == true,
        marca: Marca.fromJson(_mapa(j['marca'])),
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
  });

  final String clave;
  final String titulo;
  final String descripcion;
  final Situacion situacion;
  final String? desde; // ISO o null

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
  });

  final String id;
  final String? codigo;
  final String? mueble;
  final LineaTiempo lineaTiempo;
  final Instalacion? instalacion;
  final Pagos pagos;
  final Marca marca;

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
        id: _s(j['id']),
        codigo: _sn(j['codigo']),
        mueble: _sn(j['mueble']),
        lineaTiempo: LineaTiempo.fromJson(_mapa(j['lineaTiempo'])),
        instalacion: Instalacion.fromJsonOrNull(j['instalacion']),
        pagos: Pagos.fromJson(_mapa(j['pagos'])),
        marca: Marca.fromJson(_mapa(j['marca'])),
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
  });

  final String? nombre;
  final Contacto contacto;
  final List<Cita> citas;
  final List<Cotizacion> cotizaciones;
  final List<Compra> compras;

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
