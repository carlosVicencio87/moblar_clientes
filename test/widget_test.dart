import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/session_store.dart';
import 'package:moblar_clientes/main.dart';
import 'package:moblar_clientes/state/app_state.dart';
import 'package:moblar_clientes/ui/cita_detalle_page.dart';
import 'package:moblar_clientes/ui/compra_detalle_page.dart';
import 'package:moblar_clientes/ui/compras_tab.dart';
import 'package:moblar_clientes/ui/login_page.dart';

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

  Future<void> abrirApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MoblarClientesApp(state: state));
    await tester.runAsync(state.arrancar);
    await tester.pumpAndSettle();
  }

  FilledButton botonEntrar(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('botonEntrar')));

  testWidgets('el campo da formato al código y habilita Entrar al completarlo', (tester) async {
    await abrirApp(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(botonEntrar(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('campoCodigo')), 'k7qm4x');
    await tester.pump();
    expect(find.text('K7QM-4X'), findsOneWidget);
    expect(botonEntrar(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('campoCodigo')), 'k7qm 4xrt');
    await tester.pump();
    expect(find.text('K7QM-4XRT'), findsOneWidget);
    expect(botonEntrar(tester).onPressed, isNotNull);
  });

  testWidgets('los caracteres fuera del alfabeto no se escriben', (tester) async {
    await abrirApp(tester);
    await tester.enterText(find.byKey(const Key('campoCodigo')), 'O0I1L-K7');
    await tester.pump();
    expect(find.text('K7'), findsOneWidget);
  });

  testWidgets('código incorrecto muestra el error y se queda en ingreso', (tester) async {
    await abrirApp(tester);
    await tester.enterText(find.byKey(const Key('campoCodigo')), 'AAAA2222');
    await tester.pump();
    await tester.tap(find.byKey(const Key('botonEntrar')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('mensajeLogin')), findsOneWidget);
    expect(store.token, isNull);
  });

  testWidgets('entrar abre Mi compra y el detalle muestra la línea de tiempo', (tester) async {
    await abrirApp(tester);
    await tester.enterText(find.byKey(const Key('campoCodigo')), 'K7QM4XRT');
    await tester.pump();
    await tester.tap(find.byKey(const Key('botonEntrar')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(store.token, 'tok-1');
    // Con compras, la app abre en "Mi compra" y la que está en curso va primero.
    expect(find.text('EN PROCESO'), findsOneWidget);
    expect(find.byType(TarjetaCompra), findsNWidgets(2));

    await tester.tap(find.byType(TarjetaCompra).first);
    await tester.pumpAndSettle();
    expect(find.byType(CompraDetallePage), findsOneWidget);
    expect(find.text('Pedido P-0002'), findsOneWidget);
    expect(find.byType(LineaTiempoVertical), findsOneWidget);
    expect(find.text('Control de calidad'), findsOneWidget);
    // Montos apagados: no aparece la tarjeta de pagos.
    expect(find.text('Pagos'), findsNothing);
  });

  testWidgets('si revocan el código, cualquier pantalla regresa al ingreso con aviso', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.byType(TarjetaCompra).first);
    await tester.pumpAndSettle();
    expect(find.byType(CompraDetallePage), findsOneWidget);

    servidor.revocado = true;
    await tester.runAsync(state.refrescar);
    await tester.pumpAndSettle();

    expect(find.byType(CompraDetallePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('mensajeLogin')), findsOneWidget);
    expect(store.token, isNull);
  });

  testWidgets('la barra inferior cambia de sección', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.text('Citas'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Carlos'), findsOneWidget);
    expect(find.text('TU PRÓXIMA CITA'), findsOneWidget);

    expect(find.byKey(const Key('citaDestacada')), findsOneWidget);
    expect(find.text('AL'), findsOneWidget); // iniciales de Ana López, sin foto

    await tester.tap(find.byKey(const Key('citaDestacada')));
    await tester.pumpAndSettle();
    expect(find.byType(CitaDetallePage), findsOneWidget);
    expect(find.text('Tu arquitecto'), findsOneWidget);
    // La lista construye solo lo visible: se desplaza hasta el final.
    final lista = find
        .descendant(of: find.byType(CitaDetallePage), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(const Key('botonReagendar')), 200, scrollable: lista);
    expect(find.byKey(const Key('botonReagendar')), findsOneWidget);
    expect(find.text('Av. Siempre Viva 742, CDMX'), findsOneWidget);
    expect(find.text('Ver en Maps'), findsOneWidget);
    // pageBack() busca el tooltip en inglés ("Back"); la app está en español.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cotizaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Cotización 000135'), findsOneWidget);

    await tester.tap(find.text('Atención'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('botonWhatsApp')), findsOneWidget);
    expect(find.text('Llamar al 55 3076 8296'), findsOneWidget);
  });
}
