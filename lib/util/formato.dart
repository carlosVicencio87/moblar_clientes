/// Formatos para mostrar al cliente, en español de México.
///
/// Sin `intl` a propósito: la app necesita poquísimo y así no chocamos con la
/// versión que fija el SDK de Flutter.
library;

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// Fecha ISO del servidor (UTC) a la hora local del teléfono.
DateTime? parseFecha(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.toLocal();
}

/// "lunes 24 de agosto de 2026"
String fechaLarga(DateTime f) =>
    '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]} de ${f.year}';

/// "lunes …" → "Lunes …"
String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "24 ago 2026"
String fechaCorta(DateTime f) => '${f.day} ${_mesesCortos[f.month - 1]} ${f.year}';

/// Fecha de un campo `date` de Postgres ("2026-10-03"), sin mover de día por
/// zona horaria: se interpreta como fecha de calendario, no como instante.
DateTime? parseFechaCalendario(String? ymd) {
  if (ymd == null || ymd.length < 10) return null;
  final p = ymd.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Distancia en días de calendario: "Hoy", "Mañana", "En 3 días", "Ayer",
/// "Hace 5 días". Cuenta días, no horas: una cita mañana a las 9 es "Mañana"
/// aunque falten 30 horas.
String cuandoEs(DateTime fecha, DateTime ahora) {
  final a = DateTime(fecha.year, fecha.month, fecha.day);
  final b = DateTime(ahora.year, ahora.month, ahora.day);
  // Por hora de verano, la resta puede dar 23 o 25 horas: se redondea.
  final dias = (a.difference(b).inHours / 24).round();
  return switch (dias) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Ayer',
    > 1 => 'En $dias días',
    _ => 'Hace ${-dias} días',
  };
}

/// "09:00" → "9:00 a. m."; cualquier otra cosa se devuelve tal cual.
String horaLegible(String? horario) {
  if (horario == null) return '';
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(horario.trim());
  if (m == null) return horario;
  final h = int.parse(m.group(1)!);
  final min = m.group(2)!;
  final sufijo = h < 12 ? 'a. m.' : 'p. m.';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$min $sufijo';
}

/// 12345.5 → "$12,345.50"
String dinero(num valor) {
  final negativo = valor < 0;
  final fijo = valor.abs().toStringAsFixed(2);
  final partes = fijo.split('.');
  final entero = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negativo ? '-' : ''}\$$entero.${partes[1]}';
}

// ---------------------------------------------------------------------------
// Código de acceso — ESPEJO de src/lib/business/clienteAcceso.ts del ERP.
// ---------------------------------------------------------------------------

const alfabetoCodigo = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const longitudCodigo = 8;

/// "k7qm-4xrt" → "K7QM4XRT". Descarta todo lo que no sea letra o número.
String normalizarCodigo(String entrada) =>
    entrada.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

bool codigoCompleto(String entrada) {
  final c = normalizarCodigo(entrada);
  return c.length == longitudCodigo && c.split('').every(alfabetoCodigo.contains);
}

/// "K7QM4XRT" → "K7QM-4XRT"; con menos caracteres pone el guion al pasar de 4.
String formatearCodigo(String entrada) {
  final c = normalizarCodigo(entrada);
  final recortado = c.length > longitudCodigo ? c.substring(0, longitudCodigo) : c;
  return recortado.length > 4
      ? '${recortado.substring(0, 4)}-${recortado.substring(4)}'
      : recortado;
}
