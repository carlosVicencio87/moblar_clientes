import 'package:flutter_test/flutter_test.dart';
import 'package:moblar_clientes/data/api_client.dart';
import 'package:moblar_clientes/data/models.dart';
import 'package:moblar_clientes/data/session_store.dart';
import 'package:moblar_clientes/state/app_state.dart';

/// Centro de avisos (2026-10-29): contador de nuevos y "visto hasta".
void main() {
  Inicio inicio(List<Map<String, dynamic>> avisos) => Inicio.fromJson({
        'contacto': const {},
        'citas': const [],
        'cotizaciones': const [],
        'compras': const [],
        'avisos': avisos,
      });
  const a1 = {
    'id': 'pago-k1',
    'fecha': '2026-10-29T18:00:00Z',
    'titulo': 'Pago confirmado',
    'texto': r'Confirmamos tu pago de $1,160.00.',
    'destino': 'compra',
  };
  const a2 = {
    'id': 'compra-k1',
    'fecha': '2026-10-28T17:00:00Z',
    'titulo': 'Registramos tu compra',
    'texto': 'x',
    'destino': 'compra',
  };

  test('lee los avisos y descarta los que no traen fecha válida', () {
    final d = inicio([a1, a2, {...a2, 'id': 'malo', 'fecha': 'ayer'}]);
    expect(d.avisos.map((a) => a.id), ['pago-k1', 'compra-k1']);
  });

  test('cuenta los nuevos y al abrir el centro quedan vistos (y se guarda)', () async {
    final avisos = MemoryAvisosStore();
    final s = AppState(
      api: ClienteApi(base: 'https://ejemplo.test', bypass: ''),
      store: MemorySessionStore(),
      avisos: avisos,
    );
    s.datos = inicio([a1, a2]);
    expect(s.avisosNuevos, 2);
    await s.marcarAvisosVistos();
    expect(s.avisosNuevos, 0);
    expect(DateTime.parse(avisos.iso!), DateTime.parse('2026-10-29T18:00:00Z'));

    // Llega uno más nuevo: solo ese cuenta.
    s.datos = inicio([
      {...a1, 'id': 'formal-p1', 'fecha': '2026-10-30T09:00:00Z'},
      a1,
      a2,
    ]);
    expect(s.avisosNuevos, 1);
  });

  test('al cerrar sesión se olvida lo visto', () async {
    final avisos = MemoryAvisosStore()..iso = '2026-10-29T18:00:00Z';
    final s = AppState(
      api: ClienteApi(base: 'https://ejemplo.test', bypass: ''),
      store: MemorySessionStore(),
      avisos: avisos,
    );
    await s.salir();
    expect(avisos.iso, isNull);
  });
}
