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
///     --dart-define=VERCEL_BYPASS=<secreto de "Protection Bypass for Automation">
class AppConfig {
  AppConfig._();

  /// Dominio del ERP en producción (Vercel). Sin diagonal final.
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://caml.osmon-moblar.xyz',
  );

  /// Opcional. Solo para previews protegidos; en producción va vacío.
  static const String vercelBypass = String.fromEnvironment('VERCEL_BYPASS');

  /// Contacto de respaldo para la pantalla de ingreso, cuando todavía no hay
  /// sesión y el servidor no ha dicho a quién llamar. Moblar atiende a todas
  /// las marcas (decisión 2026-09-27).
  static const String telefonoAtencion = '5530768296';
}
