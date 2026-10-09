import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Dónde vive el pase de sesión del cliente. El código de acceso NUNCA se
/// guarda: solo el token, que el servidor puede invalidar en cualquier momento.
abstract class SessionStore {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> borrar();
}

/// Keychain en iOS, almacenamiento cifrado en Android.
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _clave = 'moblar_cliente_token';

  @override
  Future<String?> leer() async {
    try {
      return await _storage.read(key: _clave);
    } catch (_) {
      // Almacenamiento corrupto (p. ej. tras restaurar el teléfono): se trata
      // como "sin sesión" y el cliente vuelve a teclear su código.
      return null;
    }
  }

  @override
  Future<void> guardar(String token) => _storage.write(key: _clave, value: token);

  @override
  Future<void> borrar() async {
    try {
      await _storage.delete(key: _clave);
    } catch (_) {}
  }
}

/// Para pruebas.
class MemorySessionStore implements SessionStore {
  String? token;
  @override
  Future<String?> leer() async => token;
  @override
  Future<void> guardar(String t) async => token = t;
  @override
  Future<void> borrar() async => token = null;
}

/// Pago con tarjeta en curso (ver [PagoPendiente]). Uno a la vez.
abstract class PagoPendienteStore {
  Future<PagoPendiente?> leer();
  Future<void> guardar(PagoPendiente pago);
  Future<void> borrar();
}

class SecurePagoPendienteStore implements PagoPendienteStore {
  SecurePagoPendienteStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _clave = 'moblar_cliente_pago_tarjeta';

  @override
  Future<PagoPendiente?> leer() async {
    try {
      final v = await _storage.read(key: _clave);
      if (v == null) return null;
      final j = jsonDecode(v);
      return j is Map<String, dynamic> ? PagoPendiente.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(PagoPendiente pago) =>
      _storage.write(key: _clave, value: jsonEncode(pago.toJson()));

  @override
  Future<void> borrar() async {
    try {
      await _storage.delete(key: _clave);
    } catch (_) {}
  }
}

/// Para pruebas (y por omisión): solo en memoria.
class MemoryPagoPendienteStore implements PagoPendienteStore {
  PagoPendiente? pago;
  @override
  Future<PagoPendiente?> leer() async => pago;
  @override
  Future<void> guardar(PagoPendiente p) async => pago = p;
  @override
  Future<void> borrar() async => pago = null;
}
