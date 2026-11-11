import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_real.dart' show ArchivoComprobante;
import 'package:moblar_clientes/ui/widgets/pago_visita.dart' show EfectivoPinPage, TransferenciaPagoPage;

http.Response _json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Abonos reales desde la app (2026-11-11): tarjeta, efectivo con PIN y
/// transferencia con comprobante, todos registrados en el ERP.
void main() {
  group('modelo', () {
    test('formas de abonar que manda el ERP', () {
      final o = OpcionesAbono.fromJson({
        'tarjeta': {'abonoMinimo': 1000},
        'efectivo': {'arquitecto': 'Arq Uno'},
        'transferencia': {'banco': 'Banco', 'beneficiario': 'Moblar', 'clabe': '012345678901234567', 'concepto': 'ABONO-296754'},
      })!;
      expect(o.tarjeta?.abonoMinimo, 1000);
      expect(o.efectivo, isTrue);
      expect(o.arquitecto, 'Arq Uno');
      expect(o.transferencia?.concepto, 'ABONO-296754');
      // Sin ninguna forma: null.
      expect(OpcionesAbono.fromJson({'tarjeta': null, 'efectivo': null, 'transferencia': null}), isNull);
      expect(OpcionesAbono.fromJson(null), isNull);
    });
  });

  group('API', () {
    test('efectivo: método, monto, PIN y requestId', () async {
      late http.Request r0;
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async {
          r0 = r;
          return _json({'ok': true, 'mensaje': 'Listo: tu arquitecto confirmó tu abono en efectivo.'}, 200);
        }),
      );
      final m = await api.abonoEfectivo('tok', 'p-1', monto: 1500, pin: '1234', requestId: 'abono-123456789');
      expect(m, contains('confirmó'));
      expect(r0.url.path, '/api/cliente/proyectos/p-1/abonos');
      expect(jsonDecode(r0.body), {'metodo': 'efectivo', 'monto': 1500, 'liquidar': false, 'pin': '1234', 'requestId': 'abono-123456789'});
    });

    test('efectivo: PIN incorrecto llega como error con el mensaje del ERP', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async => _json({'error': 'PIN incorrecto. Te quedan 4 intentos.'}, 422)),
      );
      await expectLater(
        api.abonoEfectivo('tok', 'p-1', liquidar: true, pin: '0000', requestId: 'abono-123456789'),
        throwsA(isA<ErrorServidor>().having((e) => e.mensaje, 'mensaje', contains('PIN incorrecto'))),
      );
    });

    test('transferencia: registra, sube y confirma', () async {
      final pasos = <String>[];
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async {
          if (r.method == 'PUT') {
            pasos.add('PUT ${r.url.host} ${r.headers['Content-Type']}');
            return http.Response('', 200);
          }
          pasos.add('POST ${r.url.path}');
          if (r.url.path.endsWith('/comprobante')) return _json({'ok': true, 'mensaje': 'Recibimos tu comprobante.'}, 200);
          return _json({'ok': true, 'abonoId': 'ab-1', 'ruta': 'abonos/ab-1/comprobante-1.jpg', 'url': 'https://almacen.test/x'}, 200);
        }),
      );
      final m = await api.abonoTransferencia('tok', 'p-1',
          monto: 2000, requestId: 'abono-123456789', bytes: Uint8List.fromList([1, 2]), extension: 'jpg');
      expect(m, 'Recibimos tu comprobante.');
      expect(pasos, [
        'POST /api/cliente/proyectos/p-1/abonos',
        'PUT almacen.test image/jpeg',
        'POST /api/cliente/abonos/ab-1/comprobante',
      ]);
    });
  });

  group('pantallas', () {
    Future<void> abrir(WidgetTester t, Widget pagina) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => pagina)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
    }

    Future<void> teclear(WidgetTester t, String pin) async {
      for (final d in pin.split('')) {
        await t.tap(find.text(d).last);
        await t.pump();
      }
    }

    testWidgets('efectivo: el ERP valida el PIN; si falla, se ve el motivo', (t) async {
      var intentos = 0;
      var confirmado = false;
      await abrir(
        t,
        EfectivoPinPage(
          titulo: 'Abono en efectivo',
          monto: 1500,
          arquitecto: 'Arq Uno',
          demo: false,
          onConfirmado: () => confirmado = true,
          confirmarReal: (pin) async {
            intentos++;
            if (pin == '0000') throw const ErrorServidor('PIN incorrecto. Te quedan 4 intentos.');
            return 'Listo: tu arquitecto confirmó tu abono en efectivo.';
          },
        ),
      );
      await t.tap(find.byKey(const Key('turnoArquitecto')));
      await t.pumpAndSettle();
      await teclear(t, '0000');
      await t.tap(find.byKey(const Key('pinConfirmar')));
      await t.pumpAndSettle();
      expect(find.text('PIN incorrecto. Te quedan 4 intentos.'), findsOneWidget);
      expect(confirmado, isFalse);
      await teclear(t, '1234');
      await t.tap(find.byKey(const Key('pinConfirmar')));
      await t.pumpAndSettle();
      expect(intentos, 2);
      expect(confirmado, isTrue);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('transferencia: elige el comprobante, lo sube y regresa', (t) async {
      ArchivoComprobante? subido;
      await abrir(
        t,
        TransferenciaPagoPage(
          titulo: 'Abono por transferencia',
          monto: 2000,
          datos: const DatosTransferencia(banco: 'Banco', beneficiario: 'Moblar', clabe: '012345678901234567', concepto: 'ABONO-296754'),
          demo: false,
          paraQue: 'del abono a tu mueble',
          onEnviado: (_) {},
          elegirArchivo: () async => ArchivoComprobante(nombre: 'recibo.jpg', bytes: Uint8List.fromList([1]), extension: 'jpg'),
          enviarReal: (a) async {
            subido = a;
            return 'Recibimos tu comprobante.';
          },
        ),
      );
      expect(find.text('Datos de ejemplo: aún no se configura la cuenta real.'), findsNothing);
      await t.tap(find.byKey(const Key('elegirComprobante')));
      await t.pumpAndSettle();
      expect(find.text('recibo.jpg'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('enviarComprobante')));
      await t.tap(find.byKey(const Key('enviarComprobante')));
      await t.pumpAndSettle();
      expect(subido?.nombre, 'recibo.jpg');
      expect(find.text('abrir'), findsOneWidget);
      expect(find.text('Recibimos tu comprobante.'), findsOneWidget);
    });
  });
}
