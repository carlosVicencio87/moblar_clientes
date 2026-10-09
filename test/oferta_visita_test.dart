import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_oferta.dart';
import 'package:moblar_clientes/ui/widgets/contacto.dart';
import 'package:moblar_clientes/ui/widgets/oferta_visita.dart';

/// Esqueleto de la oferta de la visita (paso C). La app solo muestra los
/// números del servidor, no los recalcula.
///  - `json`: servidor anterior, sin desglose de IVA (debe seguir funcionando).
///  - `jsonIva`: servidor actual (clienteOfertaVisita.test.ts, $10,000 antes de
///    IVA, tarifa real de Clip): con factura por omisión y `sinFactura`.
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
      {'meses': 1, 'total': 10360.51, 'mensualidad': 10360.51, 'cobro': 4144.21, 'liquida': false},
      {'meses': 3, 'total': 10962.54, 'mensualidad': 3654.18, 'cobro': 10962.54, 'liquida': true},
      {'meses': 6, 'total': 11397.29, 'mensualidad': 1899.55, 'cobro': 11397.29, 'liquida': true},
      {'meses': 9, 'total': 11950.19, 'mensualidad': 1327.8, 'cobro': 11950.19, 'liquida': true},
      {'meses': 12, 'total': 12238.57, 'mensualidad': 1019.89, 'cobro': 12238.57, 'liquida': true},
      {'meses': 18, 'total': 13482.58, 'mensualidad': 749.04, 'cobro': 13482.58, 'liquida': true},
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

  final jsonIva = <String, dynamic>{
    ...json,
    'subtotal': 10000,
    'iva': 1600,
    'ivaPct': 16,
    'precioContado': 11600,
    'precioLista': 15640.45,
    'mensualidad': 868.92,
    'descuento': 4040.45,
    'descuentoPct': 25.83,
    'anticipoContado': 4640,
    'anticipoTarjeta': 4807.3,
    'precioTarjeta': 12018.24,
    'opcionesTarjeta': [
      {'meses': 1, 'total': 12018.24, 'mensualidad': 12018.24, 'cobro': 4807.3, 'liquida': false},
      {'meses': 3, 'total': 12716.7, 'mensualidad': 4238.9, 'cobro': 12716.7, 'liquida': true},
      {'meses': 6, 'total': 13221.08, 'mensualidad': 2203.52, 'cobro': 13221.08, 'liquida': true},
      {'meses': 9, 'total': 13862.55, 'mensualidad': 1540.29, 'cobro': 13862.55, 'liquida': true},
      {'meses': 12, 'total': 14197.13, 'mensualidad': 1183.1, 'cobro': 14197.13, 'liquida': true},
      {'meses': 18, 'total': 15640.45, 'mensualidad': 868.92, 'cobro': 15640.45, 'liquida': true},
    ],
    'sinFactura': {
      'precioContado': 10000,
      'precioLista': 13483.15,
      'mensualidad': 749.07,
      'meses': 18,
      'descuento': 3483.15,
      'descuentoPct': 25.83,
      'anticipoPct': 40,
      'anticipoContado': 4000,
      'anticipoTarjeta': 4144.23,
      'precioTarjeta': 10360.56,
      'opcionesTarjeta': [
        {'meses': 1, 'total': 10360.56, 'mensualidad': 10360.56, 'cobro': 4144.23, 'liquida': false},
        {'meses': 3, 'total': 10962.68, 'mensualidad': 3654.23, 'cobro': 10962.68, 'liquida': true},
        {'meses': 6, 'total': 11397.48, 'mensualidad': 1899.58, 'cobro': 11397.48, 'liquida': true},
        {'meses': 9, 'total': 11950.48, 'mensualidad': 1327.84, 'cobro': 11950.48, 'liquida': true},
        {'meses': 12, 'total': 12238.9, 'mensualidad': 1019.91, 'cobro': 12238.9, 'liquida': true},
        {'meses': 18, 'total': 13483.15, 'mensualidad': 749.07, 'cobro': 13483.15, 'liquida': true},
      ],
    },
  };
  final ofertaIva = OfertaVisita.fromJson(jsonIva);
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
      expect(find.textContaining('ya está en «Mi compra»'), findsOneWidget);
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

    testWidgets('tarjeta: un solo pago por omisión, sin abrir ningún link en la demo', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoTarjeta'));
      expect(find.byKey(const Key('detalleTarjeta')), findsOneWidget);
      // Se despliegan el pago único y nuestros MSI.
      for (final m in [1, 3, 6, 9, 12, 18]) {
        await tester.scrollUntilVisible(
          find.byKey(Key('opcionAnticipo-$m')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(Key('opcionAnticipo-$m')), findsOneWidget);
      }
      await tocar(tester, const Key('pagarConClip'));
      expect(find.text(r'Precio con tarjeta: $10,360.51'), findsOneWidget);
      expect(find.text(r'Anticipo: $4,144.21 · Tarjeta, un solo pago · pagado con Clip'), findsOneWidget);
      expect(find.text(r'Saldo: $6,216.30'), findsOneWidget);
    });

    testWidgets('tarjeta a 18 MSI: paga el mueble completo, sin anticipo ni saldo', (tester) async {
      await abrir(tester, oferta);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoTarjeta'));
      await tocar(tester, const Key('opcionAnticipo-18'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('resumenPlazo')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      final resumen = find.byKey(const Key('resumenPlazo'));
      expect(find.descendant(of: resumen, matching: find.text('Pagas tu mueble completo en')), findsOneWidget);
      expect(find.descendant(of: resumen, matching: find.text(r'18 × $749.04')), findsOneWidget);
      expect(find.textContaining('No hay anticipo ni saldo pendiente'), findsOneWidget);
      await tocar(tester, const Key('pagarConClip'));
      expect(find.text(r'Precio con tarjeta (18 MSI): $13,482.58'), findsOneWidget);
      expect(find.text(r'Pagado completo: $13,482.58 · Tarjeta, 18 MSI · pagado con Clip'), findsOneWidget);
      expect(find.text(r'Saldo: $0.00 · Liquidado'), findsOneWidget);
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

  group('IVA y factura', () {
    test('servidor anterior: sin desglose ni casilla de factura', () {
      expect(oferta.iva, 0);
      expect(oferta.eligeFactura, isFalse);
      expect(identical(oferta.variante(factura: false), oferta), isTrue);
    });

    test('con factura por omisión; la variante sin factura conserva la cita y la transferencia', () {
      expect(ofertaIva.subtotal, 10000);
      expect(ofertaIva.iva, 1600);
      expect(ofertaIva.precioContado, 11600);
      expect(ofertaIva.conFactura, isTrue);
      expect(ofertaIva.eligeFactura, isTrue);
      final sin = ofertaIva.variante(factura: false);
      expect(sin.conFactura, isFalse);
      expect(sin.iva, 0);
      expect(sin.subtotal, 10000);
      expect(sin.precioContado, 10000);
      expect(sin.precioLista, 13483.15);
      expect(sin.anticipoContado, 4000);
      expect(sin.opcionesTarjeta.last.total, 13483.15);
      expect(sin.citaId, 'cita-1');
      expect(sin.transferencia?.concepto, 'ANTICIPO-CITA1');
      expect(sin.adquirible, isTrue);
      expect(identical(ofertaIva.variante(factura: true), ofertaIva), isTrue);
    });

    testWidgets('la tarjeta desglosa el IVA en su propio renglón', (tester) async {
      await abrir(tester, ofertaIva);
      expect(find.text('Precio de lista (IVA incluido)'), findsOneWidget);
      expect(find.text(r'$15,640.45'), findsOneWidget);
      final subtotal = find.byKey(const Key('subtotalOferta'));
      final iva = find.byKey(const Key('ivaOferta'));
      expect(find.descendant(of: subtotal, matching: find.text(r'$10,000.00')), findsOneWidget);
      expect(find.descendant(of: iva, matching: find.text('IVA (16%)')), findsOneWidget);
      expect(find.descendant(of: iva, matching: find.text(r'$1,600.00')), findsOneWidget);
      expect(find.text(r'$11,600.00'), findsOneWidget);
      expect(find.byKey(const Key('avisoFacturaOferta')), findsOneWidget);
      final y = tester.getTopLeft(iva).dy;
      expect(tester.getTopLeft(subtotal).dy < y, isTrue);
      expect(y < tester.getTopLeft(find.byKey(const Key('precioContadoOferta'))).dy, isTrue);
    });

    testWidgets('"Requiero factura" marcada: anticipo con IVA; desmarcada: sin IVA', (tester) async {
      await abrir(tester, ofertaIva);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      final casilla = find.byKey(const Key('requiereFactura'));
      expect(tester.widget<CheckboxListTile>(casilla).value, isTrue);
      expect(find.text(r'Precio de tu mueble $10,000.00 + IVA (16%) $1,600.00.'), findsOneWidget);
      // Con factura: 11,600 → anticipo 4,640, saldo 6,960; tarjeta 12,018.24.
      Future<void> verTarjeta(String precio) async {
        // La lista es perezosa: bajar hasta el resumen con tarjeta y volver arriba.
        final tarjeta = find.byKey(const Key('resumenTarjeta'));
        await tester.scrollUntilVisible(tarjeta, 200, scrollable: find.byType(Scrollable).last);
        expect(find.descendant(of: tarjeta, matching: find.text(precio)), findsOneWidget);
        await tester.scrollUntilVisible(casilla, -200, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
      }

      expect(find.text(r'$4,640.00'), findsOneWidget);
      expect(find.text(r'$6,960.00'), findsOneWidget);
      await verTarjeta(r'$12,018.24');

      await tocar(tester, const Key('requiereFactura'));
      expect(tester.widget<CheckboxListTile>(casilla).value, isFalse);
      expect(find.text(r'Sin factura no se cobra IVA: pagas $1,600.00 menos.'), findsOneWidget);
      // Sin factura: 10,000 → anticipo 4,000, saldo 6,000; tarjeta 10,360.56.
      expect(find.text(r'$4,000.00'), findsOneWidget);
      expect(find.text(r'$6,000.00'), findsOneWidget);
      expect(find.text(r'$4,640.00'), findsNothing);
      await verTarjeta(r'$10,360.56');
    });

    testWidgets('sin factura y en efectivo: la compra queda sin IVA', (tester) async {
      await abrir(tester, ofertaIva);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('requiereFactura'));
      await tocar(tester, const Key('anticipoEfectivo'));
      expect(find.text(r'Entrega $4,000.00 a Ana López'), findsOneWidget);
      await tocar(tester, const Key('turnoArquitecto'));
      for (final d in ['4', '8', '2', '7']) {
        await tocar(tester, Key('pin-$d'));
      }
      await tocar(tester, const Key('pinConfirmar'));
      expect(find.text('Adquirida'), findsOneWidget);
      expect(find.text('Sin factura (sin IVA)'), findsOneWidget);
      expect(find.text(r'Precio de contado: $10,000.00'), findsOneWidget);
      expect(find.text(r'Saldo: $6,000.00'), findsOneWidget);
    });

    testWidgets('con factura a 18 MSI: paga el total con IVA', (tester) async {
      await abrir(tester, ofertaIva);
      await tocar(tester, const Key('adquirirOferta-cita-1'));
      await tocar(tester, const Key('anticipoTarjeta'));
      await tocar(tester, const Key('opcionAnticipo-18'));
      await tocar(tester, const Key('pagarConClip'));
      expect(find.text('Con factura (IVA incluido)'), findsOneWidget);
      expect(find.text(r'Pagado completo: $15,640.45 · Tarjeta, 18 MSI · pagado con Clip'), findsOneWidget);
      expect(find.text(r'Saldo: $0.00 · Liquidado'), findsOneWidget);
    });
  });
}
