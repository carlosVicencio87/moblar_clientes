import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'compra_detalle_page.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';

/// "Mi compra": un renglón por mueble comprado con su etapa y avance.
class ComprasTab extends StatelessWidget {
  const ComprasTab({super.key, required this.datos});

  final Inicio datos;

  @override
  Widget build(BuildContext context) {
    final compras = datos.comprasOrdenadas;
    final enCurso = compras.where((c) => !c.lineaTiempo.entregado).toList();
    final entregadas = compras.where((c) => c.lineaTiempo.entregado).toList();

    return ListaRefrescable(
      onRefrescar: AppScope.read(context).refrescar,
      children: [
        if (compras.isEmpty)
          const VistaVacia(
            icono: Icons.chair_outlined,
            titulo: 'Aún no tienes compras',
            texto: 'Cuando confirmes tu pedido podrás seguir aquí cada etapa de tu mueble.',
          ),
        if (enCurso.isNotEmpty) ...[
          const TituloSeccion('En proceso'),
          for (final c in enCurso)
            TarjetaCompra(compra: c, contacto: datos.contacto, nombre: datos.nombre),
        ],
        if (entregadas.isNotEmpty) ...[
          const TituloSeccion('Entregadas'),
          for (final c in entregadas)
            TarjetaCompra(compra: c, contacto: datos.contacto, nombre: datos.nombre),
        ],
      ],
    );
  }
}

/// Tarjeta de un mueble comprado: etapa, porcentaje grande, barra y
/// contacto directo con el motivo `[PROYECTO código]` ya escrito.
class TarjetaCompra extends StatelessWidget {
  const TarjetaCompra({
    super.key,
    required this.compra,
    required this.contacto,
    this.nombre,
  });

  final Compra compra;
  final Contacto contacto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final lt = compra.lineaTiempo;
    final inst = compra.instalacion;
    final fechaInst = parseFechaCalendario(inst?.fecha);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('abrirCompra'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => CompraDetallePage(compraId: compra.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarcaEncabezado(
                      marca: compra.marca,
                      trailing: const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      compra.mueble ?? 'Tu mueble',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: MoblarColors.textPrimary,
                      ),
                    ),
                    if (compra.codigo != null)
                      Text(
                        'Pedido ${compra.codigo}',
                        style: const TextStyle(color: MoblarColors.textMuted, fontSize: 12),
                      ),
                    const SizedBox(height: 12),
                    AvanceCompra(linea: lt),
                    if (lt.mensaje.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(lt.mensaje, style: const TextStyle(color: MoblarColors.textSecondary)),
                    ],
                    if (!lt.entregado && fechaInst != null)
                      Dato(
                        icono: Icons.event_available_outlined,
                        texto: 'Instalación: ${fechaCorta(fechaInst)}'
                            '${inst?.horario != null ? ', ${horaLegible(inst!.horario)}' : ''}',
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: BotonesContacto(
                contacto: contacto,
                mensaje: mensajeProyecto(compra, nombre),
                compactos: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etapa + porcentaje grande + seguimiento en miniatura (las 6 etapas).
class AvanceCompra extends StatelessWidget {
  const AvanceCompra({super.key, required this.linea});

  final LineaTiempo linea;

  @override
  Widget build(BuildContext context) {
    final pct = linea.porcentaje;
    final entregado = linea.entregado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: EstadoChip(
                  texto: linea.tituloActual,
                  color: entregado ? const Color(0xFF065F46) : MoblarColors.primaryDark,
                  fondo: entregado ? const Color(0xFFD1FAE5) : MoblarColors.primarySoft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              key: const Key('avancePorcentaje'),
              style: TextStyle(
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w700,
                color: entregado ? const Color(0xFF065F46) : MoblarColors.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SeguimientoMini(linea: linea),
      ],
    );
  }
}

/// Línea de seguimiento horizontal en miniatura: una bolita por etapa, con los
/// mismos colores que la línea de tiempo del detalle (hecha, actual, pendiente).
class SeguimientoMini extends StatelessWidget {
  const SeguimientoMini({super.key, required this.linea});

  final LineaTiempo linea;

  static const _punto = 14.0;

  @override
  Widget build(BuildContext context) {
    final etapas = linea.etapas;
    if (etapas.isEmpty) return const SizedBox.shrink();
    final i = linea.etapaActual.clamp(0, etapas.length - 1);
    return Semantics(
      label: 'Etapa ${i + 1} de ${etapas.length}: ${linea.tituloActual}',
      excludeSemantics: true,
      child: Row(
        key: const Key('seguimientoMini'),
        children: [
          for (var k = 0; k < etapas.length; k++) ...[
            if (k > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: etapas[k].situacion == Situacion.pendiente
                      ? MoblarColors.border
                      : MoblarColors.primary,
                ),
              ),
            _Punto(situacion: etapas[k].situacion, tamano: _punto),
          ],
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.situacion, required this.tamano});

  final Situacion situacion;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final hecha = situacion == Situacion.hecha;
    final actual = situacion == Situacion.actual;
    final color = hecha
        ? MoblarColors.primary
        : actual
            ? MoblarColors.amber
            : MoblarColors.border;
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hecha || actual ? color : MoblarColors.surface,
        border: Border.all(color: color, width: 2),
        boxShadow: actual
            ? [
                BoxShadow(
                  color: MoblarColors.amber.withValues(alpha: 0.35),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
    );
  }
}
