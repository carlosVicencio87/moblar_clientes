import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'inicio_fixture.dart';

/// Servidor falso: responde según la ruta y deja cambiar el estado de la
/// sesión para simular que la operadora revoca el código.
class ServidorFalso {
  bool revocado = false;
  int llamadasInicio = 0;

  late final client = MockClient((r) async {
    if (r.url.path == '/api/cliente/sesion') {
      final codigo = (jsonDecode(r.body) as Map)['codigo'];
      return codigo == 'K7QM4XRT'
          ? http.Response(jsonEncode({'token': 'tok-1', 'cliente': {'nombre': 'Carlos'}}), 200)
          : http.Response(jsonEncode({'error': 'no'}), 401);
    }
    if (r.url.path == '/api/cliente/inicio') {
      llamadasInicio++;
      if (revocado || r.headers['Authorization'] != 'Bearer tok-1') {
        return http.Response('{}', 401);
      }
      return http.Response.bytes(utf8.encode(inicioJson), 200);
    }
    return http.Response('{}', 404);
  });
}
