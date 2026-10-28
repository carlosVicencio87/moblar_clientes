import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/api_client.dart' show AbonoInvalido;
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_oferta.dart' show DemoAnticipos;
import 'package:moblar_clientes/ui/widgets/adquirir_real.dart';
import 'package:moblar_clientes/ui/widgets/oferta_visita.dart';

/// Compra REAL de opciones (2026-10-27): varias opciones y un solo pago,
/// registrada en el ERP; con tarjeta, link real de Clip.
void main() {
  Map<String, dynamic> precios(num contado) => {
        'precioContado': contado,
        'precioLista': contado * 1.5,
        'mensualidad': contado * 1.5 / 24,
        'meses': 24,
        'descuento': contado * 0.5,
        'descuentoPct': 35,
        'precioTarjeta': contado * 1.04,
        'anticipoPct': 50,
        'anticipoContado': contado / 2,
        'anticipoTarjeta': contado * 0.52,
        'apartadoMinimo': contado / 10,
      };
  Map<String, dynamic> oferta({List<Map<String, dynamic>> compras = const []}) => {
        ...precios(1160),
        'citaId': 'cita-1',
        'fechaVisita': '2026-10-26T16:00:00.000Z',
        'muebles': ['Cajonera'],
        'demo': true,
        'emitida': '2026-10-26T16:00:00.000Z',
        'vigenteHasta': '2099-11-10T16:00:00.000Z',
        'vigente': true,
        'marca': {},
        'compraReal': true,
        'compras': compras,
        'transferencia': {'banco': 'BBVA', 'beneficiario': 'Moblar', 'clabe': '012180001234567891', 'concepto': 'ANTICIPO-CITA1'},
        'opciones': [
          {...precios(1160), 'numero': 1, 'notas': 'Nogal'},
          {...precios(2320), 'numero': 2, 'notas': 'Con luz LED'},
        ],
      };
  const compraOpcion2 = {
    'id': 'k-1',
    'fecha': '2026-10-27T05:00:00Z',
    'opciones': [2],
    'modalidad': 'fabricacion',
    'metodo': 'tarjeta',
    'estadoPago': 'validado',
    'total': 2320,
    'pago': 1160,
    'cobro': 1201.67,
  };

  setUp(() => DemoAnticipos.resultados.value = const {});

  test('el modelo lee las compras reales; una rechazada no cuenta', () {
    final o = OfertaVisita.fromJson(oferta(compras: [
      compraOpcion2,
      {...compraOpcion2, 'id': 'k-0', 'opciones': [1], 'estadoPago': 'rechazado'},
    ]));
    expect(o.compraReal, isTrue);
    expect(o.compras, hasLength(2));
    expect(o.opcionesAdquiridas, {2});
    expect(o.opciones[1].compras, hasLength(2), reason: 'cada opción ve las compras de la oferta');
    expect(o.comprasDe(2).single.cubreAnticipo, isTrue);
    expect(o.comprasDe(2).single.resumen, 'Anticipo del 50 % · tarjeta · pagado');
  });

  Future<void> abrirTarjeta(WidgetTester tester, OfertaVisita o) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [TarjetaOfertaVisita(oferta: o, contacto: const Contacto(empresa: 'X', telefono: '', whatsapp: ''))],
        ),
      ),
    ));
  }

  testWidgets('sin compra: un solo botón para adquirir (con casillas adentro)', (tester) async {
    await abrirTarjeta(tester, OfertaVisita.fromJson(oferta()));
    expect(find.byKey(const Key('adquirirReal-cita-1')), findsOneWidget);
    expect(find.text('Adquirir'), findsOneWidget);
    expect(find.byKey(const Key('adquirirOferta-cita-1')), findsNothing, reason: 'el botón de la demo no sale');
    expect(find.byKey(const Key('paraIniciar')), findsNothing);
  });

  testWidgets('opción 2 comprada: abre en ella, con su pago y lo que falta para iniciar', (tester) async {
    await abrirTarjeta(tester, OfertaVisita.fromJson(oferta(compras: [compraOpcion2])));
    expect(find.text('Con luz LED'), findsOneWidget);
    expect(find.text('Adquirida'), findsOneWidget);
    expect(find.byKey(const Key('comprasReales')), findsOneWidget);
    expect(find.byKey(const Key('paraIniciar')), findsOneWidget);
    expect(find.text('Anticipo del 50 % pagado'), findsOneWidget);
    expect(find.text('Firma tu cotización formal'), findsOneWidget);
    expect(find.text('Adquirir otra opción'), findsOneWidget);
  });

  Future<void> abrirPagina(WidgetTester tester, Widget pagina) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: pagina));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  const cot = CotizacionCompra(
    total: 3480,
    pago: 1740,
    cobro: 1740,
    comision: 0,
    liquida: false,
    anticipo: 1740,
    apartadoMinimo: 348,
    faltaFabricacion: 0,
  );

  testWidgets('marca dos opciones y paga una vez por transferencia, con su comprobante', (tester) async {
    final pedidos = <PedidoCompra>[];
    PedidoCompra? registrado;
    String? subidoA;
    ArchivoComprobante? subido;
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 1,
        cotizar: (p) async {
          pedidos.add(p);
          return cot;
        },
        adquirir: (p) async {
          registrado = p;
          return ResultadoCompra(
            compra: CompraOferta(
              id: 'k-9',
              fecha: '',
              opciones: p.opciones,
              modalidad: p.modalidad,
              metodo: p.metodo,
              estadoPago: 'en_revision',
              total: 3480,
              pago: 1740,
            ),
          );
        },
        elegirArchivo: () async =>
            ArchivoComprobante(nombre: 'transferencia.pdf', bytes: Uint8List.fromList([1, 2, 3]), extension: 'pdf'),
        subirComprobante: (id, a) async {
          subidoA = id;
          subido = a;
        },
      ),
    );
    expect(pedidos.last.opciones, [1]);
    await tester.tap(find.byKey(const Key('marcarOpcion-2')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(pedidos.last.opciones, [1, 2]);
    expect(find.byKey(const Key('desgloseCompra')), findsOneWidget);
    expect(find.byKey(const Key('datosTransferenciaCompra')), findsOneWidget);
    expect(find.text('Concepto: ANTICIPO-CITA1'), findsOneWidget);

    FilledButton boton() => tester.widget<FilledButton>(find.byKey(const Key('confirmarCompra')));
    expect(boton().onPressed, isNull, reason: 'sin comprobante no se registra');
    await tester.tap(find.byKey(const Key('adjuntarComprobante')));
    await tester.pumpAndSettle();
    expect(find.text('transferencia.pdf'), findsOneWidget);
    expect(boton().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirmarCompra')));
    await tester.pumpAndSettle();
    expect(registrado?.opciones, [1, 2]);
    expect(registrado?.metodo, 'transferencia');
    expect(registrado?.modalidad, 'fabricacion');
    expect(registrado?.pin, isNull);
    expect(registrado!.requestId.length, greaterThanOrEqualTo(8));
    expect(subidoA, 'k-9', reason: 'el comprobante sube a la compra registrada');
    expect(subido?.extension, 'pdf');
  });

  testWidgets('efectivo: el arquitecto escribe su PIN y queda pagado', (tester) async {
    PedidoCompra? registrado;
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 1,
        cotizar: (p) async => cot,
        adquirir: (p) async {
          registrado = p;
          return ResultadoCompra(
            compra: CompraOferta(
              id: 'k-5',
              fecha: '',
              opciones: p.opciones,
              modalidad: p.modalidad,
              metodo: p.metodo,
              estadoPago: 'validado',
              total: 3480,
              pago: 1740,
            ),
          );
        },
      ),
    );
    await tester.tap(find.byKey(const Key('metodo-efectivo')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    FilledButton boton() => tester.widget<FilledButton>(find.byKey(const Key('confirmarCompra')));
    expect(find.byKey(const Key('pinArquitecto')), findsOneWidget);
    expect(boton().onPressed, isNull, reason: 'sin PIN no se registra');
    await tester.enterText(find.byKey(const Key('pinArquitecto')), '12');
    await tester.pump();
    expect(boton().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('pinArquitecto')), '4321');
    await tester.pump();
    expect(boton().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('confirmarCompra')));
    await tester.pumpAndSettle();
    expect(registrado?.metodo, 'efectivo');
    expect(registrado?.pin, '4321');
    expect(registrado!.toJson(cotizar: false)['pin'], '4321');
    expect(registrado!.toJson(cotizar: true).containsKey('pin'), isFalse, reason: 'cotizar no manda el PIN');
  });

  testWidgets('efectivo con PIN equivocado: avisa y borra el PIN', (tester) async {
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 1,
        cotizar: (p) async => cot,
        adquirir: (p) async => throw const AbonoInvalido('PIN incorrecto. Le quedan 4 intentos.'),
      ),
    );
    await tester.tap(find.byKey(const Key('metodo-efectivo')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('pinArquitecto')), '0000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmarCompra')));
    await tester.pumpAndSettle();
    expect(find.text('PIN incorrecto. Le quedan 4 intentos.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('pinArquitecto'))).controller!.text, isEmpty);
    expect(find.byKey(const Key('adquirirOpciones')), findsOneWidget, reason: 'sigue en la pantalla');
  });

  test('comprobante: tipos y tamaño', () {
    expect(problemaComprobante('foto.JPG', 2000), isNull);
    expect(problemaComprobante('banco.pdf', 2000), isNull);
    expect(problemaComprobante('hoja.xlsx', 2000), isNotNull);
    expect(problemaComprobante('foto.png', 11 * 1024 * 1024), contains('10 MB'));
    expect(problemaComprobante('foto.png', 0), isNotNull);
  });

  testWidgets('transferencia sin comprobante: lo dice y deja subirlo', (tester) async {
    final o = OfertaVisita.fromJson(oferta(compras: [
      {...compraOpcion2, 'metodo': 'transferencia', 'estadoPago': 'en_revision', 'comprobante': false},
    ]));
    expect(o.compras.single.faltaComprobante, isTrue);
    expect(o.compras.single.resumen, 'Anticipo del 50 % · transferencia · falta tu comprobante');
    await abrirTarjeta(tester, o);
    expect(find.byKey(const Key('subirComprobante-k-1')), findsOneWidget);
  });

  test('con comprobante ya no lo pide; el efectivo se lee pagado a tu arquitecto', () {
    final o = OfertaVisita.fromJson(oferta(compras: [
      {...compraOpcion2, 'metodo': 'transferencia', 'estadoPago': 'en_revision', 'comprobante': true},
      {...compraOpcion2, 'id': 'k-2', 'opciones': [1], 'metodo': 'efectivo'},
    ]));
    expect(o.compras.first.faltaComprobante, isFalse);
    expect(o.compras.first.resumen, endsWith('en revisión'));
    expect(o.compras.last.resumen, endsWith('pagado a tu arquitecto'));
  });

  testWidgets('todo el mueble a meses: solo tarjeta y con el plazo; abre el link real de Clip', (tester) async {
    Uri? abierto;
    PedidoCompra? registrado;
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 2,
        cotizar: (p) async => const CotizacionCompra(
          total: 2320,
          pago: 2320,
          cobro: 2900,
          comision: 580,
          liquida: true,
          anticipo: 1160,
          apartadoMinimo: 232,
          faltaFabricacion: 0,
        ),
        adquirir: (p) async {
          registrado = p;
          return ResultadoCompra(
            compra: CompraOferta(
              id: 'k-10',
              fecha: '',
              opciones: p.opciones,
              modalidad: p.modalidad,
              metodo: p.metodo,
              estadoPago: 'pendiente',
              total: 2320,
              pago: 2320,
            ),
            link: LinkPagoTarjeta.fromJson(const {
              'id': '11111111-1111-1111-1111-111111111111',
              'url': 'https://pago.clip.mx/abc',
              'ticket': 't',
              'neto': 2320,
              'cobro': 2900,
            }),
          );
        },
        abrir: (u) async => abierto = u,
      ),
    );
    await tester.tap(find.byKey(const Key('modo-liquidar')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('metodo-meses')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('plazo-6')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text(r'Pagar $2,900.00 con Clip'), findsOneWidget);
    expect(find.byKey(const Key('mensualidadCompra')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmarCompra')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(registrado?.modalidad, 'liquidar');
    expect(registrado?.metodo, 'tarjeta');
    expect(registrado?.plazo, 6);
    expect(abierto.toString(), 'https://pago.clip.mx/abc');
    expect(find.byKey(const Key('esperandoClip')), findsOneWidget);
  });

  testWidgets('el 50 % también a meses; apartar no ofrece meses', (tester) async {
    final pedidos = <PedidoCompra>[];
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 1,
        cotizar: (p) async {
          pedidos.add(p);
          return cot;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('metodo-meses')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('plazo-3')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(pedidos.last.modalidad, 'fabricacion');
    expect(pedidos.last.metodo, 'tarjeta');
    expect(pedidos.last.plazo, 3);

    await tester.tap(find.byKey(const Key('modo-apartado')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('metodo-meses')), findsNothing);
    expect(find.byKey(const Key('plazo-3')), findsNothing);
    await tester.enterText(find.byKey(const Key('montoApartadoReal')), '500');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(pedidos.last.modalidad, 'apartado');
    expect(pedidos.last.metodo, 'tarjeta', reason: 'pasa a una exhibición');
    expect(pedidos.last.plazo, 0);
  });

  test('resumen de las modalidades nuevas', () {
    CompraOferta c(String m, int plazo) => CompraOferta(
          id: 'x', fecha: '', opciones: const [1], modalidad: m, metodo: 'tarjeta',
          estadoPago: 'validado', plazo: plazo, total: 2000, pago: m == 'fabricacion' ? 1000 : 2000);
    expect(c('liquidar', 0).resumen, startsWith('Pago total · tarjeta'));
    expect(c('liquidar', 6).resumen, startsWith('Pago total a 6 meses'));
    expect(c('fabricacion', 12).resumen, startsWith('Anticipo del 50 % a 12 meses'));
    expect(c('liquidar', 0).cubreAnticipo, isTrue);
    expect(c('fabricacion', 12).cubreAnticipo, isTrue);
  });

  testWidgets('apartar: pide el monto antes de cotizar', (tester) async {
    final pedidos = <PedidoCompra>[];
    await abrirPagina(
      tester,
      AdquirirOpcionesPage(
        oferta: OfertaVisita.fromJson(oferta()),
        inicial: 1,
        cotizar: (p) async {
          pedidos.add(p);
          return cot;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('modo-apartado')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('desgloseCompra')), findsNothing);
    await tester.enterText(find.byKey(const Key('montoApartadoReal')), '500');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(pedidos.last.modalidad, 'apartado');
    expect(pedidos.last.monto, 500);
  });

  testWidgets('una cotización formal por opción: cada pestaña con la suya', (tester) async {
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Cotizacion formal(String id, String codigo, int opcion) => Cotizacion.fromJson({
          'id': id,
          'codigo': codigo,
          'citaId': 'cita-1',
          'tienePdf': true,
          'opcion': opcion,
          // El precio no importa: manda el número de opción.
          'precio': 1,
          'marca': <String, dynamic>{},
        });
    final o = OfertaVisita.fromJson(oferta());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TarjetaOfertaVisita(
              oferta: o,
              contacto: const Contacto(empresa: 'X', telefono: '', whatsapp: ''),
              formales: [formal('p-1', '296754', 1), formal('p-2', '296754A', 2)],
            ),
          ],
        ),
      ),
    ));
    expect(find.text('Tu cotización formal ya está lista (folio 296754)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('opcionOferta-2')));
    await tester.pumpAndSettle();
    expect(find.text('Tu cotización formal ya está lista (folio 296754A)'), findsOneWidget);
    expect(find.byKey(const Key('firmarCotizacion-p-2')), findsOneWidget);
  });

  group('pago con tarjeta sin terminar (abrió Clip y regresó sin pagar)', () {
    const sinTerminar = {
      'id': 'k-3',
      'fecha': '2026-10-27T17:00:00Z',
      'opciones': [1, 2],
      'modalidad': 'apartado',
      'metodo': 'tarjeta',
      'estadoPago': 'pendiente',
      'total': 3480,
      'pago': 700,
      'cobro': 725.21,
    };

    test('no aparta las opciones', () {
      final o = OfertaVisita.fromJson(oferta(compras: [sinTerminar]));
      expect(o.opcionesAdquiridas, isEmpty);
      expect(o.tarjetasSinTerminar.single.id, 'k-3');
    });

    testWidgets('la tarjeta lo explica y deja pagar de nuevo', (tester) async {
      await abrirTarjeta(tester, OfertaVisita.fromJson(oferta(compras: [sinTerminar])));
      expect(find.byKey(const Key('pagoSinTerminar')), findsOneWidget);
      expect(find.textContaining('No se te cobró nada'), findsOneWidget);
      expect(find.text('Pagar de nuevo'), findsOneWidget);
      expect(find.text('Adquirida'), findsNothing);
      expect(find.byKey(const Key('comprasReales')), findsNothing);
    });

    testWidgets('desde la espera de Clip se puede elegir otra forma de pago', (tester) async {
      await abrirPagina(
        tester,
        AdquirirOpcionesPage(
          oferta: OfertaVisita.fromJson(oferta()),
          inicial: 1,
          iniciales: const {1, 2},
          cotizar: (p) async => cot,
          adquirir: (p) async => ResultadoCompra(
            compra: CompraOferta(
              id: 'k-11',
              fecha: '',
              opciones: p.opciones,
              modalidad: p.modalidad,
              metodo: p.metodo,
              estadoPago: 'pendiente',
              total: 3480,
              pago: 1740,
            ),
            link: LinkPagoTarjeta.fromJson(const {
              'id': '22222222-2222-2222-2222-222222222222',
              'url': 'https://pago.clip.mx/xyz',
              'ticket': 't',
              'neto': 1740,
              'cobro': 1800,
            }),
          ),
          abrir: (_) async {},
        ),
      );
      final marcada = tester.widget<CheckboxListTile>(find.byKey(const Key('marcarOpcion-2')));
      expect(marcada.value, isTrue, reason: 'retoma las mismas opciones');
      await tester.tap(find.byKey(const Key('metodo-tarjeta')));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('confirmarCompra')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('esperandoClip')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('otraFormaDePago')));
      await tester.tap(find.byKey(const Key('otraFormaDePago')));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('esperandoClip')), findsNothing);
      expect(find.byKey(const Key('adquirirOpciones')), findsOneWidget);
    });
  });
}
