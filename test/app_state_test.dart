import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/session_store.dart';
import 'package:moblar_clientes/state/app_state.dart';

import 'fixtures/servidor_falso.dart';

void main() {
  late ServidorFalso servidor;
  late MemorySessionStore store;
  late AppState state;

  setUp(() {
    servidor = ServidorFalso();
    store = MemorySessionStore();
    state = AppState(
      api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
      store: store,
    );
  });

  test('sin token guardado arranca en ingreso', () async {
    await state.arrancar();
    expect(state.estado, EstadoApp.sinSesion);
    expect(servidor.llamadasInicio, 0);
  });

  test('entrar guarda el token y carga los datos', () async {
    await state.arrancar();
    await state.entrar('K7QM4XRT');
    expect(state.estado, EstadoApp.conSesion);
    expect(store.token, 'tok-1');
    expect(state.datos!.compras, hasLength(2));
  });

  test('código malo no cambia de pantalla ni guarda nada', () async {
    await state.arrancar();
    await expectLater(state.entrar('AAAA2222'), throwsA(isA<CodigoInvalido>()));
    expect(state.estado, EstadoApp.sinSesion);
    expect(store.token, isNull);
  });

  test('con token guardado entra directo', () async {
    store.token = 'tok-1';
    await state.arrancar();
    expect(state.estado, EstadoApp.conSesion);
    expect(state.datos, isNotNull);
  });

  test('código revocado: al refrescar regresa a ingreso con aviso y borra el token', () async {
    store.token = 'tok-1';
    await state.arrancar();
    servidor.revocado = true;
    await state.refrescar();
    expect(state.estado, EstadoApp.sinSesion);
    expect(state.aviso, isNotNull);
    expect(state.datos, isNull);
    expect(store.token, isNull);
  });

  test('salir borra todo sin aviso', () async {
    store.token = 'tok-1';
    await state.arrancar();
    await state.salir();
    expect(state.estado, EstadoApp.sinSesion);
    expect(state.aviso, isNull);
    expect(store.token, isNull);
  });

  test('sin red al arrancar conserva la sesión y muestra el error', () async {
    store.token = 'tok-1';
    final sinRed = AppState(
      api: ClienteApi(
        client: MockClient((_) async => throw http.ClientException('sin red')),
        base: 'https://ejemplo.test',
        bypass: '',
      ),
      store: store,
    );
    await sinRed.arrancar();
    expect(sinRed.estado, EstadoApp.conSesion);
    expect(sinRed.datos, isNull);
    expect(sinRed.errorCarga, const SinConexion().mensaje);
    expect(store.token, 'tok-1'); // sin red no es motivo para sacar al cliente
  });
}
