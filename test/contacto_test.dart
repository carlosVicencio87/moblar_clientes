import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/contacto.dart';

import 'fixtures/inicio_fixture.dart';

void main() {
  final inicio = Inicio.fromJson(jsonDecode(inicioJson) as Map<String, dynamic>);

  group('mensajes con motivo (contact center los clasifica por la etiqueta)', () {
    test('la etiqueta va primero, entre corchetes', () {
      final m = mensajeContacto(
        etiqueta: MotivoContacto.citas,
        nombre: 'Carlos Prueba',
        texto: 'Tengo una duda sobre mis citas.',
      );
      expect(m, '[CITAS] Hola, soy Carlos Prueba. Tengo una duda sobre mis citas.');
    });

    test('sin nombre ni referencia no deja huecos', () {
      expect(
        mensajeContacto(etiqueta: MotivoContacto.compras, texto: 'Duda.'),
        '[COMPRAS] Hola. Duda.',
      );
      expect(
        mensajeContacto(etiqueta: MotivoContacto.proyecto, referencia: '  ', texto: 'Duda.'),
        '[PROYECTO] Hola. Duda.',
      );
    });

    test('cotización lleva su código', () {
      final m = mensajeCotizacion(inicio.cotizaciones.first, 'Carlos Prueba');
      expect(m, startsWith('[COTIZACIÓN 000135] Hola, soy Carlos Prueba.'));
      expect(m, contains('de Cocina (000135)'));
    });

    test('cotización sin código ni mueble', () {
      final m = mensajeCotizacion(inicio.cotizaciones.last, null);
      expect(m, '[COTIZACIÓN] Hola. Tengo una duda sobre mi cotización.');
    });

    test('proyecto lleva su código de pedido', () {
      final compra = inicio.compras.firstWhere((c) => c.id == 'p-fabricacion');
      expect(
        mensajeProyecto(compra, 'Carlos Prueba'),
        '[PROYECTO P-0002] Hola, soy Carlos Prueba. Quiero saber sobre mi Cocina (pedido P-0002).',
      );
    });

    test('cita lleva la fecha corta como referencia', () {
      final m = mensajeCita(inicio.citas.first, 'Carlos Prueba');
      expect(m, startsWith('[CITA '));
      expect(m, contains('2030'));
      expect(m, contains('Tengo una duda sobre mi cita del'));
    });
  });

  group('contacto resuelto', () {
    test('usa el del servidor', () {
      final c = ContactoResuelto(inicio.contacto);
      expect(c.telefono, '5530768296');
      expect(c.whatsapp, 'https://wa.me/525530768296');
      expect(c.telefonoLegible, '55 3076 8296');
    });

    test('sin datos del servidor cae al teléfono de respaldo', () {
      final c = ContactoResuelto(const Contacto(empresa: 'MOBLAR', telefono: '', whatsapp: ''));
      expect(c.telefono, isNotEmpty);
      expect(c.whatsapp, '52${c.telefono}');
    });
  });
}
