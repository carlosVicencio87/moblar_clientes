// Aviso de llegada del arquitecto y textos de la visita (feedback de
// arquitectura, 2026-10-14).
import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/ui/widgets/aviso_arquitecto.dart';

Cita cita(String clave, {DateTime? fecha, String? arquitecto = 'Ana López', String id = 'c'}) => Cita.fromJson({
      'id': id,
      'fecha': (fecha ?? DateTime.now()).toUtc().toIso8601String(),
      'estado': {'clave': clave, 'titulo': 'x'},
      'arquitecto': arquitecto,
      'muebles': const <String>[],
      'marca': const {},
    });

void main() {
  test('dice si va en camino o si ya llegó', () {
    expect(textoAvisoArquitecto(cita('en_camino')), 'Tu arquitecto Ana López va en camino.');
    expect(textoAvisoArquitecto(cita('en_visita')), 'Tu arquitecto Ana López llegó.');
    expect(textoAvisoArquitecto(cita('en_camino', arquitecto: null)), 'Tu arquitecto va en camino.');
    expect(textoAvisoArquitecto(cita('confirmada')), isNull);
    expect(textoAvisoArquitecto(cita('realizada')), isNull);
  });

  test('solo vigila las citas de hoy que todavía pueden cambiar', () {
    final ahora = DateTime.now();
    final lista = [
      cita('confirmada', id: 'hoy'),
      cita('en_camino', id: 'camino'),
      cita('realizada', id: 'hecha'),
      cita('confirmada', id: 'manana', fecha: ahora.add(const Duration(days: 1))),
    ];
    expect(citasPorVigilar(lista, ahora).map((c) => c.id), ['hoy', 'camino']);
  });
}
