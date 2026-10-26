// Iniciar el proyecto (Carlos, 2026-10-13): 50% para entrar a fabricación, o
// apartar con un monto libre (mínimo $1,000 o 10%) y completar el 50% después.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/compras_demo.dart';
import 'package:moblar_clientes/ui/estado_cuenta.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_oferta.dart';
import 'package:moblar_clientes/ui/widgets/persistencia_demo.dart';

void main() {
  const json = {
    'citaId': 'cita-1',
    'fechaVisita': '2026-10-13T16:00:00.000Z',
    'muebles': ['Clóset'],
    'demo': true,
    'precioContado': 10000,
    'precioLista': 15383.97,
    'mensualidad': 641,
    'meses': 24,
    'descuento': 5383.97,
    'descuentoPct': 35,
    'arquitecto': 'Ana López',
    'emitida': '2026-10-13T16:00:00.000Z',
    'vigenteHasta': '2026-10-28T16:00:00.000Z',
    'vigente': true,
    'anticipoPct': 50,
    'anticipoContado': 5000,
    'anticipoTarjeta': 5180.28,
    'precioTarjeta': 10360.56,
    'apartadoMinimo': 1000,
    'opcionesTarjeta': [
      {'meses': 1, 'total': 10360.56, 'mensualidad': 10360.56, 'cobro': 5180.28, 'liquida': false},
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
  final apartado = ResultadoAnticipo(
    metodo: 'efectivo',
    monto: 2000,
    fecha: DateTime(2026, 10, 13, 12),
    arquitecto: 'Ana López',
    factura: false,
    apartado: true,
  );

  setUp(() => DemoAnticipos.resultados.value = const {});

  Future<void> pantalla(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pumpAndSettle();
  }

  test('modelo: mínimo para apartar', () {
    expect(oferta.apartadoMinimo, 1000);
    expect(oferta.permiteApartar, isTrue);
    expect(OfertaVisita.fromJson({...json, 'apartadoMinimo': null}).permiteApartar, isFalse);
  });

  group('adquirir', () {
    testWidgets('por omisión, iniciar fabricación con el 50%', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta));
      expect(find.text('Para empezar a trabajar en Clóset requerimos el 50% de anticipo.'), findsOneWidget);
      expect(find.byKey(const Key('textoApartar')), findsOneWidget);
      expect(find.text(r'Efectivo · $5,000.00'), findsOneWidget);
      expect(find.byKey(const Key('infoApartado')), findsNothing);
    });

    testWidgets('apartar: mínimo, tope y efectivo con PIN', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta));
      await tester.tap(find.byKey(const Key('segApartar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('infoApartado')), findsOneWidget);
      expect(find.text('Una vez apartado, te respetamos este precio.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('montoApartado')), '500');
      await tester.pump();
      expect(find.text(r'Para apartar, lo mínimo es $1,000.00.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('montoApartado')), '5000');
      await tester.pump();
      expect(find.textContaining('entra directo a fabricación'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('montoApartado')), '2000');
      await tester.pump();
      expect(find.text(r'Efectivo · $2,000.00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('apartadoEfectivo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('turnoArquitecto')));
      await tester.pumpAndSettle();
      for (final d in ['4', '8', '2', '7']) {
        await tester.tap(find.byKey(Key('pin-$d')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('pinConfirmar')));
      await tester.pumpAndSettle();
      final r = DemoAnticipos.resultados.value['cita-1']!;
      expect((r.apartado, r.monto, r.metodo), (true, 2000, 'efectivo'));
    });

    testWidgets('apartar por transferencia', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta));
      await tester.tap(find.byKey(const Key('segApartar')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('montoApartado')), '1500');
      await tester.pump();
      await tester.tap(find.byKey(const Key('apartadoTransferencia')));
      await tester.pumpAndSettle();
      expect(find.text('ANTICIPO-CITA1'), findsOneWidget);
    });

    testWidgets('sin monto válido las formas de pago no hacen nada', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta));
      await tester.tap(find.byKey(const Key('segApartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apartadoEfectivo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('turnoArquitecto')), findsNothing);
    });
  });

  group('después de apartar', () {
    testWidgets('resumen: "Apartado" y cuánto falta para fabricación', (tester) async {
      await pantalla(tester, Scaffold(body: ResumenCompraOferta(oferta: oferta, resultado: apartado)));
      expect(find.text(r'Apartado: $2,000.00 · Efectivo · recibido por Ana López'), findsOneWidget);
      expect(find.text(r'Saldo: $8,000.00'), findsOneWidget);
      expect(find.textContaining(r'Te faltan $3,000.00 para iniciar la fabricación (50%)'), findsOneWidget);
    });

    test('compra de la demo: con el anticipo no empieza nada; con firma y 50 % sí', () {
      final c = compraDemo(oferta, apartado, const []);
      expect(c.metaFabricacion, 5000);
      expect(c.lineaTiempo.mensaje, contains('Tu arquitecto está preparando tu cotización formal'));
      expect(c.lineaTiempo.mensaje, isNot(contains('Comenzamos')));
      expect(c.lineaTiempo.porcentaje, 0);
      expect(c.lineaTiempo.etapas.first.titulo, 'Cotización formal');
      expect(c.cuenta?.pagos.last.concepto, 'Apartado');

      final lista = Cotizacion.fromJson(const {'id': 'p-1', 'citaId': 'cita-1', 'tienePdf': true, 'marca': {}});
      final firmada = Cotizacion.fromJson(const {
        'id': 'p-1',
        'citaId': 'cita-1',
        'tienePdf': true,
        'firma': {'fecha': '2026-10-26T18:00:00.000Z', 'version': 1},
        'marca': {},
      });
      expect(
        compraDemo(oferta, apartado, const [], formal: lista).lineaTiempo.mensaje,
        contains('Empezaremos tu proyecto en cuanto la firmes'),
      );
      // Firmada pero apartada: todavía le falta para el 50 %.
      final apartada = compraDemo(oferta, apartado, const [], formal: firmada);
      expect(apartada.lineaTiempo.mensaje, contains(r'te faltan $3,000.00'));
      expect(apartada.lineaTiempo.porcentaje, 0);

      final cubierta = compraDemo(
        oferta,
        apartado,
        [AbonoDemo(fecha: DateTime(2026, 10, 20), monto: 3000, metodo: 'Efectivo', validado: true)],
        formal: firmada,
      );
      expect(cubierta.lineaTiempo.mensaje, contains('¡Comenzamos con tu proyecto!'));
      expect(cubierta.lineaTiempo.porcentaje, greaterThan(0));
      expect(cubierta.lineaTiempo.etapas.first.situacion, Situacion.hecha);

      // Sin firma no empieza aunque esté cubierto.
      final sinFirma = compraDemo(oferta, apartado, [
        AbonoDemo(fecha: DateTime(2026, 10, 20), monto: 3000, metodo: 'Efectivo', validado: true),
      ]);
      expect(sinFirma.lineaTiempo.porcentaje, 0);
      expect(sinFirma.lineaTiempo.mensaje, isNot(contains('Comenzamos')));
    });

    testWidgets('estado de cuenta: aviso de lo que falta y de cuando se cubre', (tester) async {
      final cuenta = cuentaDemo(oferta, apartado, const []);
      await pantalla(tester, Scaffold(body: ListView(children: [EstadoCuentaCompra(cuenta: cuenta, metaFabricacion: 5000)])));
      expect(find.textContaining(r'te faltan $3,000.00'), findsOneWidget);
      final cubierta = cuentaDemo(oferta, apartado, [
        AbonoDemo(fecha: DateTime(2026, 10, 20), monto: 3000, metodo: 'Efectivo', validado: true),
      ]);
      await pantalla(tester, Scaffold(body: ListView(children: [EstadoCuentaCompra(cuenta: cubierta, metaFabricacion: 5000)])));
      expect(find.textContaining('tu proyecto entra a fabricación'), findsOneWidget);
    });

    test('el apartado se guarda y se restaura', () {
      final r = anticipoDeJson(anticipoAJson(apartado))!;
      expect((r.apartado, r.monto, r.factura), (true, 2000, false));
    });
  });
}
