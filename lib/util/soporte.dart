/// Modo soporte (2026-11-17): un super admin abre esta app desde el ERP
/// ("Ver como cliente") para ver lo mismo que el cliente, SIN sacarlo y SOLO
/// LECTURA. El ERP manda el pase en el fragmento: `.../clientes/#soporte=<token>`.
/// El fragmento no viaja al servidor; la app lo quita de la barra al leerlo
/// y el pase solo vive en memoria (no se guarda en el navegador).
///
/// El bloqueo de verdad está en el servidor: con este pase todo lo que no sea
/// consultar responde 403. Aquí solo se lee el pase y se avisa en pantalla.
library;

final _jwt = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

/// El pase de soporte de la dirección, o null si no viene (o no tiene forma
/// de pase). Acepta `#soporte=…`, `#/soporte=…` y `#/?soporte=…`.
String? tokenSoporteDe(Uri uri) {
  var f = uri.fragment;
  if (f.startsWith('/')) f = f.substring(1);
  if (f.startsWith('?')) f = f.substring(1);
  if (f.isEmpty) return null;
  final Map<String, String> q;
  try {
    q = Uri.splitQueryString(f);
  } catch (_) {
    return null;
  }
  final t = q['soporte']?.trim();
  if (t == null || !_jwt.hasMatch(t)) return null;
  return t;
}

const mensajeSoporteTerminado =
    'El modo soporte terminó (dura una hora). Ábrelo de nuevo desde la cita en el ERP.';

const textoFranjaSoporte = 'Modo soporte · solo lectura. El cliente no ve esta sesión.';
