import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/pago_visita.dart';

http.Response _json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Pago REAL de la visita (2026-11-14): solo efectivo con el PIN del
/// arquitecto, después de la propuesta; el estado lo da el ERP.
void main() {
  Map<String, dynamic> pagoJson({String estado = 'pendiente', String? recibio}) => {
        'demo': false,
        'real': true,
        'monto': 500,
        'estado': estado,
        'promesaRegistrada': true,
        'metodos': estado == 'pendiente' ? ['efectivo'] : <String>[],
        'transferencia': null,
        'transferenciaAlLlegar': false,
        'pagadaEl': estado == 'pendiente' || estado == 'incluida' ? null : '2026-11-14T18:00:00.000Z',
        'recibio': recibio,
      };
  Cita cita(Map<String, dynamic> pago) => Cita.fromJson({
        'id': 'cita-1',
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'estado': {'clave': 'realizada', 'titulo': 'Realizada'},
        'arquitecto': 'Luis Pérez',
        'muebles': ['Clóset'],
        'marca': const {},
        'pagoVisita': pago,
      });

  Future<void> tarjeta(WidgetTester tester, Map<String, dynamic> pago) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = cita(pago);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TarjetaPagoVisita(cita: c, pago: c.pagoVisita!))));
    await tester.pumpAndSettle();
  }

  test('modelo: real, estado, cuándo y quién', () {
    final p = PagoVisita.fromJson(pagoJson(estado: 'pagada', recibio: 'Luis Pérez'));
    expect(p.real, isTrue);
    expect(p.demo, isFalse);
    expect(p.pendiente, isFalse);
    expect(p.recibio, 'Luis Pérez');
    expect(p.aceptaEfectivo, isFalse, reason: 'ya pagada: sin métodos');
    final demo = PagoVisita.fromJson({'demo': true, 'monto': 500, 'metodos': ['efectivo']});
    expect(demo.real, isFalse);
    expect(demo.pendiente, isTrue);
  });

  testWidgets('pendiente: botón para pagar, sin aviso de demostración', (tester) async {
    await tarjeta(tester, pagoJson());
    expect(find.byKey(const Key('pagarVisita')), findsOneWidget);
    expect(find.byKey(const Key('avisoDemo')), findsNothing);
    expect(find.textContaining('confirma con su PIN'), findsOneWidget);
  });

  testWidgets('pagada: quién la recibió y que se abona si compra', (tester) async {
    await tarjeta(tester, pagoJson(estado: 'pagada', recibio: 'Luis Pérez'));
    expect(find.text('Pagada'), findsOneWidget);
    expect(find.textContaining('La recibió Luis Pérez'), findsOneWidget);
    expect(find.byKey(const Key('pagarVisita')), findsNothing);
    expect(find.byKey(const Key('reiniciarDemoVisita')), findsNothing);
  });

  testWidgets('aplicada: se abonó a su proyecto', (tester) async {
    await tarjeta(tester, pagoJson(estado: 'aplicada', recibio: 'Luis Pérez'));
    expect(find.text('Este pago se abonó al anticipo de tu proyecto.'), findsOneWidget);
  });

  testWidgets('incluida: compró sin pagarla, va en su anticipo', (tester) async {
    await tarjeta(tester, pagoJson(estado: 'incluida'));
    expect(find.byKey(const Key('visitaSinCosto')), findsOneWidget);
    expect(find.byKey(const Key('pagarVisita')), findsNothing);
  });

  testWidgets('elegir método: solo efectivo', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = cita(pagoJson());
    await tester.pumpWidget(MaterialApp(home: PagarVisitaPage(cita: c, pago: c.pagoVisita!)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('metodoEfectivo')), findsOneWidget);
    expect(find.byKey(const Key('metodoTransferencia')), findsNothing);
    expect(find.byKey(const Key('metodoTransferenciaAlLlegar')), findsNothing);
    expect(find.byKey(const Key('avisoDemo')), findsNothing);
  });

  test('API: PIN y requestId; el monto no lo manda el teléfono', () async {
    late http.Request r0;
    final api = ClienteApi(
      base: 'https://ejemplo.test',
      bypass: '',
      client: MockClient((r) async {
        r0 = r;
        return _json({'mensaje': 'Listo: Luis recibió el pago de tu visita.'}, 200);
      }),
    );
    final m = await api.pagoVisitaEfectivo('tok', 'cita-1', pin: '1234', requestId: 'visita-123456789');
    expect(m, contains('recibió'));
    expect(r0.url.path, '/api/cliente/citas/cita-1/pago-visita');
    expect(jsonDecode(r0.body), {'pin': '1234', 'requestId': 'visita-123456789'});
  });

  test('API: el error del ERP llega con su mensaje', () async {
    final api = ClienteApi(
      base: 'https://ejemplo.test',
      bypass: '',
      client: MockClient((r) async => _json({'error': 'La visita se paga cuando tu arquitecto te entrega su propuesta.'}, 409)),
    );
    await expectLater(
      api.pagoVisitaEfectivo('tok', 'cita-1', pin: '1234', requestId: 'visita-123456789'),
      throwsA(isA<ErrorServidor>().having((e) => e.mensaje, 'mensaje', contains('propuesta'))),
    );
  });
}
