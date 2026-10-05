import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/pago_visita.dart';

/// Esqueleto de demostración del pago de la visita (sin servidor).
void main() {
  const json = {
    'demo': true,
    'monto': 350,
    'estado': 'pendiente',
    'promesaRegistrada': true,
    'metodos': ['transferencia', 'efectivo'],
    'transferencia': {
      'banco': 'BBVA',
      'beneficiario': 'MOBLAR (datos de ejemplo)',
      'clabe': '012180001234567891',
      'concepto': 'VISITA-3F2A9C',
      'ejemplo': true,
    },
  };

  final pago = PagoVisita.fromJson(json);
  const cita = Cita(
    id: 'cita-1',
    fecha: '2026-10-03T16:00:00Z',
    horario: null,
    estado: EstadoCita(clave: 'confirmada', titulo: 'Confirmada'),
    arquitecto: 'Ana López',
    muebles: [],
    costoVisita: 350,
    marca: Marca.moblar,
  );

  setUp(() => DemoPagosVisita.resultados.value = const {});

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [TarjetaPagoVisita(cita: cita, pago: pago)]),
        ),
      ),
    );
  }

  /// Lleva el widget a la vista. ListView construye solo lo cercano a la
  /// pantalla: si todavía no existe, se desplaza hasta que aparezca.
  Future<void> mostrar(WidgetTester tester, Key key) async {
    final f = find.byKey(key);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Key key) async {
    await mostrar(tester, key);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('modelo', () {
    test('lee el pago de la visita', () {
      expect(pago.demo, isTrue);
      expect(pago.monto, 350);
      expect(pago.promesaRegistrada, isTrue);
      expect(pago.aceptaTransferencia, isTrue);
      expect(pago.aceptaEfectivo, isTrue);
      expect(pago.transferencia!.clabeLegible, '012 180 00123456789 1');
    });

    test('sin datos de transferencia no se ofrece transferencia', () {
      final p = PagoVisita.fromJson({...json, 'transferencia': null});
      expect(p.aceptaTransferencia, isFalse);
      expect(p.aceptaEfectivo, isTrue);
    });

    test('la cita sin pagoVisita lo deja en null', () {
      final c = Cita.fromJson({'id': 'x', 'fecha': '2026-10-03T16:00:00Z'});
      expect(c.pagoVisita, isNull);
    });
  });

  testWidgets('tarjeta: pendiente, aviso de demostración y promesa', (tester) async {
    await abrir(tester);
    expect(find.byKey(const Key('avisoDemo')), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.textContaining('Al agendar te informamos'), findsOneWidget);
    expect(find.byKey(const Key('pagarVisita')), findsOneWidget);
  });

  testWidgets('transferencia: datos, comprobante y queda en revisión', (tester) async {
    await abrir(tester);
    await tocar(tester, const Key('pagarVisita'));
    expect(find.byKey(const Key('metodoTransferencia')), findsOneWidget);
    expect(find.byKey(const Key('metodoEfectivo')), findsOneWidget);
    // Sin tarjeta.
    expect(find.textContaining('Tarjeta'), findsNothing);

    await tocar(tester, const Key('metodoTransferencia'));
    expect(find.text('VISITA-3F2A9C'), findsOneWidget);
    expect(find.text('012 180 00123456789 1'), findsOneWidget);
    expect(find.textContaining('Datos de ejemplo'), findsOneWidget);

    // Sin comprobante no se puede enviar.
    await mostrar(tester, const Key('enviarComprobante'));
    final enviar = tester.widget<FilledButton>(find.byKey(const Key('enviarComprobante')));
    expect(enviar.onPressed, isNull);

    await tocar(tester, const Key('elegirComprobante'));
    expect(find.byKey(const Key('comprobanteElegido')), findsOneWidget);
    await tocar(tester, const Key('enviarComprobante'));

    // De regreso en la tarjeta.
    expect(find.byKey(const Key('tarjetaPagoVisita')), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(DemoPagosVisita.resultados.value['cita-1']?.metodo, 'transferencia');
  });

  testWidgets('efectivo: PIN del arquitecto; 0000 falla y otro confirma', (tester) async {
    await abrir(tester);
    await tocar(tester, const Key('pagarVisita'));
    await tocar(tester, const Key('metodoEfectivo'));
    expect(find.byKey(const Key('instruccionesEfectivo')), findsOneWidget);
    await tocar(tester, const Key('turnoArquitecto'));

    // PIN incompleto: no confirma.
    await tocar(tester, const Key('pin-1'));
    expect(DemoPagosVisita.resultados.value, isEmpty);

    // 0000 → error y se limpia.
    await tocar(tester, const Key('pinBorrar'));
    for (var i = 0; i < 4; i++) {
      await tocar(tester, const Key('pin-0'));
    }
    await tocar(tester, const Key('pinConfirmar'));
    expect(find.byKey(const Key('errorPin')), findsOneWidget);
    expect(DemoPagosVisita.resultados.value, isEmpty);

    for (final d in ['4', '8', '2', '7']) {
      await tocar(tester, Key('pin-$d'));
    }
    await tocar(tester, const Key('pinConfirmar'));

    expect(find.text('Pagada'), findsOneWidget);
    expect(find.textContaining('La recibió Ana López'), findsOneWidget);
    expect(DemoPagosVisita.resultados.value['cita-1']?.arquitecto, 'Ana López');

    // Reiniciar deja la tarjeta como al principio.
    await tocar(tester, const Key('reiniciarDemoVisita'));
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('antes de llegar el arquitecto: transferencia a su cuenta hasta el QR', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final antes = PagoVisita.fromJson({...json, 'transferencia': null, 'transferenciaAlLlegar': true});
    expect(antes.aceptaTransferencia, isFalse);
    expect(antes.transferenciaAlLlegar, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: [TarjetaPagoVisita(cita: cita, pago: antes)]),
        ),
      ),
    );
    await tocar(tester, const Key('pagarVisita'));
    expect(find.byKey(const Key('metodoTransferencia')), findsNothing);
    expect(find.byKey(const Key('metodoTransferenciaAlLlegar')), findsOneWidget);
    expect(find.textContaining('cuando llegue y escanee el QR'), findsOneWidget);
    // El efectivo sigue disponible.
    expect(find.byKey(const Key('metodoEfectivo')), findsOneWidget);
  });
}
