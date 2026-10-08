// Fin de la visita y la regla de la visita al comprar (Carlos, 2026-10-08):
// si inicia su proyecto la visita no se cobra; si ya la pagó, se abona a lo
// que paga hoy. Siempre paga en total el precio del mueble.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_oferta.dart';
import 'package:moblar_clientes/ui/widgets/pago_visita.dart';
import 'package:moblar_clientes/ui/widgets/visita_terminada.dart';

void main() {
  const ofertaJson = {
    'citaId': 'cita-1',
    'fechaVisita': '2026-10-08T16:00:00.000Z',
    'muebles': ['Clóset'],
    'demo': true,
    'precioContado': 10000,
    'precioLista': 15383.97,
    'mensualidad': 641,
    'meses': 24,
    'descuento': 5383.97,
    'descuentoPct': 35,
    'arquitecto': 'Ana López',
    'emitida': '2026-10-08T16:00:00.000Z',
    'vigenteHasta': '2026-10-23T16:00:00.000Z',
    'vigente': true,
    'anticipoPct': 40,
    'anticipoContado': 4000,
    'anticipoTarjeta': 4144.21,
    'precioTarjeta': 10360.51,
    'opcionesTarjeta': [
      {'meses': 1, 'total': 10360.51, 'mensualidad': 10360.51, 'cobro': 4144.21, 'liquida': false},
      {'meses': 3, 'total': 10962.54, 'mensualidad': 3654.18, 'cobro': 10962.54, 'liquida': true},
    ],
    'transferencia': {
      'banco': 'BBVA',
      'beneficiario': 'MOBLAR (datos de ejemplo)',
      'clabe': '012180001234567891',
      'concepto': 'ANTICIPO-CITA1',
      'ejemplo': true,
    },
  };
  const pagoJson = {
    'demo': true,
    'monto': 500,
    'estado': 'pendiente',
    'promesaRegistrada': true,
    'metodos': ['transferencia', 'efectivo'],
  };
  final oferta = OfertaVisita.fromJson(ofertaJson);
  final pago = PagoVisita.fromJson(pagoJson);

  Map<String, dynamic> citaJson({String clave = 'realizada', DateTime? fecha}) => {
        'id': 'cita-1',
        'fecha': (fecha ?? DateTime.now()).toUtc().toIso8601String(),
        'estado': {'clave': clave, 'titulo': 'x'},
        'arquitecto': 'Ana López',
        'muebles': ['Clóset'],
        'marca': const {},
        'pagoVisita': pagoJson,
      };
  Cita cita({String clave = 'realizada'}) => Cita.fromJson(citaJson(clave: clave));
  Inicio inicio({String clave = 'realizada', DateTime? fecha, bool conPago = true}) => Inicio.fromJson({
        'contacto': const {},
        'citas': [
          {...citaJson(clave: clave, fecha: fecha), if (!conPago) 'pagoVisita': null},
        ],
        'ofertasVisita': [ofertaJson],
      });

  setUp(() {
    DemoPagosVisita.resultados.value = const {};
    DemoAnticipos.resultados.value = const {};
  });

  void visitaPagada() => DemoPagosVisita.registrar(
        'cita-1',
        ResultadoPagoVisita(metodo: 'efectivo', fecha: DateTime(2026, 10, 8, 12), arquitecto: 'Ana López'),
      );

  Future<void> pantalla(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
    await tester.pumpAndSettle();
  }

  group('abono de la visita', () {
    test('al centavo y nunca negativo', () {
      expect(menosAbono(4000, 500), 3500);
      expect(menosAbono(4144.21, 500), 3644.21);
      expect(menosAbono(300, 500), 0);
      expect(menosAbono(4000, 0), 4000);
    });

    test('solo se abona si ya la pagó', () {
      expect(abonoVisita('cita-1', 500), 0);
      visitaPagada();
      expect(abonoVisita('cita-1', 500), 500);
      expect(abonoVisita('otra', 500), 0);
      expect(abonoVisita('cita-1', 0), 0);
    });

    test('tarjeta: baja el cobro, no el precio; a meses se reparte', () {
      const unPago = OpcionTarjeta(meses: 1, total: 10360.51, mensualidad: 10360.51, cobro: 4144.21);
      final u = conAbono(unPago, 500);
      expect(u.cobro, 3644.21);
      expect(u.total, 10360.51);
      const msi = OpcionTarjeta(meses: 3, total: 10962.54, mensualidad: 3654.18, cobro: 10962.54, liquida: true);
      final m = conAbono(msi, 500);
      expect(m.cobro, 10462.54);
      expect(m.mensualidad, 3487.52); // 10,462.54 / 3 hacia arriba al centavo
      expect(identical(conAbono(msi, 0), msi), isTrue);
    });
  });

  group('iniciar el proyecto', () {
    testWidgets('visita sin pagar: no se cobra y el anticipo es completo', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta, montoVisita: 500));
      expect(find.text(r'Tu visita ($500.00) no tiene costo al iniciar tu proyecto.'), findsOneWidget);
      expect(find.text(r'Efectivo · $4,000.00'), findsOneWidget);
      expect(find.text('Ya pagaste tu visita'), findsNothing);
    });

    testWidgets('visita ya pagada: se descuenta de lo que paga hoy', (tester) async {
      visitaPagada();
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta, montoVisita: 500));
      expect(find.textContaining(r'Ya pagaste tu visita ($500.00)'), findsOneWidget);
      final contado = find.byKey(const Key('resumenContado'));
      expect(find.descendant(of: contado, matching: find.text(r'$4,000.00')), findsOneWidget);
      expect(find.descendant(of: contado, matching: find.text(r'−$500.00')), findsOneWidget);
      expect(find.descendant(of: contado, matching: find.text(r'$3,500.00')), findsOneWidget);
      expect(find.descendant(of: contado, matching: find.text(r'$6,000.00')), findsOneWidget);
      expect(find.text(r'Efectivo · $3,500.00'), findsOneWidget);
      expect(find.text(r'Tarjeta · desde $3,644.21'), findsOneWidget);
    });

    testWidgets('sin visita (montoVisita 0): igual que antes', (tester) async {
      await pantalla(tester, AdquirirOfertaPage(oferta: oferta));
      expect(find.byKey(const Key('avisoVisitaAnticipo')), findsNothing);
      expect(find.text(r'Efectivo · $4,000.00'), findsOneWidget);
    });

    testWidgets('resumen de la compra con abono: anticipo completo y saldo correcto', (tester) async {
      await pantalla(
        tester,
        Scaffold(
          body: ResumenCompraOferta(
            oferta: oferta,
            resultado: ResultadoAnticipo(
              metodo: 'efectivo',
              monto: 3500,
              abonoVisita: 500,
              fecha: DateTime(2026, 10, 8),
              arquitecto: 'Ana López',
            ),
          ),
        ),
      );
      expect(find.text(r'Anticipo: $4,000.00 · Efectivo · recibido por Ana López'), findsOneWidget);
      expect(find.text(r'Incluye $500.00 que ya habías pagado de tu visita.'), findsOneWidget);
      expect(find.text(r'Saldo: $6,000.00'), findsOneWidget);
    });
  });

  group('tarjeta de la visita en la cita', () {
    Future<void> tarjeta(WidgetTester tester) =>
        pantalla(tester, Scaffold(body: ListView(children: [TarjetaPagoVisita(cita: cita(), pago: pago)])));

    testWidgets('terminada y sin decidir: pendiente, explica que comprando no cuesta', (tester) async {
      await tarjeta(tester);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.textContaining('Si inicias tu proyecto, tu visita no tiene costo'), findsOneWidget);
      expect(find.byKey(const Key('pagarVisita')), findsOneWidget);
    });

    testWidgets('inició su proyecto sin pagarla: sin costo y sin botón de pago', (tester) async {
      DemoAnticipos.registrar('cita-1', ResultadoAnticipo(metodo: 'efectivo', monto: 4000, fecha: DateTime(2026, 10, 8)));
      await tarjeta(tester);
      expect(find.text('Sin costo'), findsOneWidget);
      expect(find.byKey(const Key('visitaSinCosto')), findsOneWidget);
      expect(find.byKey(const Key('pagarVisita')), findsNothing);
    });

    testWidgets('la pagó y después compró: se abonó', (tester) async {
      visitaPagada();
      DemoAnticipos.registrar(
        'cita-1',
        ResultadoAnticipo(metodo: 'efectivo', monto: 3500, abonoVisita: 500, fecha: DateTime(2026, 10, 8)),
      );
      await tarjeta(tester);
      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('Este pago se abonó al anticipo de tu proyecto.'), findsOneWidget);
    });
  });

  group('cuándo aparece la pantalla de fin de visita', () {
    test('visita de hoy terminada, con propuesta y sin cubrir', () {
      final v = visitaPorCubrir(inicio(), DateTime.now());
      expect(v?.cita.id, 'cita-1');
      expect(v?.oferta.citaId, 'cita-1');
      expect(montoVisitaDe(inicio(), 'cita-1'), 500);
      expect(montoVisitaDe(inicio(), 'otra'), 0);
    });

    test('no aparece: en curso, otro día, ya mostrada, sin pago de visita', () {
      final ahora = DateTime.now();
      expect(visitaPorCubrir(inicio(clave: 'en_visita'), ahora), isNull);
      expect(visitaPorCubrir(inicio(fecha: ahora.subtract(const Duration(days: 2))), ahora), isNull);
      expect(visitaPorCubrir(inicio(), ahora, omitir: {'cita-1'}), isNull);
      expect(visitaPorCubrir(inicio(conPago: false), ahora), isNull);
    });

    test('no aparece si ya pagó la visita o ya compró', () {
      visitaPagada();
      expect(visitaPorCubrir(inicio(), DateTime.now()), isNull);
      DemoPagosVisita.resultados.value = const {};
      DemoAnticipos.registrar('cita-1', ResultadoAnticipo(metodo: 'efectivo', monto: 4000, fecha: DateTime(2026, 10, 8)));
      expect(visitaPorCubrir(inicio(), DateTime.now()), isNull);
    });
  });

  group('pantalla "Tu visita terminó"', () {
    testWidgets('propuesta y las dos formas de cubrir la visita', (tester) async {
      await pantalla(tester, VisitaTerminadaPage(cita: cita(), oferta: oferta));
      expect(find.text('Ana López terminó tu visita'), findsOneWidget);
      expect(find.text(r'$10,000.00'), findsOneWidget);
      expect(find.text(r'o 24 meses sin intereses de $641.00'), findsOneWidget);
      expect(find.byKey(const Key('finVisitaIniciar')), findsOneWidget);
      expect(find.text(r'Por ahora, pagar solo mi visita · $500.00'), findsOneWidget);
      expect(find.byKey(const Key('finVisitaDespues')), findsOneWidget);
    });

    testWidgets('iniciar mi proyecto abre el anticipo con la visita sin costo', (tester) async {
      await pantalla(tester, VisitaTerminadaPage(cita: cita(), oferta: oferta));
      await tester.tap(find.byKey(const Key('finVisitaIniciar')));
      await tester.pumpAndSettle();
      expect(find.byType(AdquirirOfertaPage), findsOneWidget);
      expect(find.text(r'Tu visita ($500.00) no tiene costo al iniciar tu proyecto.'), findsOneWidget);
    });

    testWidgets('pagar solo la visita abre el pago de la visita', (tester) async {
      await pantalla(tester, VisitaTerminadaPage(cita: cita(), oferta: oferta));
      await tester.tap(find.byKey(const Key('finVisitaPagar')));
      await tester.pumpAndSettle();
      expect(find.byType(PagarVisitaPage), findsOneWidget);
    });
  });
}
