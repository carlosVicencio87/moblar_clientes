// Abonar con tarjeta (link de Clip): llamadas al ERP, pago pendiente que
// sobrevive a recargar la página, y la pantalla con el desglose.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/data/session_store.dart';
import 'package:moblar_clientes/state/app_scope.dart';
import 'package:moblar_clientes/state/app_state.dart';
import 'package:moblar_clientes/ui/abono_tarjeta_page.dart';

import 'fixtures/inicio_fixture.dart';

const _link = '2cbf5775-1cdd-4601-9712-c4a6ab7fa6f5';

http.Response _json(Object cuerpo, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Servidor falso con las reglas del ERP (mínimo $1,000, saldo $6,000).
class _Servidor {
  String estado = 'pendiente';
  bool registrado = false;
  final pedidos = <Map<String, dynamic>>[];

  late final client = MockClient((r) async {
    if (r.headers['Authorization'] != 'Bearer tok-1') return _json({}, 401);
    if (r.url.path == '/api/cliente/inicio') return http.Response.bytes(utf8.encode(inicioJson), 200);
    if (r.url.path == '/api/cliente/proyectos/compra-1/pago-tarjeta') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      pedidos.add(b);
      final liquidar = b['liquidar'] == true;
      final monto = (b['monto'] as num?) ?? 0;
      if (!liquidar && monto < 1000) return _json({'error': r'El abono mínimo con tarjeta es $1,000.00.'}, 422);
      final d = liquidar
          ? {'neto': 6000, 'cobro': 6216.33, 'comision': 216.33, 'liquida': true, 'saldo': 6000}
          : {'neto': 5000, 'cobro': 5180.28, 'comision': 180.28, 'liquida': false, 'saldo': 6000};
      if (b['cotizar'] == true) return _json(d, 200);
      return _json({...d, 'id': _link, 'url': 'https://completa-tu-pago.payclip.com/$_link', 'ticket': 'tkt', 'expira': null}, 200);
    }
    if (r.url.path == '/api/cliente/pagos-tarjeta/$_link') {
      if (r.url.queryParameters['t'] != 'tkt') return _json({'error': 'Pago no encontrado.'}, 404);
      return _json({'estado': estado, 'recibo': estado == 'pagado' ? 'EyCtYWF' : null, 'registrado': registrado}, 200);
    }
    return _json({}, 404);
  });
}

void main() {
  late _Servidor servidor;
  late MemoryPagoPendienteStore pagos;
  late AppState state;

  setUp(() async {
    servidor = _Servidor();
    pagos = MemoryPagoPendienteStore();
    state = AppState(
      api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
      store: MemorySessionStore()..token = 'tok-1',
      pagos: pagos,
    );
    await state.arrancar();
  });

  group('llamadas', () {
    test('cotizar: desglose del servidor, sin crear link', () async {
      final c = await state.cotizarAbono('compra-1', monto: 5000);
      expect(c.neto, 5000);
      expect(c.cobro, 5180.28);
      expect(c.comision, 180.28);
      expect(servidor.pedidos.last, {'monto': 5000, 'liquidar': false, 'cotizar': true});
      expect(pagos.pago, isNull);
    });

    test('monto fuera de regla: AbonoInvalido con el motivo del servidor', () async {
      await expectLater(
        state.cotizarAbono('compra-1', monto: 500),
        throwsA(isA<AbonoInvalido>().having((e) => e.mensaje, 'mensaje', contains('mínimo'))),
      );
    });

    test('crear: guarda el pago pendiente antes de abrir Clip', () async {
      final l = await state.crearPagoTarjeta('compra-1', monto: 5000);
      expect(l.url, startsWith('https://completa-tu-pago.payclip.com/'));
      expect(pagos.pago?.id, _link);
      expect(pagos.pago?.neto, 5000);
      expect(servidor.pedidos.last['cotizar'], isFalse);
    });
  });

  group('revisar el pago al regresar de Clip', () {
    setUp(() async => state.crearPagoTarjeta('compra-1', monto: 5000));

    test('pendiente: se conserva y no hay aviso', () async {
      final e = await state.revisarPagoPendiente();
      expect(e?.pendiente, isTrue);
      expect(pagos.pago, isNotNull);
      expect(state.avisoPago, isNull);
    });

    test('pagado (fase de pruebas): aviso con recibo y aclaración; se olvida', () async {
      servidor.estado = 'pagado';
      await state.revisarPagoPendiente();
      expect(state.avisoPago, contains(r'$5,000.00'));
      expect(state.avisoPago, contains('EyCtYWF'));
      expect(state.avisoPago, contains('todavía no se suma'));
      expect(pagos.pago, isNull);
      state.cerrarAvisoPago();
      expect(state.avisoPago, isNull);
    });

    test('pagado y registrado: aviso de que ya está en el estado de cuenta', () async {
      servidor
        ..estado = 'pagado'
        ..registrado = true;
      await state.revisarPagoPendiente();
      expect(state.avisoPago, contains('Ya está en tu estado de cuenta'));
    });

    test('vencido: aviso y se olvida', () async {
      servidor.estado = 'vencido';
      await state.revisarPagoPendiente();
      expect(state.avisoPago, contains('venció'));
      expect(pagos.pago, isNull);
    });

    test('al arrancar la app (regreso a la pestaña) se revisa solo', () async {
      servidor.estado = 'pagado';
      final otra = AppState(
        api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
        store: MemorySessionStore()..token = 'tok-1',
        pagos: pagos,
      );
      await otra.arrancar();
      expect(otra.avisoPago, contains('Recibimos tu pago'));
    });

    test('salir borra el pago pendiente', () async {
      await state.salir();
      expect(pagos.pago, isNull);
    });
  });

  group('modelo', () {
    test('compra con o sin pago con tarjeta', () {
      expect(Compra.fromJson(const {'id': 'x'}).pagoTarjeta, isNull);
      expect(Compra.fromJson(const {'id': 'x', 'pagoTarjeta': {'abonoMinimo': 1000}}).pagoTarjeta?.abonoMinimo, 1000);
    });
    test('pago pendiente incompleto no se usa', () {
      expect(PagoPendiente.fromJson(const {'id': 'a'}), isNull);
      final p = PagoPendiente.fromJson(const {'id': 'a', 'ticket': 't', 'compraId': 'c', 'neto': 1, 'cobro': 2});
      expect(p?.toJson(), {'id': 'a', 'ticket': 't', 'compraId': 'c', 'neto': 1, 'cobro': 2});
    });
  });

  group('pantalla', () {
    final compra = Compra.fromJson(const {
      'id': 'compra-1',
      'codigo': '296754',
      'mueble': 'Clóset',
      'cuenta': {'subtotal': 10000, 'iva': 0, 'total': 10000, 'pagado': 4000, 'enRevision': 0, 'saldo': 6000, 'conFactura': false},
      'pagoTarjeta': {'abonoMinimo': 1000},
    });

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(home: AbonoTarjetaPage(compra: compra, espera: Duration.zero, intervalo: const Duration(hours: 1))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('escribe el abono y ve el desglose; recuerda que sin tarjeta no hay comisión', (tester) async {
      await abrir(tester);
      expect(find.byKey(const Key('sinComision')), findsOneWidget);
      expect(find.text(r'$6,000.00'), findsWidgets);
      await tester.enterText(find.byKey(const Key('montoAbono')), '5000');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desgloseAbono')), findsOneWidget);
      expect(find.text(r'$5,000.00'), findsOneWidget);
      expect(find.text(r'$180.28'), findsOneWidget);
      expect(find.text(r'Pagar $5,180.28 con tarjeta'), findsOneWidget);
    });

    testWidgets('abajo del mínimo: el motivo y sin botón de pagar', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byKey(const Key('montoAbono')), '500');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('errorAbono')), findsOneWidget);
      expect(find.byKey(const Key('pagarTarjeta')), findsNothing);
    });

    testWidgets('liquidar: el saldo completo', (tester) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('liquidarSaldo')));
      await tester.pumpAndSettle();
      expect(find.text('Se liquida tu saldo'), findsOneWidget);
      expect(find.text(r'Pagar $6,216.33 con tarjeta'), findsOneWidget);
    });

    testWidgets('pagar: genera el link, queda en curso y se puede cancelar', (tester) async {
      await abrir(tester);
      await tester.enterText(find.byKey(const Key('montoAbono')), '5000');
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pagarTarjeta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pagoEnCurso')), findsOneWidget);
      expect(pagos.pago?.id, _link);
      servidor.estado = 'pagado';
      await tester.tap(find.byKey(const Key('revisarPago')));
      await tester.pumpAndSettle();
      expect(find.text('¡Pago recibido!'), findsOneWidget);
      expect(pagos.pago, isNull);
    });
  });
}
