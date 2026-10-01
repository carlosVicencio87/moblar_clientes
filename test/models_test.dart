import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';

import 'fixtures/inicio_fixture.dart';

void main() {
  final inicio = Inicio.fromJson(jsonDecode(inicioJson) as Map<String, dynamic>);

  test('lee cliente y contacto', () {
    expect(inicio.nombre, 'Carlos Prueba');
    expect(inicio.contacto.empresa, 'MOBLAR');
    expect(inicio.contacto.telefono, '5530768296');
    expect(inicio.contacto.whatsapp, 'https://wa.me/525530768296');
  });

  test('lee citas', () {
    expect(inicio.citas, hasLength(2));
    final c = inicio.citas.first;
    expect(c.estado.clave, 'confirmada');
    expect(c.muebles, ['Cocina', 'Closet']);
    expect(c.costoVisita, isNull);
    expect(c.marca.asset, 'assets/brand/logo-moblar.png');
    expect(inicio.citas.last.arquitecto, isNull);
    expect(c.direccion, 'Av. Siempre Viva 742, CDMX');
    expect(c.mapsUrl, 'https://maps.app.goo.gl/ejemplo');
    expect(c.arquitectoFoto, isNull);
    expect(c.vigente, isTrue);
    expect(inicio.citas.last.vigente, isFalse); // realizada
    expect(inicio.citas.last.direccion, isNull); // campo ausente → null
    expect(inicio.citas.last.marca.asset, 'assets/brand/logo-voreal.jpeg');
  });

  test('marca desconocida cae al logo y nombre de Moblar', () {
    final m = inicio.cotizaciones.last.marca;
    expect(m.asset, 'assets/brand/logo-moblar.png');
    expect(m.nombre, 'MOBLAR');
  });

  test('lee cotizaciones', () {
    final q = inicio.cotizaciones.first;
    expect(q.codigo, '000135');
    expect(q.tienePdf, isTrue);
    expect(q.comprado, isTrue);
    expect(q.precio, 250000);
    expect(inicio.cotizaciones.last.tienePdf, isFalse);
  });

  test('línea de tiempo: entregado y en curso', () {
    final entregado = inicio.compras.first.lineaTiempo;
    expect(entregado.entregado, isTrue);
    expect(entregado.tituloActual, 'Entregado');

    final curso = inicio.compras.last.lineaTiempo;
    expect(curso.entregado, isFalse);
    expect(curso.tituloActual, 'Fabricación');
    expect(curso.etapas.map((e) => e.situacion), [
      Situacion.hecha,
      Situacion.hecha,
      Situacion.actual,
      Situacion.pendiente,
      Situacion.pendiente,
      Situacion.pendiente,
    ]);
  });

  test('porcentaje: el del ERP; si no llega, se estima por etapas', () {
    expect(inicio.compras.first.lineaTiempo.porcentaje, 100);
    expect(inicio.compras.last.lineaTiempo.porcentaje, 58);

    final sinPct = Map<String, dynamic>.from(
      (jsonDecode(inicioJson) as Map<String, dynamic>)['compras'][1]['lineaTiempo'] as Map,
    )..remove('porcentaje');
    // 2 hechas + la actual a la mitad, de 6 → 41.
    expect(LineaTiempo.fromJson(sinPct).porcentaje, 41);
    expect(LineaTiempo.fromJson({...sinPct, 'porcentaje': 140}).porcentaje, 100);
    expect(LineaTiempo.fromJson({...sinPct, 'porcentaje': 'x'}).porcentaje, 41);
  });

  test('habilidades del arquitecto: estrellas solo si hay datos', () {
    final hs = inicio.citas.first.arquitectoHabilidades;
    expect(hs.map((h) => h.clave), ['creatividad', 'puntualidad', 'atencion']);
    expect(hs.first.estrellas, 4.5);
    expect(hs[1].estrellas, isNull);
    // Cita sin el campo (servidor anterior): lista vacía.
    expect(inicio.citas.last.arquitectoHabilidades, isEmpty);
    expect(Habilidad.fromJson({'estrellas': 9}).estrellas, 5);
  });

  test('teléfono del arquitecto y quién agendó', () {
    expect(inicio.citas.first.arquitectoTelefono, '5512345678');
    expect(inicio.citas.first.agendoPor, 'Estela Ramírez');
    expect(inicio.citas.last.arquitectoTelefono, isNull);
    expect(inicio.citas.last.agendoPor, isNull);
  });

  test('detalle del mueble: piezas, tonos, lo que incluye', () {
    final d = DetalleProyecto.fromJson(jsonDecode(detalleJson) as Map<String, dynamic>);
    expect(d.tieneContenido, isTrue);
    expect(d.imagenDiseno, isNull);
    expect(d.medidas, '240 × 180 cm');
    expect(d.piezas.first.cantidad, 2);
    expect(d.piezas.last.medidas, isNull);
    expect(d.tonos.map((t) => t.hex), ['#8B5A2B', null]);
    expect(d.incluye, contains('Cajones'));
    expect(d.porTuCuenta, ['Chimenea']);

    final conImagen = DetalleProyecto.fromJson({'id': 'x', 'imagenDiseno': 'https://f/i.png'});
    expect(conImagen.tieneContenido, isTrue);
    final vacio = DetalleProyecto.fromJson({'id': 'x', 'piezas': 'no', 'incluye': [1, '', 'Luces']});
    expect(vacio.piezas, isEmpty);
    expect(vacio.incluye, ['Luces']);
  });

  test('meta de cada etapa: la del servidor o la de respaldo', () {
    final etapas = inicio.compras.last.lineaTiempo.etapas;
    expect(etapas.map((e) => e.meta), [15, 35, 70, 80, 95, 100]);
    final delServidor = EtapaLineaTiempo.fromJson({'clave': 'pedido', 'meta': 12});
    expect(delServidor.meta, 12);
    expect(EtapaLineaTiempo.fromJson({'clave': 'otra'}).meta, isNull);
  });

  test('cotización comercial y estado de cuenta', () {
    final q1 = inicio.cotizaciones.first.comercial!;
    expect(q1.precio, 250000);
    expect(q1.vigente, isTrue);
    expect(q1.arquitecto, 'Ana López');
    expect(q1.incluye, hasLength(4));
    expect(inicio.cotizaciones.last.comercial!.vigente, isFalse);
    expect(Cotizacion.fromJson(const {'id': 'x'}).comercial, isNull);

    final e = inicio.estadoCuenta!;
    expect(e.saldo, 150000);
    expect(e.avance, closeTo(0.4, 1e-9));
    expect(e.pagos.first.validado, isFalse);
    expect(e.pagos.last.validado, isTrue);
    expect(Inicio.fromJson(const {}).estadoCuenta, isNull);
    expect(const EstadoCuenta(total: 0, pagado: 0, enRevision: 0, saldo: 0, conIva: false).avance, 0);
  });

  test('compras en curso primero', () {
    expect(inicio.comprasOrdenadas.map((c) => c.id), ['p-fabricacion', 'p-entregado']);
  });

  test('montos apagados: pagos no visibles', () {
    expect(inicio.compras.first.pagos.visibles, isFalse);
    expect(const Pagos(total: 100).visibles, isTrue);
  });

  test('instalación opcional', () {
    expect(inicio.compras.first.instalacion!.fecha, '2026-09-04');
    expect(inicio.compras.last.instalacion, isNull);
  });

  test('JSON vacío o raro no revienta', () {
    final vacio = Inicio.fromJson(const {});
    expect(vacio.citas, isEmpty);
    expect(vacio.compras, isEmpty);
    expect(vacio.contacto.empresa, 'MOBLAR');
    final raro = Inicio.fromJson({
      'citas': [42, 'x', {'id': 'a'}],
      'compras': [
        {'id': 'b', 'lineaTiempo': {'etapas': 'no-lista'}},
      ],
    });
    expect(raro.citas, hasLength(1));
    expect(raro.citas.single.estado.clave, '');
    expect(raro.compras.single.lineaTiempo.etapas, isEmpty);
    expect(raro.compras.single.lineaTiempo.entregado, isFalse);
    expect(raro.compras.single.lineaTiempo.tituloActual, '');
  });
}
