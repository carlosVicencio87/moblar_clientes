import 'dart:convert';

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

import 'fixtures/inicio_fixture.dart';
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
    // Porcentaje del ERP, grande, y contacto directo en cada tarjeta.
    expect(find.text('58%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TarjetaCompra).first,
        matching: find.byKey(const Key('contactoWhatsApp')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('abrirCompra')).first);
    await tester.pumpAndSettle();
    expect(find.byType(CompraDetallePage), findsOneWidget);
    expect(find.text('Pedido P-0002'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CompraDetallePage), matching: find.text('58%')),
      findsOneWidget,
    );
    expect(find.byType(LineaTiempoVertical), findsOneWidget);
    expect(find.text('Control de calidad'), findsOneWidget);
    // Montos apagados: no aparece la tarjeta de pagos.
    expect(find.text('Pagos'), findsNothing);
  });

  testWidgets('si revocan el código, cualquier pantalla regresa al ingreso con aviso', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.byKey(const Key('abrirCompra')).first);
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
    expect(find.text('TU ARQUITECTO'), findsOneWidget);
    // La lista construye solo lo visible: se desplaza para ver cada parte.
    final lista = find
        .descendant(of: find.byType(CitaDetallePage), matching: find.byType(Scrollable))
        .first;

    // Habilidades: plegadas; al abrir, estrellas solo donde hay datos.
    await tester.scrollUntilVisible(
      find.byKey(const Key('habilidadesArquitecto')), 200, scrollable: lista);
    expect(find.text('Precisión en medidas'), findsNothing);
    await tester.tap(find.byKey(const Key('habilidadesArquitecto')));
    await tester.pumpAndSettle();
    expect(find.text('Precisión en medidas'), findsOneWidget);
    expect(find.text('18 de 20 proyectos sin corrección de medidas.'), findsOneWidget);
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget); // 4.5
    expect(find.text('Sin calificar'), findsNWidgets(2)); // puntualidad y atención

    await tester.scrollUntilVisible(find.text('Ver en Maps'), 200, scrollable: lista);
    expect(find.text('Av. Siempre Viva 742, CDMX'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('contactoCita')), 200, scrollable: lista);
    expect(find.byKey(const Key('contactoCita')), findsOneWidget);
    expect(find.text('¿Necesitas cambiar tu cita?'), findsOneWidget);
    // pageBack() busca el tooltip en inglés ("Back"); la app está en español.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cotizaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Cotización 000135'), findsOneWidget);

    expect(find.byKey(const Key('preguntarCotizacion-q1')), findsOneWidget);

    // Ya no existe la pestaña Atención: el contacto vive en cada sección.
    expect(find.text('Atención'), findsNothing);
    expect(find.text('Mi compra'), findsOneWidget);
  });

  testWidgets('sin compras no aparece la pestaña Mi compra', (tester) async {
    final sinCompras = jsonDecode(inicioJson) as Map<String, dynamic>
      ..['compras'] = <Object>[];
    servidor = ServidorFalso(inicio: jsonEncode(sinCompras));
    state = AppState(
      api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
      store: store,
    );
    store.token = 'tok-1';
    await abrirApp(tester);

    expect(find.text('Mi compra'), findsNothing);
    expect(find.text('Citas'), findsOneWidget);
    expect(find.text('Cotizaciones'), findsOneWidget);
    // Abre en Citas y trae su tarjeta de ayuda.
    expect(find.text('TU PRÓXIMA CITA'), findsOneWidget);
    final lista = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const Key('tarjetaAyuda')), 200, scrollable: lista);
    expect(find.text('¿Dudas sobre tus citas?'), findsOneWidget);
  });
}
