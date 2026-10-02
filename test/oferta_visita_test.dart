import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/contacto.dart';
import 'package:moblar_clientes/ui/widgets/oferta_visita.dart';

/// Esqueleto de la oferta de la visita (paso C). Los números son los de la
/// tabla de referencia del ERP (clienteOfertaVisita.test.ts): la app solo los
/// muestra, no los recalcula.
void main() {
  const json = {
    'citaId': 'cita-1',
    'fechaVisita': '2026-10-02T16:00:00.000Z',
    'muebles': ['Clóset'],
    'demo': true,
    'precioContado': 10000,
    'precioLista': 13482.58,
    'mensualidad': 749.04,
    'meses': 18,
    'descuento': 3482.58,
    'descuentoPct': 25.83,
    'imagenDiseno': null,
    'arquitecto': 'Ana López',
    'emitida': '2026-10-02T16:00:00.000Z',
    'vigenteHasta': '2026-10-17T16:00:00.000Z',
    'vigente': true,
    'incluye': ['Proceso de fabricación', 'Materiales', 'Transporte', 'Instalación'],
  };

  final oferta = OfertaVisita.fromJson(json);
  const contacto = Contacto(empresa: 'MOBLAR', telefono: '5512345678', whatsapp: 'https://wa.me/525512345678');

  Future<void> abrir(WidgetTester tester, OfertaVisita o) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [TarjetaOfertaVisita(oferta: o, contacto: contacto, nombre: 'Carlos')],
          ),
        ),
      ),
    );
  }

  group('modelo', () {
    test('lee la oferta tal cual la manda el servidor', () {
      expect(oferta.demo, isTrue);
      expect(oferta.precioLista, 13482.58);
      expect(oferta.mensualidad, 749.04);
      expect(oferta.meses, 18);
      expect(oferta.descuento, 3482.58);
      expect(oferta.precioContado, 10000);
      expect(oferta.imagenDiseno, isNull);
      expect(oferta.incluye, hasLength(4));
      expect(oferta.completa, isTrue);
    });

    test('incompleta si faltan precios (no se muestra)', () {
      expect(OfertaVisita.fromJson(const {'demo': true}).completa, isFalse);
    });

    test('ligada a su cita, con fecha y muebles', () {
      expect(oferta.citaId, 'cita-1');
      expect(oferta.fechaVisita, '2026-10-02T16:00:00.000Z');
      expect(oferta.muebles, ['Clóset']);
      expect(oferta.marca.clave, 'moblar');
    });

    test('Inicio: lista de ofertas (vacía si el servidor no la manda; descarta incompletas)', () {
      final sin = Inicio.fromJson(const {'contacto': {}});
      expect(sin.ofertasVisita, isEmpty);
      final con = Inicio.fromJson({
        'contacto': const {},
        'ofertasVisita': [json, const {'demo': true}],
      });
      expect(con.ofertasVisita, hasLength(1));
      expect(con.ofertasVisita.first.precioLista, 13482.58);
    });
  });

  testWidgets('muestra lista, 18 MSI, descuento y contado en ese orden', (tester) async {
    await abrir(tester, oferta);
    expect(find.byKey(const Key('avisoDemo')), findsOneWidget);
    expect(find.text('COTIZACIÓN COMERCIAL'), findsOneWidget);
    expect(find.text('Clóset'), findsOneWidget);
    expect(find.textContaining('Propuesta de tu visita del'), findsOneWidget);
    expect(find.byKey(const Key('fotoPendienteOferta')), findsOneWidget);
    expect(find.text(r'$13,482.58'), findsOneWidget);
    expect(find.text(r'o 18 meses sin intereses de $749.04'), findsOneWidget);
    expect(find.text(r'−$3,482.58 (25.8%)'), findsOneWidget);
    expect(find.text(r'$10,000.00'), findsOneWidget);
    expect(find.text('Tu arquitecto: Ana López'), findsOneWidget);
    expect(find.text('Instalación'), findsOneWidget);
    expect(find.text('Preguntar por esta cotización'), findsOneWidget);
    expect(find.text('Vencida'), findsNothing);

    final lista = tester.getTopLeft(find.byKey(const Key('precioListaOferta'))).dy;
    final msi = tester.getTopLeft(find.byKey(const Key('mensualidadOferta'))).dy;
    final contado = tester.getTopLeft(find.byKey(const Key('precioContadoOferta'))).dy;
    expect(lista < msi && msi < contado, isTrue);
  });

  testWidgets('vencida: etiqueta y pedir actualización', (tester) async {
    await abrir(tester, OfertaVisita.fromJson({...json, 'vigente': false}));
    expect(find.text('Vencida'), findsOneWidget);
    expect(find.text('Pedir cotización actualizada'), findsOneWidget);
  });

  test('mensaje de WhatsApp: etiqueta de cotización con la fecha de la visita', () {
    final m = mensajeOfertaVisita(oferta, 'Carlos');
    expect(m, startsWith('[COTIZACIÓN '));
    expect(m, contains('Carlos'));
    expect(m, contains('que me dejó mi arquitecto en la visita'));
  });
}
