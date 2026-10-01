import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';

import 'fixtures/inicio_fixture.dart';

http.Response _json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('entrar', () {
    test('200 devuelve token y manda el código en el cuerpo', () async {
      late http.Request recibida;
      final api = ClienteApi(
        base: 'https://ejemplo.test/',
        bypass: '',
        client: MockClient((r) async {
          recibida = r;
          return _json({'token': 'abc.def.ghi', 'cliente': {'nombre': 'Ana'}}, 200);
        }),
      );
      final s = await api.entrar('K7QM4XRT');
      expect(s.token, 'abc.def.ghi');
      expect(s.nombre, 'Ana');
      expect(recibida.method, 'POST');
      expect(recibida.url.toString(), 'https://ejemplo.test/api/cliente/sesion');
      expect(jsonDecode(recibida.body), {'codigo': 'K7QM4XRT'});
      expect(recibida.headers.containsKey('x-vercel-protection-bypass'), isFalse);
      expect(recibida.headers.containsKey('Authorization'), isFalse);
    });

    test('401 es código inválido', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'error': 'Código incorrecto.'}, 401)),
      );
      await expectLater(api.entrar('K7QM4XRT'), throwsA(isA<CodigoInvalido>()));
    });

    test('429 es demasiados intentos', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({}, 429)),
      );
      await expectLater(api.entrar('K7QM4XRT'), throwsA(isA<DemasiadosIntentos>()));
    });

    test('500 o cuerpo no JSON es error de servidor', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => http.Response('<html>', 500)),
      );
      await expectLater(api.entrar('K7QM4XRT'), throwsA(isA<ErrorServidor>()));
    });

    test('200 sin token es error de servidor', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'ok': true}, 200)),
      );
      await expectLater(api.entrar('K7QM4XRT'), throwsA(isA<ErrorServidor>()));
    });

    test('sin red es SinConexion', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => throw http.ClientException('sin red')),
      );
      await expectLater(api.entrar('K7QM4XRT'), throwsA(isA<SinConexion>()));
    });
  });

  group('inicio', () {
    test('manda Bearer y bypass cuando existe', () async {
      late http.Request recibida;
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: 'secreto-preview',
        client: MockClient((r) async {
          recibida = r;
          return http.Response.bytes(utf8.encode(inicioJson), 200);
        }),
      );
      final inicio = await api.inicio('tok');
      expect(recibida.headers['Authorization'], 'Bearer tok');
      expect(recibida.headers['x-vercel-protection-bypass'], 'secreto-preview');
      // Acentos intactos aunque el servidor no declare charset.
      expect(inicio.compras.last.lineaTiempo.etapas[1].titulo, 'Diseño técnico');
    });

    test('401 es sesión terminada', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'error': 'x'}, 401)),
      );
      await expectLater(api.inicio('tok'), throwsA(isA<SesionTerminada>()));
    });
  });

  group('urlPdf', () {
    test('200 devuelve la URL firmada', () async {
      late http.Request recibida;
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async {
          recibida = r;
          return _json({'url': 'https://storage.test/x.pdf?token=1', 'expiraEnSeg': 300}, 200);
        }),
      );
      final url = await api.urlPdf('tok', 'q1');
      expect(recibida.url.path, '/api/cliente/cotizaciones/q1/pdf');
      expect(url.toString(), 'https://storage.test/x.pdf?token=1');
    });

    test('404 explica que no hay documento', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({}, 404)),
      );
      await expectLater(
        api.urlPdf('tok', 'ajena'),
        throwsA(isA<ErrorServidor>().having((e) => e.mensaje, 'mensaje', contains('documento'))),
      );
    });

    test('401 es sesión terminada', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({}, 401)),
      );
      await expectLater(api.urlPdf('tok', 'q1'), throwsA(isA<SesionTerminada>()));
    });
  });

  group('detalleProyecto', () {
    test('200 arma el detalle y pide la ruta del proyecto', () async {
      late http.Request recibida;
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async {
          recibida = r;
          return http.Response.bytes(utf8.encode(detalleJson), 200);
        }),
      );
      final d = await api.detalleProyecto('tok', 'p-fabricacion');
      expect(recibida.url.path, '/api/cliente/proyectos/p-fabricacion/detalle');
      expect(recibida.headers['Authorization'], 'Bearer tok');
      expect(d.tonos.first.nombre, 'Nogal Terracota');
    });

    test('404 es error con mensaje claro', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'error': 'x'}, 404)),
      );
      expect(
        () => api.detalleProyecto('tok', 'p'),
        throwsA(isA<ErrorServidor>().having((e) => e.mensaje, 'mensaje', contains('detalle'))),
      );
    });

    test('401 es sesión terminada', () async {
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({}, 401)),
      );
      expect(() => api.detalleProyecto('tok', 'p'), throwsA(isA<SesionTerminada>()));
    });
  });

  group('comprobantePago', () {
    test('200 con PDF', () async {
      late http.Request recibida;
      final api = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((r) async {
          recibida = r;
          return _json({'url': 'https://f/x.pdf', 'tipo': 'pdf', 'expiraEnSeg': 300}, 200);
        }),
      );
      final c = await api.comprobantePago('tok', 'pg1');
      expect(recibida.url.path, '/api/cliente/pagos/pg1/comprobante');
      expect(c.esPdf, isTrue);
      expect(c.url.toString(), 'https://f/x.pdf');
    });

    test('imagen y 404', () async {
      final img = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'url': 'https://f/x.jpg', 'tipo': 'imagen'}, 200)),
      );
      expect((await img.comprobantePago('tok', 'p')).esPdf, isFalse);
      final no = ClienteApi(
        base: 'https://ejemplo.test',
        bypass: '',
        client: MockClient((_) async => _json({'error': 'x'}, 404)),
      );
      expect(() => no.comprobantePago('tok', 'p'), throwsA(isA<ErrorServidor>()));
    });
  });
}
