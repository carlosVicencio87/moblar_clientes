import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_oferta.dart';
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
    'anticipoPct': 40,
    'anticipoContado': 4000,
    'anticipoTarjeta': 4144.21,
    'precioTarjeta': 10360.51,
    'opcionesTarjeta': [
      {'meses': 1, 'total': 10360.51, 'mensualidad': 10360.51},
      {'meses': 3, 'total': 10962.54, 'mensualidad': 3654.18},
      {'meses': 6, 'total': 11397.29, 'mensualidad': 1899.55},
      {'meses': 9, 'total': 11950.19, 'mensualidad': 1327.8},
      {'meses': 12, 'total': 12238.57, 'mensualidad': 1019.89},
      {'meses': 18, 'total': 13482.58, 'mensualidad': 749.04},
    ],
    'transferencia': {
      'banco': 'BBVA',
      'beneficiario': 'MOBLAR (datos de ejemplo)',
      'clabe': '012180001234567891',
      'concepto': 'ANTICIPO-CITA1',
      'ejemplo': true,
    },
  };

  final oferta = OfertaVisita.fromJson(json);
  const contacto = Contacto(empresa: 'MOBLAR', telefono: '5512345678', whatsapp: 'https://wa.me/525512345678');

  setUp(() => DemoAnticipos.resultados.value = const {});

  Future<void> tocar(WidgetTester tester, Key key) async {
    final f = find.byKey(key);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

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

  group('adquirir', () {
    test('el modelo trae el anticipo y la transferencia', () {
      expect(oferta.anticipoPct, 40);
      expect(oferta.anticipoContado, 4000);
      expect(oferta.anticipoTarjeta, 4144.21);
      expect(oferta.precioTarjeta, 10360.51);
      expect(oferta.opcionesTarjeta.map((x) => x.meses), [1, 3, 6, 9, 12, 18]);
      expect(oferta.transferencia?.concepto, 'ANTICIPO-CITA1');
      expect(oferta.adquirible, isTrue);
    });

    test('vencida o sin anticipo: no se puede adquirir desde la app', () {
      expect(OfertaVisita.fromJson({...json, 'vigente': false}).adquirible, isFalse);
      expect(OfertaVisita.fromJson({...json, 'anticipoContado': null}).adquirible, isFalse);
      expect(OfertaVisita.fromJson({...json, 'precioTarjeta': null}).adquirible, isFalse);
    });

    testWidgets('pantalla del anticipo: 40%, montos y tres formas de pago', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      expect(find.byType(AdquirirOfertaPage), findsOneWidget);
      expect(find.text('Para empezar a trabajar en Clóset requerimos el 40% de anticipo.'), findsOneWidget);
      // De contado: 10,000 → anticipo 4,000, saldo 6,000. Tarjeta: sobre la lista.
      expect(find.text(r'$4,000.00'), findsOneWidget);
      expect(find.text(r'$6,000.00'), findsOneWidget);
      expect(find.text(r'$10,360.51'), findsOneWidget);
      expect(find.text(r'$4,144.21'), findsOneWidget);
      expect(find.text(r'$6,216.30'), findsOneWidget);
      // La lista solo construye lo cercano a la pantalla: se baja hasta cada opción.
      for (final k in ['anticipoEfectivo', 'anticipoTransferencia', 'anticipoTarjeta']) {
        await tester.scrollUntilVisible(find.byKey(Key(k)), 200, scrollable: find.byType(Scrollable).last);
        expect(find.byKey(Key(k)), findsOneWidget);
      }
    });

    testWidgets('efectivo con el PIN del arquitecto → Adquirida, con su compra', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoEfectivo'));
      expect(find.text(r'Entrega $4,000.00 a Ana López'), findsOneWidget);
      await tocar(tester, const Key('turnoArquitecto'));
      for (final d in ['4', '8', '2', '7']) {
        await tocar(tester, Key('pin-$d'));
      }
      await tocar(tester, const Key('pinConfirmar'));

      // De regreso en Cotizaciones: la tarjeta ya está adquirida.
      expect(find.byType(AdquirirOfertaPage), findsNothing);
      expect(find.text('Adquirida'), findsOneWidget);
      expect(find.byKey(const Key('adquirirOferta-cita-1')), findsNothing);
      expect(find.text('Adquiriste: Clóset'), findsOneWidget);
      expect(find.text(r'Precio de contado: $10,000.00'), findsOneWidget);
      expect(find.text(r'Anticipo: $4,000.00 · Efectivo · recibido por Ana López'), findsOneWidget);
      expect(find.text(r'Saldo: $6,000.00'), findsOneWidget);

      await tocar(tester, const Key('verCompraOferta-cita-1'));
      expect(find.textContaining('aparecerá en «Mi compra»'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      await tocar(tester, const Key('reiniciarAnticipo-cita-1'));
      expect(find.text('Adquirida'), findsNothing);
      expect(find.byKey(const Key('adquirirOferta-cita-1')), findsOneWidget);
    });

    testWidgets('transferencia: concepto del anticipo y queda en revisión', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoTransferencia'));
      expect(find.text('ANTICIPO-CITA1'), findsOneWidget);
      expect(find.textContaining('el pago es del anticipo de tu mueble'), findsOneWidget);
      await tocar(tester, const Key('elegirComprobante'));
      await tocar(tester, const Key('enviarComprobante'));
      expect(find.text(r'Anticipo: $4,000.00 · Transferencia · en revisión'), findsOneWidget);
    });

    testWidgets('tarjeta: anticipo sobre el precio con tarjeta (un pago), sin abrir ningún link en la demo', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoTarjeta'));
      expect(find.byKey(const Key('detalleTarjeta')), findsOneWidget);
      expect(find.textContaining('incluye la comisión de Clip'), findsOneWidget);
      await tocar(tester, const Key('pagarConClip'));
      expect(find.text(r'Precio con tarjeta: $10,360.51'), findsOneWidget);
      expect(find.text(r'Anticipo: $4,144.21 · Tarjeta (Clip) · pagado con Clip'), findsOneWidget);
      expect(find.text(r'Saldo: $6,216.30'), findsOneWidget);
    });

    testWidgets('vencida: sin botón de adquirir', (tester) async {
      await abrir(tester, OfertaVisita.fromJson({...json, 'vigente': false}));
      expect(find.byKey(const Key('adquirirOferta-cita-1')), findsNothing);
    });
  });

  testWidgets('opciones con tarjeta: un pago y cada plazo con su precio', (tester) async {
    await abrir(tester, oferta);
    await tocar(tester, const Key('opcionesTarjeta'));
    expect(find.text('Un solo pago'), findsOneWidget);
    expect(find.text(r'$10,360.51'), findsOneWidget);
    expect(find.text(r'3 × $3,654.18'), findsOneWidget);
    expect(find.text(r'Total $10,962.54'), findsOneWidget);
    expect(find.text(r'18 × $749.04'), findsOneWidget);
    expect(find.text(r'Total $13,482.58'), findsOneWidget);
  });
}
