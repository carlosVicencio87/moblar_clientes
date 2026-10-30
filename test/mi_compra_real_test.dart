import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/compras_demo.dart';

/// "Mi compra" con las compras REALES de la app (2026-10-29).
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
  Map<String, dynamic> compra(Map<String, dynamic> cambios) => {
        'id': 'k-1',
        'fecha': '2026-10-28T17:00:00Z',
        'opciones': [2],
        'modalidad': 'fabricacion',
        'metodo': 'transferencia',
        'estadoPago': 'en_revision',
        'factura': true,
        'total': 2320,
        'pago': 1160,
        'comprobante': true,
        ...cambios,
      };
  Inicio inicio({
    List<Map<String, dynamic>> compras = const [],
    List<Map<String, dynamic>> cotizaciones = const [],
    List<Map<String, dynamic>> proyectos = const [],
  }) =>
      Inicio.fromJson({
        'contacto': const {},
        'citas': const [],
        'cotizaciones': cotizaciones,
        'compras': proyectos,
        'ofertasVisita': [
          {
            ...precios(1160),
            'citaId': 'cita-1',
            'fechaVisita': '2026-10-26T16:00:00.000Z',
            'muebles': ['Cajonera'],
            'emitida': '2026-10-26T16:00:00.000Z',
            'vigenteHasta': '2099-11-10T16:00:00.000Z',
            'vigente': true,
            'marca': {},
            'compraReal': true,
            'compras': compras,
            'opciones': [
              {...precios(1160), 'numero': 1},
              {...precios(2320), 'numero': 2},
            ],
          },
        ],
      });

  test('transferencia en revisión: sale en Mi compra con el pago en revisión', () {
    final c = comprasDeLaApp(inicio(compras: [compra({})])).single;
    expect(c.esCompraApp, isTrue);
    expect(c.mueble, 'Cajonera · Opción 2');
    expect(c.cuenta!.pagado, 0);
    expect(c.cuenta!.enRevision, 1160);
    expect(c.cuenta!.saldo, 2320);
    expect(c.lineaTiempo.mensaje, contains('validando tu pago'));
  });

  test('sin comprobante lo pide', () {
    final c = comprasDeLaApp(inicio(compras: [compra({'comprobante': false})])).single;
    expect(c.lineaTiempo.mensaje, contains('Falta tu comprobante'));
  });

  test('pagada, con su cotización formal firmada: anticipo cubierto y folio', () {
    final c = comprasDeLaApp(inicio(
      compras: [compra({'estadoPago': 'validado', 'metodo': 'efectivo'})],
      cotizaciones: [
        {'id': 'p-2', 'codigo': '296754A', 'citaId': 'cita-1', 'tienePdf': true, 'opcion': 2, 'firma': {'fecha': '2026-10-28T18:00:00Z'}, 'marca': {}},
      ],
    )).single;
    expect(c.codigo, '296754A');
    expect(c.cuenta!.pagado, 1160);
    expect(c.cuenta!.saldo, 1160);
    expect(c.lineaTiempo.mensaje, contains('anticipo está cubierto'));
  });

  test('apartado: dice cuánto falta para el 50 %', () {
    final c = comprasDeLaApp(inicio(
      compras: [compra({'estadoPago': 'validado', 'modalidad': 'apartado', 'pago': 500})],
      cotizaciones: [
        {'id': 'p-2', 'codigo': 'X', 'citaId': 'cita-1', 'tienePdf': true, 'opcion': 2, 'firma': {'fecha': '2026-10-28T18:00:00Z'}, 'marca': {}},
      ],
    )).single;
    expect(c.metaFabricacion, 1160);
    expect(c.lineaTiempo.mensaje, contains(r'te faltan $660'));
  });

  test('no salen: rechazada, tarjeta sin terminar ni la que ya es proyecto en marcha', () {
    expect(comprasDeLaApp(inicio(compras: [compra({'estadoPago': 'rechazado'})])), isEmpty);
    expect(comprasDeLaApp(inicio(compras: [compra({'metodo': 'tarjeta', 'estadoPago': 'pendiente'})])), isEmpty);
    final enMarcha = inicio(
      compras: [compra({'estadoPago': 'validado'})],
      cotizaciones: [
        {'id': 'p-2', 'codigo': 'X', 'citaId': 'cita-1', 'tienePdf': true, 'opcion': 2, 'marca': {}},
      ],
      proyectos: [
        {'id': 'p-2', 'codigo': 'X', 'mueble': 'Cajonera', 'lineaTiempo': {}, 'pagos': {}, 'marca': {}},
      ],
    );
    expect(comprasDeLaApp(enMarcha), isEmpty);
  });
}
