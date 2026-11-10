import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/compra_detalle_page.dart';

/// La instalación va aparte del porcentaje (2026-11-10): con el mueble listo
/// se ofrece "Quiero agendar mi instalación"; después, en qué va.
void main() {
  Widget envolver(EstadoInstalacion e) => MaterialApp(
        home: Scaffold(body: TarjetaInstalacion(compraId: 'p-1', estado: e)),
      );

  testWidgets('por agendar: mensaje y botón', (t) async {
    await t.pumpWidget(envolver(const EstadoInstalacion(
      clave: 'por_agendar',
      titulo: 'Instalación por agendar',
      mensaje: 'Tu mueble está listo. Agenda tu instalación con nuestro asesor.',
      puedeSolicitar: true,
    )));
    expect(find.text('Instalación por agendar'), findsOneWidget);
    expect(find.textContaining('Agenda tu instalación'), findsOneWidget);
    expect(find.byKey(const Key('solicitarInstalacion')), findsOneWidget);
  });

  testWidgets('solicitada o programada: sin botón', (t) async {
    const base = EstadoInstalacion(clave: 'por_agendar', titulo: '', mensaje: '', puedeSolicitar: true);
    await t.pumpWidget(envolver(base.solicitada('2026-11-10T16:00:00Z')));
    expect(find.text('Solicitud recibida'), findsOneWidget);
    expect(find.textContaining('Un asesor te contactará'), findsOneWidget);
    expect(find.byKey(const Key('solicitarInstalacion')), findsNothing);

    await t.pumpWidget(envolver(const EstadoInstalacion(
      clave: 'programada',
      titulo: 'Instalación programada',
      mensaje: 'Tu instalación está programada.',
      puedeSolicitar: false,
    )));
    expect(find.text('Instalación programada'), findsOneWidget);
    expect(find.byKey(const Key('solicitarInstalacion')), findsNothing);
  });
}
