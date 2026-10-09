import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'abonar_proyecto_page.dart';
import 'estado_cuenta.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';
import 'widgets/detalle_mueble.dart';

/// Seguimiento de un mueble: línea de tiempo vertical con las 6 etapas.
///
/// Recibe el id y no la compra para leerla siempre del estado: si el cliente
/// jala para actualizar, la línea de tiempo se redibuja con lo nuevo.
class CompraDetallePage extends StatelessWidget {
  const CompraDetallePage({super.key, required this.compraId});

  final String compraId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final datos = state.datos;
    final compra = datos?.compras.where((c) => c.id == compraId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: datos == null || compra == null
          ? const VistaVacia(
              icono: Icons.search_off,
              titulo: 'No encontramos esta compra',
              texto: 'Regresa e intenta de nuevo.',
            )
          : ListaRefrescable(
              onRefrescar: AppScope.read(context).refrescar,
              children: [
                _Encabezado(compra: compra),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: LineaTiempoVertical(linea: compra.lineaTiempo),
                  ),
                ),
                if (compra.cuenta != null) ...[
                  const SizedBox(height: 16),
                  EstadoCuentaCompra(cuenta: compra.cuenta!),
                  // Solo con pago con tarjeta disponible: efectivo y transferencia de
                  // una compra real se registran en Pagos (con aprobación de gerencia).
                  if (compra.pagoTarjeta != null && compra.cuenta!.saldo > 0) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('abonarProyecto'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AbonarProyectoPage(
                            destino: DestinoAbono.compra(compra),
                            tarjeta: compra.pagoTarjeta != null,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Abonar a mi proyecto'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                DetalleMueble(proyectoId: compra.id),
                const SizedBox(height: 16),
                _Ayuda(contacto: datos.contacto, compra: compra, nombre: datos.nombre),
              ],
            ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.compra});

  final Compra compra;

  @override
  Widget build(BuildContext context) {
    final inst = compra.instalacion;
    final fechaInst = parseFechaCalendario(inst?.fecha);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarcaEncabezado(marca: compra.marca),
            const SizedBox(height: 12),
            Text(
              compra.mueble ?? 'Tu mueble',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MoblarColors.textPrimary,
              ),
            ),
            if (compra.codigo != null) Dato(icono: Icons.tag, texto: 'Pedido ${compra.codigo}'),
            if (fechaInst != null)
              Dato(
                icono: Icons.event_available_outlined,
                texto: '${compra.lineaTiempo.entregado ? 'Instalado el' : 'Instalación programada:'} '
                    '${fechaLarga(fechaInst)}'
                    '${inst?.horario != null ? ', ${horaLegible(inst!.horario)}' : ''}',
              ),
            if (compra.lineaTiempo.mensaje.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MoblarColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  compra.lineaTiempo.mensaje,
                  style: const TextStyle(color: MoblarColors.primaryDark, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Línea de tiempo vertical. Pública para probarla por separado.
class LineaTiempoVertical extends StatelessWidget {
  const LineaTiempoVertical({super.key, required this.linea});

  final LineaTiempo linea;

  @override
  Widget build(BuildContext context) {
    final etapas = linea.etapas;
    return Column(
      children: [
        for (var i = 0; i < etapas.length; i++)
          _PasoEtapa(
            etapa: etapas[i],
            // Etapa actual: el avance real; las demás, su meta.
            porcentaje: etapas[i].situacion == Situacion.actual ? linea.porcentaje : etapas[i].meta,
            primera: i == 0,
            ultima: i == etapas.length - 1,
            siguienteAlcanzada: i + 1 < etapas.length && etapas[i + 1].situacion != Situacion.pendiente,
          ),
      ],
    );
  }
}

class _PasoEtapa extends StatelessWidget {
  const _PasoEtapa({
    required this.etapa,
    required this.porcentaje,
    required this.primera,
    required this.ultima,
    required this.siguienteAlcanzada,
  });

  final EtapaLineaTiempo etapa;
  final int? porcentaje;
  final bool primera;
  final bool ultima;
  final bool siguienteAlcanzada;

  @override
  Widget build(BuildContext context) {
    final hecha = etapa.situacion == Situacion.hecha;
    final actual = etapa.situacion == Situacion.actual;
    final alcanzada = hecha || actual;
    final desde = parseFecha(etapa.desde);

    final Color colorPunto = hecha
        ? MoblarColors.primary
        : actual
            ? MoblarColors.amber
            : MoblarColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Porcentaje a la izquierda de la bolita, a su altura.
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    porcentaje == null ? '' : '$porcentaje%',
                    key: Key('pctEtapa-${etapa.clave}'),
                    style: TextStyle(
                      fontSize: actual ? 14 : 12,
                      fontWeight: actual ? FontWeight.w800 : FontWeight.w600,
                      color: actual
                          ? const Color(0xFFB45309)
                          : hecha
                              ? MoblarColors.primary
                              : MoblarColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 4,
                  color: primera
                      ? Colors.transparent
                      : (alcanzada ? MoblarColors.primary : MoblarColors.border),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: alcanzada ? colorPunto : MoblarColors.surface,
                    border: Border.all(color: colorPunto, width: 2),
                    boxShadow: actual
                        ? [
                            BoxShadow(
                              color: MoblarColors.amber.withValues(alpha: 0.35),
                              blurRadius: 0,
                              spreadRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: hecha
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : actual
                          ? const Icon(Icons.more_horiz, size: 16, color: Colors.white)
                          : null,
                ),
                if (!ultima)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: siguienteAlcanzada ? MoblarColors.primary : MoblarColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    etapa.titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: actual ? FontWeight.w700 : FontWeight.w600,
                      color: alcanzada ? MoblarColors.textPrimary : MoblarColors.textMuted,
                    ),
                  ),
                  if (desde != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        fechaCorta(desde),
                        style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                      ),
                    ),
                  if (actual && etapa.descripcion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        etapa.descripcion,
                        style: const TextStyle(color: MoblarColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ayuda extends StatelessWidget {
  const _Ayuda({required this.contacto, required this.compra, required this.nombre});

  final Contacto contacto;
  final Compra compra;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Tienes dudas sobre tu mueble?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Una persona de nuestro equipo te atiende.',
              style: TextStyle(color: MoblarColors.textSecondary),
            ),
            const SizedBox(height: 12),
            BotonesContacto(contacto: contacto, mensaje: mensajeProyecto(compra, nombre)),
          ],
        ),
      ),
    );
  }
}
