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
import 'package:moblar_clientes/ui/widgets/detalle_mueble.dart';

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
    // Saldo de cada compra en su propia tarjeta (no sumado entre muebles).
    expect(find.byKey(const Key('saldoCompra')), findsOneWidget);
    // Porcentaje del ERP, grande, seguimiento en miniatura (no barra lisa)
    // y contacto directo en cada tarjeta.
    expect(find.text('58%'), findsOneWidget);
    expect(find.byKey(const Key('seguimientoMini')), findsWidgets);
    expect(
      find.descendant(of: find.byType(TarjetaCompra), matching: find.byType(LinearProgressIndicator)),
      findsNothing,
    );
    // La entregada va después: se baja para verla y se regresa.
    final listaCompras = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('100%'), 300, scrollable: listaCompras);
    expect(find.text('ENTREGADAS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('EN PROCESO'), -300, scrollable: listaCompras);
    await tester.pumpAndSettle();
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
    // En Seguimiento ya no hay barra: el % va junto a cada bolita de la
    // línea de tiempo (la actual con el avance real, las demás con su meta).
    Finder enDetalle(Finder f) => find.descendant(of: find.byType(CompraDetallePage), matching: f);
    expect(enDetalle(find.byKey(const Key('avancePorcentaje'))), findsNothing);
    expect(enDetalle(find.byKey(const Key('seguimientoMini'))), findsNothing);
    expect(enDetalle(find.text('58%')), findsOneWidget);
    expect(enDetalle(find.text('15%')), findsOneWidget);
    expect(enDetalle(find.text('35%')), findsOneWidget);
    expect(enDetalle(find.text('80%')), findsOneWidget);
    expect(enDetalle(find.text('95%')), findsOneWidget);
    expect(enDetalle(find.text('100%')), findsOneWidget);
    expect(find.byType(LineaTiempoVertical), findsOneWidget);
    expect(find.text('Control de calidad'), findsOneWidget);
    // Tonos y lo que incluye, pedidos al servidor al abrir el detalle.
    final listaCompra = find
        .descendant(of: find.byType(CompraDetallePage), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(const Key('tonosMueble')), 200, scrollable: listaCompra);
    expect(find.text('Nogal Terracota'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('incluyeMueble')), 200, scrollable: listaCompra);
    expect(find.text('Lo que incluye tu pedido'), findsOneWidget);
    expect(find.text('Medidas generales: 240 × 180 cm'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Chimenea'), 200, scrollable: listaCompra);
    expect(find.text('Alacena × 2'), findsOneWidget);
    expect(find.text('CORRE POR TU CUENTA'), findsOneWidget);
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
    expect(find.byKey(const Key('agendarNuevaCita')), findsOneWidget);
    expect(find.text('TU PRÓXIMA CITA'), findsOneWidget);

    expect(find.byKey(const Key('citaDestacada')), findsOneWidget);
    expect(find.text('AL'), findsOneWidget); // iniciales de Ana López, sin foto

    await tester.tap(find.byKey(const Key('citaDestacada')));
    await tester.pumpAndSettle();
    expect(find.byType(CitaDetallePage), findsOneWidget);
    expect(find.text('TU ARQUITECTO'), findsOneWidget);
    expect(find.text('Agendó tu cita: Estela Ramírez'), findsOneWidget);
    // La lista construye solo lo visible: se desplaza para ver cada parte.
    final lista = find
        .descendant(of: find.byType(CitaDetallePage), matching: find.byType(Scrollable))
        .first;

    // Habilidades: plegadas; al abrir, estrellas solo donde hay datos.
    await tester.scrollUntilVisible(
      find.byKey(const Key('habilidadesArquitecto')), 200, scrollable: lista);
    expect(find.text('Creatividad en diseños'), findsNothing);
    await tester.tap(find.byKey(const Key('habilidadesArquitecto')));
    await tester.pumpAndSettle();
    expect(find.text('Creatividad en diseños'), findsOneWidget);
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget); // 4.5
    expect(find.text('Sin calificar'), findsNWidgets(2)); // puntualidad y atención
    // Al final del desplegable: contacto directo y discreto con el arquitecto.
    await tester.scrollUntilVisible(
      find.byKey(const Key('contactoArquitecto')), 200, scrollable: lista);
    expect(find.text('Contacta a tu arquitecto'), findsOneWidget);
    expect(find.byKey(const Key('arquitectoLlamar')), findsOneWidget);
    expect(find.byKey(const Key('arquitectoWhatsApp')), findsOneWidget);

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

  testWidgets('estado de cuenta dentro de la compra, con la visita abonada', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.byKey(const Key('abrirCompra')).first);
    await tester.pumpAndSettle();
    final lista = find
        .descendant(of: find.byType(CompraDetallePage), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byKey(const Key('estadoCuentaCompra')), 200, scrollable: lista);
    expect(find.text('Saldo pendiente'), findsOneWidget);
    expect(find.byKey(const Key('visitaAbonada')), findsOneWidget);
    expect(find.textContaining('en revisión: se sumará'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Anticipo'), 200, scrollable: lista);
    expect(find.text('Validado'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Incluye costo de la visita (\$500.00)'), findsOneWidget);
  });

  testWidgets('cotización comercial: precio, vigencia, arquitecto e incluye', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.text('Cotizaciones'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('precioCotizacion-q1')), findsOneWidget);
    expect(find.byKey(const Key('etiquetaComercial')), findsWidgets);
    expect(find.text('\$250,000.00'), findsOneWidget);
    expect(find.text('Tu arquitecto: Ana López'), findsOneWidget);
    expect(find.text('Transporte'), findsWidgets);
    expect(find.text('Ver cotización formal'), findsOneWidget);
    // q1 ya está comprada: no muestra vigencia. q2 venció.
    final lista = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Vencida'), 200, scrollable: lista);
    expect(find.textContaining('Venció el'), findsOneWidget);
    expect(find.text('Pedir cotización actualizada'), findsOneWidget);
  });

  testWidgets('desde una cotización se abre el diseño y lo que incluye', (tester) async {
    store.token = 'tok-1';
    await abrirApp(tester);
    await tester.tap(find.text('Cotizaciones'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('verDetalle-q1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verDetalle-q1')));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleMueblePage), findsOneWidget);
    expect(find.text('Tonos'), findsOneWidget);
    expect(find.text('Blanco Brillante'), findsOneWidget);
    expect(find.byKey(const Key('disenoMueble')), findsNothing); // sin imagen
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

    // Sin compras abre directo el detalle de su próxima cita.
    expect(find.byType(CitaDetallePage), findsOneWidget);
    expect(find.text('TU ARQUITECTO'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Al regresar queda en Citas, sin la pestaña Mi compra.
    expect(find.byType(CitaDetallePage), findsNothing);
    expect(find.text('Mi compra'), findsNothing);
    expect(find.text('Citas'), findsOneWidget);
    expect(find.text('Cotizaciones'), findsOneWidget);
    expect(find.text('TU PRÓXIMA CITA'), findsOneWidget);
    // Con citas no hay tarjeta de ayuda repetida: cada cita trae su contacto.
    expect(find.byKey(const Key('preguntarCita-c-futura')), findsOneWidget);
    final lista = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('preguntarCita-c-pasada')), 200, scrollable: lista);
    expect(find.byKey(const Key('tarjetaAyuda')), findsNothing);
  });

  testWidgets('sin compras y sin cita próxima: se queda en Citas', (tester) async {
    final soloPasadas = jsonDecode(inicioJson) as Map<String, dynamic>
      ..['compras'] = <Object>[]
      ..['citas'] = [(jsonDecode(inicioJson) as Map<String, dynamic>)['citas'][1]];
    servidor = ServidorFalso(inicio: jsonEncode(soloPasadas));
    state = AppState(
      api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
      store: store,
    );
    store.token = 'tok-1';
    await abrirApp(tester);

    expect(find.byType(CitaDetallePage), findsNothing);
    expect(find.text('ANTERIORES'), findsOneWidget);
  });

  testWidgets('sección vacía: ahí sí aparece la tarjeta de ayuda', (tester) async {
    final vacio = jsonDecode(inicioJson) as Map<String, dynamic>
      ..['compras'] = <Object>[]
      ..['citas'] = <Object>[]
      ..['cotizaciones'] = <Object>[];
    servidor = ServidorFalso(inicio: jsonEncode(vacio));
    state = AppState(
      api: ClienteApi(client: servidor.client, base: 'https://ejemplo.test', bypass: ''),
      store: store,
    );
    store.token = 'tok-1';
    await abrirApp(tester);

    expect(find.text('Todavía no tienes citas'), findsOneWidget);
    expect(find.text('¿Dudas sobre tus citas?'), findsOneWidget);
  });
}
