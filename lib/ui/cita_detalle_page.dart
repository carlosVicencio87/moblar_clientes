import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'citas_tab.dart';
import 'widgets/avatar_arquitecto.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';
import 'widgets/estrellas.dart';

/// Detalle de una cita: cuándo, dónde, con quién y en qué va.
///
/// Recibe el id (no la cita) para leerla siempre del estado: al jalar para
/// actualizar se ve el estado nuevo ("Tu arquitecto va en camino").
class CitaDetallePage extends StatelessWidget {
  const CitaDetallePage({super.key, required this.citaId, this.ahora});

  final String citaId;

  /// Para pruebas; por omisión, el reloj del teléfono.
  final DateTime? ahora;

  @override
  Widget build(BuildContext context) {
    final datos = AppScope.of(context).datos;
    final cita = datos?.citas.where((c) => c.id == citaId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Tu cita')),
      body: datos == null || cita == null
          ? const VistaVacia(
              icono: Icons.search_off,
              titulo: 'No encontramos esta cita',
              texto: 'Regresa e intenta de nuevo.',
            )
          : ListaRefrescable(
              onRefrescar: AppScope.read(context).refrescar,
              children: [
                _Encabezado(cita: cita, ahora: ahora ?? DateTime.now()),
                const SizedBox(height: 16),
                if (cita.estado.clave != 'cancelada') ...[
                  _Avance(clave: cita.estado.clave),
                  const SizedBox(height: 16),
                ],
                _Arquitecto(cita: cita, nombreCliente: datos.nombre),
                if (cita.direccion != null || cita.mapsUrl != null) ...[
                  const SizedBox(height: 16),
                  _Lugar(cita: cita),
                ],
                if (cita.muebles.isNotEmpty || cita.costoVisita != null) ...[
                  const SizedBox(height: 16),
                  _QueSeRevisa(cita: cita),
                ],
                const SizedBox(height: 16),
                _Contacto(cita: cita, contacto: datos.contacto, nombre: datos.nombre),
              ],
            ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.cita, required this.ahora});

  final Cita cita;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFecha(cita.fecha);
    final hora = horaLegible(cita.horario);
    final (color, fondo) = coloresEstadoCita(cita.estado.clave);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarcaEncabezado(
              marca: cita.marca,
              trailing: EstadoChip(texto: cita.estado.titulo, color: color, fondo: fondo),
            ),
            const SizedBox(height: 14),
            if (fecha != null && cita.vigente)
              Text(
                cuandoEs(fecha, ahora),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: MoblarColors.primary,
                ),
              ),
            Text(
              fecha == null ? 'Fecha por confirmar' : capitalizar(fechaLarga(fecha)),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MoblarColors.textPrimary,
              ),
            ),
            if (hora.isNotEmpty) Dato(icono: Icons.schedule, texto: hora),
            if (cita.agendoPor != null)
              Dato(icono: Icons.support_agent, texto: 'Agendó tu cita: ${cita.agendoPor}'),
          ],
        ),
      ),
    );
  }
}

/// Avance de la cita en 4 pasos. "Realizada" marca todos como hechos.
class _Avance extends StatelessWidget {
  const _Avance({required this.clave});

  final String clave;

  static const _pasos = [
    ('confirmada', 'Confirmada'),
    ('en_camino', 'En camino'),
    ('en_visita', 'En visita'),
    ('realizada', 'Realizada'),
  ];

  @override
  Widget build(BuildContext context) {
    // por_confirmar = -1: ningún paso alcanzado todavía.
    final actual = _pasos.indexWhere((p) => p.$1 == clave);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: Row(
          children: [
            for (var i = 0; i < _pasos.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      i <= actual ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: i < actual || clave == 'realizada'
                          ? MoblarColors.primary
                          : i == actual
                              ? MoblarColors.amber
                              : MoblarColors.border,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pasos[i].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                        color: i <= actual ? MoblarColors.textPrimary : MoblarColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande del arquitecto: foto al centro, nombre y, desplegable,
/// sus habilidades y, al final, el contacto directo con el arquitecto.
class _Arquitecto extends StatelessWidget {
  const _Arquitecto({required this.cita, this.nombreCliente});

  final Cita cita;
  final String? nombreCliente;

  @override
  Widget build(BuildContext context) {
    final asignado = cita.arquitecto != null;
    final habilidades = asignado ? cita.arquitectoHabilidades : const <Habilidad>[];
    final telefono = asignado ? cita.arquitectoTelefono : null;
    return Card(
      key: const Key('tarjetaArquitecto'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                const Text(
                  'TU ARQUITECTO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: MoblarColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                AvatarArquitecto(nombre: cita.arquitecto, fotoUrl: cita.arquitectoFoto, tamano: 120),
                const SizedBox(height: 12),
                Text(
                  cita.arquitecto ?? 'Por asignar',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MoblarColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !asignado
                      ? 'Te avisaremos quién te visitará.'
                      : cita.estado.clave == 'realizada'
                          ? 'Es quien te atendió en tu visita.'
                          : 'Es quien te visitará para tomar medidas y diseñar tu mueble.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary),
                ),
              ],
            ),
          ),
          if (habilidades.isNotEmpty || telefono != null) ...[
            const Divider(height: 1),
            Theme(
              // Sin las líneas que ExpansionTile dibuja al abrir.
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('habilidadesArquitecto'),
                leading: const Icon(Icons.workspace_premium_outlined, color: MoblarColors.primary),
                title: const Text('Habilidades', style: TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final h in habilidades) RenglonHabilidad(habilidad: h),
                  if (telefono != null) ...[
                    const Divider(height: 16),
                    _ContactoArquitecto(
                      telefono: telefono,
                      mensaje: mensajeArquitecto(cita, nombreCliente),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renglón discreto al final del desplegable: llamar o escribir directo al
/// arquitecto (sin pasar por atención a clientes).
class _ContactoArquitecto extends StatelessWidget {
  const _ContactoArquitecto({required this.telefono, required this.mensaje});

  final String telefono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('contactoArquitecto'),
      children: [
        const Expanded(
          child: Text(
            'Contacta a tu arquitecto',
            style: TextStyle(fontSize: 13, color: MoblarColors.textSecondary),
          ),
        ),
        IconButton(
          key: const Key('arquitectoLlamar'),
          tooltip: 'Llamar',
          color: MoblarColors.primary,
          icon: const Icon(Icons.call_outlined, size: 20),
          onPressed: () => abrirEnlace(context, Uri(scheme: 'tel', path: telefono)),
        ),
        IconButton(
          key: const Key('arquitectoWhatsApp'),
          tooltip: 'WhatsApp',
          color: MoblarColors.primary,
          icon: const Icon(Icons.chat_outlined, size: 20),
          onPressed: () => abrirEnlace(context, enlaceWhatsApp('52$telefono', mensaje: mensaje)),
        ),
      ],
    );
  }
}

class _Lugar extends StatelessWidget {
  const _Lugar({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final maps = cita.mapsUrl == null ? null : Uri.tryParse(cita.mapsUrl!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Dónde', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (cita.direccion != null) Dato(icono: Icons.place_outlined, texto: cita.direccion!),
            if (maps != null && maps.hasScheme) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => abrirEnlace(context, maps),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver en Maps'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueSeRevisa extends StatelessWidget {
  const _QueSeRevisa({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Qué vamos a revisar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (cita.muebles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final m in cita.muebles) EstadoChip(texto: m)],
              ),
            ],
            if (cita.costoVisita != null)
              Dato(
                icono: Icons.payments_outlined,
                texto: 'Costo de la visita: ${dinero(cita.costoVisita!)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto({required this.cita, required this.contacto, required this.nombre});

  final Cita cita;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final fecha = parseFecha(cita.fecha);
    final hora = horaLegible(cita.horario);
    final cuando = [if (fecha != null) fechaLarga(fecha), if (hora.isNotEmpty) hora].join(' a las ');
    // Cita vigente: el motivo típico es cambiarla. Ya realizada o cancelada:
    // una duda sobre esa visita.
    final (titulo, subtitulo, mensaje) = cita.vigente
        ? (
            '¿Necesitas cambiar tu cita?',
            'Escríbenos y te ayudamos a reagendarla o cancelarla.',
            mensajeContacto(
              etiqueta: MotivoContacto.cita,
              referencia: fecha == null ? null : fechaCorta(fecha),
              nombre: nombre,
              texto: 'Quiero reagendar o cancelar mi cita${cuando.isEmpty ? '' : ' del $cuando'}.',
            ),
          )
        : (
            '¿Dudas sobre esta visita?',
            'Una persona de nuestro equipo te atiende.',
            mensajeCita(cita, nombre),
          );
    return Card(
      key: const Key('contactoCita'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitulo, style: const TextStyle(color: MoblarColors.textSecondary)),
            const SizedBox(height: 12),
            BotonesContacto(contacto: contacto, mensaje: mensaje),
          ],
        ),
      ),
    );
  }
}
