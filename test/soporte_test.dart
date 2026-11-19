// Modo soporte (2026-11-17): "Ver como cliente" desde el ERP.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/session_store.dart';
import 'package:moblar_clientes/main.dart';
import 'package:moblar_clientes/state/app_state.dart';
import 'package:moblar_clientes/util/soporte.dart';

import 'fixtures/servidor_falso.dart';

void main() {
  const pase = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.ZmlybWE';

  group('tokenSoporteDe', () {
    test('lee el pase del fragmento en sus formas', () {
      for (final f in ['soporte=$pase', '/soporte=$pase', '/?soporte=$pase']) {
        expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/#$f')), pase, reason: f);
      }
    });

    test('sin pase, o con algo que no es un pase, nada', () {
      expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/')), isNull);
      expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/#/')), isNull);
      expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/#soporte=')), isNull);
      expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/#soporte=abc')), isNull);
      expect(tokenSoporteDe(Uri.parse('https://erp.test/clientes/#soporte=a.b.c<script>')), isNull);
    });
  });

  group('AppState en soporte', () {
    test('entra con el pase en memoria y, al vencer, avisa que fue el modo soporte', () async {
      final servidor = ServidorFalso();
      final store = MemorySessionStore()..token = 'tok-1';
      final state = AppState(
        api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
        store: store,
        soporte: true,
      );
      await state.arrancar();
      expect(state.estado, EstadoApp.conSesion);
      servidor.revocado = true;
      await state.refrescar();
      expect(state.estado, EstadoApp.sinSesion);
      expect(state.aviso, mensajeSoporteTerminado);
      expect(store.token, isNull);
    });

    test('fuera de soporte el aviso de sesión terminada no cambia', () async {
      final servidor = ServidorFalso();
      final state = AppState(
        api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
        store: MemorySessionStore()..token = 'tok-1',
      );
      await state.arrancar();
      servidor.revocado = true;
      await state.refrescar();
      expect(state.aviso, const SesionTerminada().mensaje);
    });
  });

  testWidgets('la franja de solo lectura se ve en soporte y no fuera de él', (tester) async {
    Future<void> montar(bool soporte) async {
      final servidor = ServidorFalso();
      final state = AppState(
        api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
        store: MemorySessionStore(),
        soporte: soporte,
      );
      await state.arrancar();
      await tester.pumpWidget(MoblarClientesApp(state: state));
      await tester.pumpAndSettle();
    }

    await montar(true);
    expect(find.text(textoFranjaSoporte), findsOneWidget);
    expect(find.byType(FranjaSoporte), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await montar(false);
    expect(find.text(textoFranjaSoporte), findsNothing);
  });
}
