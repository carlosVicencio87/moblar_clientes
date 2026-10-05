import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/detalle_mueble.dart';

/// Tonos con foto: miniatura (300×300) y galería a pantalla completa
/// (1600×1200). Las imágenes viven en el ERP (`public/tonos/`).
void main() {
  test('el tono lee su miniatura y su galería', () {
    final t = Tono.fromJson(const {
      'nombre': 'ARVENZA',
      'hex': '#8B5A2B',
      'miniatura': '/tonos/oporto-mini.webp',
      'galeria': ['/tonos/oporto-1.webp', ''],
    });
    expect(t.miniatura, '/tonos/oporto-mini.webp');
    expect(t.galeria, ['/tonos/oporto-1.webp']);
    expect(t.tieneFotos, isTrue);
  });

  test('tono sin fotos (servidor viejo o color sin muestra)', () {
    final t = Tono.fromJson(const {'nombre': 'VELMORA', 'hex': null});
    expect(t.miniatura, isNull);
    expect(t.galeria, isEmpty);
    expect(t.tieneFotos, isFalse);
  });

  test('las rutas del ERP se vuelven URL completas', () {
    final api = ClienteApi(base: 'https://ejemplo.test/', bypass: '');
    expect(api.recurso('/tonos/oporto-mini.webp'), 'https://ejemplo.test/tonos/oporto-mini.webp');
    expect(api.recurso('tonos/x.webp'), 'https://ejemplo.test/tonos/x.webp');
    expect(api.recurso('https://cdn.test/x.webp'), 'https://cdn.test/x.webp');
  });

  testWidgets('galería: nombre del tono, indicador y aviso de referencia', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GaleriaTonoPage(
          nombre: 'ARVENZA',
          imagenes: ['https://ejemplo.test/tonos/oporto-1.webp', 'https://ejemplo.test/tonos/oporto-2.webp'],
        ),
      ),
    );
    // Sin red en las pruebas: la imagen cae en su mensaje de error, sin tronar.
    await tester.pump();
    expect(find.byKey(const Key('galeriaTono')), findsOneWidget);
    expect(find.text('ARVENZA'), findsOneWidget);
    expect(find.textContaining('Foto de referencia'), findsOneWidget);
  });
}
