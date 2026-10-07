// QR de llegada del arquitecto: la llamada al ERP y la tarjeta en la cita.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';

http.Response _json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _qr = 'MOBLAR-LLEGADA|1|11111111-1111-4111-8111-111111111111|0123456789abcdef0123456789abcdef';

ClienteApi _api(Future<http.Response> Function(http.Request) f) =>
    ClienteApi(base: 'https://ejemplo.test', bypass: '', client: MockClient(f));

void main() {
  group('llegada', () {
    test('listo: trae QR y código; pide la ruta correcta con el token', () async {
      late http.Request recibida;
      final api = _api((r) async {
        recibida = r;
        return _json({
          'estado': 'listo',
          'texto': 'Tu arquitecto llegó. Muéstrale este código para que lo escanee.',
          'qr': _qr,
          'codigo': '123456',
          'expira': '2026-10-07T20:00:00Z',
        }, 200);
      });
      final l = await api.llegada('tok', 'c1');
      expect(recibida.url.path, '/api/cliente/citas/c1/llegada');
      expect(recibida.headers['Authorization'], 'Bearer tok');
      expect(l.listo, isTrue);
      expect(l.qr, _qr);
      expect(l.codigo, '123456');
    });

    test('esperando: sin QR', () async {
      final l = await _api((_) async => _json({'estado': 'esperando', 'texto': 'Va en camino', 'qr': null, 'codigo': null}, 200))
          .llegada('tok', 'c1');
      expect(l.estado, 'esperando');
      expect(l.listo, isFalse);
    });

    test('404 (servidor sin la ruta o cita ajena): no se muestra nada', () async {
      final l = await _api((_) async => _json({'error': 'Cita no encontrada.'}, 404)).llegada('tok', 'x');
      expect(l.estado, 'no_aplica');
    });

    test('401 es sesión terminada; 500 es error', () async {
      expect(() => _api((_) async => _json({}, 401)).llegada('tok', 'c1'), throwsA(isA<SesionTerminada>()));
      expect(() => _api((_) async => _json({}, 500)).llegada('tok', 'c1'), throwsA(isA<ErrorServidor>()));
    });

    test('respuesta incompleta no rompe', () {
      final l = LlegadaCita.fromJson(const {'estado': 'listo'});
      expect(l.listo, isFalse, reason: 'sin QR ni código no se muestra un QR vacío');
      expect(LlegadaCita.fromJson(const {}).estado, 'no_aplica');
    });
  });
}
