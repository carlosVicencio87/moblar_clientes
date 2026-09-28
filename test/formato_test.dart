import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/util/formato.dart';

void main() {
  group('código de acceso (espejo de clienteAcceso.ts)', () {
    test('normaliza lo que el cliente teclea o pega', () {
      expect(normalizarCodigo('k7qm-4xrt'), 'K7QM4XRT');
      expect(normalizarCodigo(' K7QM 4XRT '), 'K7QM4XRT');
    });

    test('código completo solo con el alfabeto válido', () {
      expect(codigoCompleto('K7QM-4XRT'), isTrue);
      expect(codigoCompleto('k7qm4xrt'), isTrue);
      expect(codigoCompleto('K7QM-4XR'), isFalse); // corto
      expect(codigoCompleto('K7QM-4XR0'), isFalse); // 0 no existe
      expect(codigoCompleto('K7QM-4XRI'), isFalse); // I no existe
      expect(codigoCompleto('K7QM-4XRL'), isFalse); // L no existe
    });

    test('guion después del cuarto carácter y recorte a 8', () {
      expect(formatearCodigo('K7Q'), 'K7Q');
      expect(formatearCodigo('K7QM'), 'K7QM');
      expect(formatearCodigo('K7QM4'), 'K7QM-4');
      expect(formatearCodigo('k7qm4xrt99'), 'K7QM-4XRT');
    });

    test('el alfabeto es el mismo que el del servidor', () {
      expect(alfabetoCodigo, '23456789ABCDEFGHJKMNPQRSTUVWXYZ');
      expect(longitudCodigo, 8);
    });
  });

  group('fechas y horas', () {
    test('fecha larga en español', () {
      expect(fechaLarga(DateTime(2026, 8, 24)), 'lunes 24 de agosto de 2026');
      expect(capitalizar(fechaLarga(DateTime(2026, 9, 27))), 'Domingo 27 de septiembre de 2026');
    });

    test('fecha corta', () {
      expect(fechaCorta(DateTime(2026, 1, 5)), '5 ene 2026');
    });

    test('fecha de calendario no se mueve por zona horaria', () {
      final f = parseFechaCalendario('2026-10-03')!;
      expect([f.year, f.month, f.day], [2026, 10, 3]);
      expect(parseFechaCalendario(null), isNull);
      expect(parseFechaCalendario('basura'), isNull);
    });

    test('parseFecha tolera vacíos', () {
      expect(parseFecha(null), isNull);
      expect(parseFecha(''), isNull);
      expect(parseFecha('no-es-fecha'), isNull);
      expect(parseFecha('2026-08-24T15:00:00+00:00')!.isUtc, isFalse);
    });

    test('cuándo es, en días de calendario', () {
      final ahora = DateTime(2026, 9, 28, 22, 30);
      expect(cuandoEs(DateTime(2026, 9, 28, 9), ahora), 'Hoy');
      expect(cuandoEs(DateTime(2026, 9, 29, 9), ahora), 'Mañana');
      expect(cuandoEs(DateTime(2026, 10, 2, 9), ahora), 'En 4 días');
      expect(cuandoEs(DateTime(2026, 9, 27, 23), ahora), 'Ayer');
      expect(cuandoEs(DateTime(2026, 9, 20), ahora), 'Hace 8 días');
    });

    test('hora legible', () {
      expect(horaLegible('09:00'), '9:00 a. m.');
      expect(horaLegible('12:30'), '12:30 p. m.');
      expect(horaLegible('00:15'), '12:15 a. m.');
      expect(horaLegible('16:00:00'), '4:00 p. m.');
      expect(horaLegible('Por la tarde'), 'Por la tarde');
      expect(horaLegible(null), '');
    });
  });

  test('dinero', () {
    expect(dinero(0), r'$0.00');
    expect(dinero(1234.5), r'$1,234.50');
    expect(dinero(1234567), r'$1,234,567.00');
    expect(dinero(-50), r'-$50.00');
  });
}
