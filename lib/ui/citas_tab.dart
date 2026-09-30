import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'cita_detalle_page.dart';
import 'widgets/avatar_arquitecto.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';

/// Citas del cliente: la próxima destacada arriba, luego las demás próximas y
/// al final las anteriores.
class CitasTab extends StatelessWidget {
  const CitasTab({super.key, required this.datos, this.ahora});

  final Inicio datos;

  /// Para pruebas; por omisión, el reloj del teléfono.
  final DateTime? ahora;

  /// La próxima cita vigente (hoy o después), o null.
  static Cita? proxima(Inicio datos, DateTime ahora) {
    final proximas = datos.citas.where((c) => esProxima(c, ahora)).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return proximas.firstOrNull;
  }

  static bool esProxima(Cita c, DateTime ahora) {
    if (!c.vigente) return false;
    final f = parseFecha(c.fecha);
    if (f == null) return true;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return !f.isBefore(hoy);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = ahora ?? DateTime.now();
    final proximas = datos.citas.where((c) => esProxima(c, hoy)).toList()
      // El servidor las manda de la más reciente a la más antigua; las
      // próximas se leen mejor en orden de calendario.
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final anteriores = datos.citas.where((c) => !esProxima(c, hoy)).toList();

    return ListaRefrescable(
      onRefrescar: AppScope.read(context).refrescar,
      children: [
        if (datos.nombre != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Hola, ${datos.nombre!.split(' ').first}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MoblarColors.textPrimary,
              ),
            ),
          ),
        if (datos.citas.isEmpty)
          const VistaVacia(
            icono: Icons.event_available_outlined,
            titulo: 'Todavía no tienes citas',
            texto: 'Cuando agendes una visita con tu arquitecto la verás aquí.',
          ),
        if (proximas.isNotEmpty) ...[
          const TituloSeccion('Tu próxima cita'),
          _CitaDestacada(
            cita: proximas.first,
            ahora: hoy,
            contacto: datos.contacto,
            nombre: datos.nombre,
          ),
        ],
        if (proximas.length > 1) ...[
          const TituloSeccion('Después'),
          for (final c in proximas.skip(1))
            _TarjetaCita(cita: c, contacto: datos.contacto, nombre: datos.nombre),
        ],
        if (anteriores.isNotEmpty) ...[
          const TituloSeccion('Anteriores'),
          for (final c in anteriores)
            _TarjetaCita(cita: c, contacto: datos.contacto, nombre: datos.nombre),
        ],
        if (datos.citas.isEmpty)
          TarjetaAyuda(
            titulo: '¿Dudas sobre tus citas?',
            contacto: datos.contacto,
            mensaje: mensajeContacto(
              etiqueta: MotivoContacto.citas,
              nombre: datos.nombre,
              texto: 'Tengo una duda sobre mis citas.',
            ),
          ),
      ],
    );
  }
}

void abrirCita(BuildContext context, Cita cita) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CitaDetallePage(citaId: cita.id)),
  );
}

/// Colores de la pastilla de estado de una cita.
(Color, Color) coloresEstadoCita(String clave) => switch (clave) {
      'confirmada' => (const Color(0xFF065F46), const Color(0xFFD1FAE5)),
      'en_camino' || 'en_visita' => (const Color(0xFF92400E), MoblarColors.amberSoft),
      'cancelada' => (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
      'realizada' => (MoblarColors.textSecondary, MoblarColors.sageSoft),
      _ => (MoblarColors.primaryDark, MoblarColors.primarySoft),
    };

class _CitaDestacada extends StatelessWidget {
  const _CitaDestacada({
    required this.cita,
    required this.ahora,
    required this.contacto,
    this.nombre,
  });

  final Cita cita;
  final DateTime ahora;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFecha(cita.fecha);
    final hora = horaLegible(cita.horario);
    final (color, fondo) = coloresEstadoCita(cita.estado.clave);

    return Card(
      key: const Key('citaDestacada'),
      color: MoblarColors.primaryDark,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => abrirCita(context, cita),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El estado va arriba y el "cuándo" abajo, cada uno con su
              // renglón: en pantallas angostas "Tu arquitecto va en camino"
              // junto a "En 12 días" no cabe en una sola línea.
              EstadoChip(texto: cita.estado.titulo, color: color, fondo: fondo),
              const SizedBox(height: 10),
              Text(
                fecha == null ? 'Por confirmar' : cuandoEs(fecha, ahora),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (fecha != null) capitalizar(fechaLarga(fecha)),
                  if (hora.isNotEmpty) hora,
                ].join(' · '),
                style: const TextStyle(color: MoblarColors.primaryTint, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AvatarArquitecto(nombre: cita.arquitecto, fotoUrl: cita.arquitectoFoto, tamano: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tu arquitecto',
                          style: TextStyle(color: MoblarColors.primaryTint, fontSize: 12),
                        ),
                        Text(
                          cita.arquitecto ?? 'Por asignar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
              const SizedBox(height: 8),
              BotonPreguntar(
                key: Key('preguntarCita-${cita.id}'),
                texto: 'Preguntar por esta cita',
                contacto: contacto,
                mensaje: mensajeCita(cita, nombre),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaCita extends StatelessWidget {
  const _TarjetaCita({required this.cita, required this.contacto, this.nombre});

  final Cita cita;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFecha(cita.fecha);
    final (color, fondo) = coloresEstadoCita(cita.estado.clave);
    final hora = horaLegible(cita.horario);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => abrirCita(context, cita),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarcaEncabezado(
                  marca: cita.marca,
                  trailing: EstadoChip(texto: cita.estado.titulo, color: color, fondo: fondo),
                ),
                const SizedBox(height: 12),
                Text(
                  fecha == null ? 'Fecha por confirmar' : capitalizar(fechaLarga(fecha)),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MoblarColors.textPrimary,
                  ),
                ),
                if (hora.isNotEmpty) Dato(icono: Icons.schedule, texto: hora),
                if (cita.arquitecto != null)
                  Dato(icono: Icons.person_outline, texto: 'Tu arquitecto: ${cita.arquitecto}'),
                if (cita.muebles.isNotEmpty)
                  Dato(icono: Icons.chair_outlined, texto: cita.muebles.join(', ')),
                const SizedBox(height: 4),
                BotonPreguntar(
                  key: Key('preguntarCita-${cita.id}'),
                  texto: 'Preguntar por esta cita',
                  contacto: contacto,
                  mensaje: mensajeCita(cita, nombre),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
