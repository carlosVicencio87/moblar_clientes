import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/adquirir_real.dart';

/// Pago a meses (2026-11-10): antes del link, 3 firmas con PIN en el ERP.
void main() {
  Map<String, dynamic> compra(Map<String, dynamic>? msi, {String estado = 'pendiente'}) => {
        'id': 'k1',
        'fecha': '2026-11-10T16:00:00Z',
        'opciones': [1],
        'modalidad': 'liquidar',
        'metodo': 'tarjeta',
        'estadoPago': estado,
        'plazo': 12,
        'total': 20000,
        'pago': 20000,
        'cobro': 23000,
        'msi': msi,
      };
  const enRevision = {
    'estado': 'en_revision',
    'titulo': 'En revisión',
    'mensaje': 'Estamos revisando tu pago a meses sin intereses.',
    'puedePagar': false,
    'enCola': false,
  };
  const lista = {
    'estado': 'lista',
    'titulo': 'Tu link de pago está listo',
    'mensaje': 'Toca «Pagar ahora» para abrir tu pago seguro con Clip.',
    'puedePagar': true,
    'pagarAntesDe': '2026-11-12T05:59:00Z',
  };

  test('a meses en curso aparta la opción y no es un pago sin terminar', () {
    final k = CompraOferta.fromJson(compra(enRevision));
    expect(k.msi?.estado, 'en_revision');
    expect(k.msiEnCurso, isTrue);
    expect(k.tarjetaSinTerminar, isFalse);
    expect(k.resumen, contains('en revisión'));
    expect(CompraOferta.fromJson(compra(lista)).resumen, contains('link de pago listo'));
    // Sin autorización (compra con tarjeta de antes): igual que siempre.
    final vieja = CompraOferta.fromJson(compra(null));
    expect(vieja.msi, isNull);
    expect(vieja.tarjetaSinTerminar, isTrue);
    // Vencida: ya no aparta.
    final vencida = CompraOferta.fromJson(compra({'estado': 'vencida', 'titulo': 'Solicitud vencida', 'mensaje': '...'}));
    expect(vencida.msiEnCurso, isFalse);
    expect(vencida.tarjetaSinTerminar, isTrue);
  });

  testWidgets('en revisión: mensaje y sin botón', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: TarjetaMsi(compraId: 'k1', msi: MsiCompra.fromJson(enRevision)!)),
    ));
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.byKey(const Key('pagarMsi')), findsNothing);
  });

  testWidgets('lista: «Pagar ahora» genera el link y lo abre', (t) async {
    Uri? abierto;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TarjetaMsi(
          compraId: 'k1',
          msi: MsiCompra.fromJson(lista)!,
          pagar: (id) async => const LinkPagoTarjeta(
            id: 'l1',
            url: 'https://pago.clip.mx/l1',
            ticket: 't',
            cotizacion: CotizacionAbono(neto: 20000, cobro: 23000, comision: 3000, liquida: true, saldo: 0),
          ),
          abrir: (u) async => abierto = u,
        ),
      ),
    ));
    expect(find.text('Pagar ahora'), findsOneWidget);
    await t.tap(find.byKey(const Key('pagarMsi')));
    await t.pumpAndSettle();
    expect(abierto.toString(), 'https://pago.clip.mx/l1');
    expect(find.text('Abrir mi pago otra vez'), findsOneWidget);
    expect(find.byKey(const Key('yaPagueMsi')), findsOneWidget);
  });
}
