/// Configuración de la app de clientes.
///
/// Se inyecta al compilar con `--dart-define`, así la app nunca trae llaves:
///
///   flutter run --dart-define=API_BASE=https://caml.osmon-moblar.xyz
///
/// Para probar contra un preview protegido de Vercel (antes del PR a master):
///
///   flutter run \
///     --dart-define=API_BASE=https://osmon-moblar-caml-git-carlosvdevlocal-moblar.vercel.app \
///     --dart-define=VERCEL_BYPASS=SECRETO   (Vercel: "Protection Bypass for Automation")
///
/// En web no hace falta nada de esto: ver [AppConfig.apiBase].
library;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  AppConfig._();

  /// Dominio del ERP en producción. Sin diagonal final.
  static const String _produccion = 'https://caml.osmon-moblar.xyz';

  static const String _apiBaseDefinida = String.fromEnvironment('API_BASE');

  /// A dónde habla la app.
  ///
  /// - Si se compila con `--dart-define=API_BASE=…`, eso manda (celular y web).
  /// - En web, sin API_BASE: el MISMO dominio que sirve la app. La app web se
  ///   publica dentro del ERP (`/clientes`), así que producción habla con
  ///   producción y un preview con su propio preview, sin CORS.
  /// - En celular, sin API_BASE: producción.
  static String get apiBase {
    if (_apiBaseDefinida.isNotEmpty) return _apiBaseDefinida;
    if (kIsWeb) return Uri.base.origin;
    return _produccion;
  }

  /// Opcional. Solo para previews protegidos desde el celular; en web el
  /// navegador ya trae la sesión de Vercel y en producción va vacío.
  static const String vercelBypass = String.fromEnvironment('VERCEL_BYPASS');

  /// Contacto de respaldo para la pantalla de ingreso, cuando todavía no hay
  /// sesión y el servidor no ha dicho a quién llamar. Moblar atiende a todas
  /// las marcas (decisión 2026-09-27).
  static const String telefonoAtencion = '5530768296';
}
