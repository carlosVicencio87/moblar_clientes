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
          for (final c in enCurso) TarjetaCompra(compra: c),
        ],
        if (entregadas.isNotEmpty) ...[
          const TituloSeccion('Entregadas'),
          for (final c in entregadas) TarjetaCompra(compra: c),
        ],
        TarjetaAyuda(
          titulo: '¿Dudas sobre tus compras?',
          contacto: datos.contacto,
          mensaje: mensajeContacto(
            etiqueta: MotivoContacto.compras,
            nombre: datos.nombre,
            texto: 'Tengo una duda sobre mis compras.',
          ),
        ),
      ],
    );
  }
}

class TarjetaCompra extends StatelessWidget {
  const TarjetaCompra({super.key, required this.compra});

  final Compra compra;

  @override
  Widget build(BuildContext context) {
    final lt = compra.lineaTiempo;
    final total = lt.etapas.isEmpty ? 1 : lt.etapas.length;
    final hechas = lt.etapas.where((e) => e.situacion == Situacion.hecha).length;
    // La etapa actual cuenta como media: el mueble está en camino dentro de ella.
    final avance = lt.entregado ? 1.0 : ((hechas + 0.5) / total).clamp(0.0, 1.0);
    final inst = compra.instalacion;
    final fechaInst = parseFechaCalendario(inst?.fecha);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => CompraDetallePage(compraId: compra.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    EstadoChip(
                      texto: lt.tituloActual,
                      color: lt.entregado ? const Color(0xFF065F46) : MoblarColors.primaryDark,
                      fondo: lt.entregado ? const Color(0xFFD1FAE5) : MoblarColors.primarySoft,
                    ),
                    const Spacer(),
                    if (compra.codigo != null)
                      Text(
                        compra.codigo!,
                        style: const TextStyle(color: MoblarColors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: avance,
                    minHeight: 6,
                    backgroundColor: MoblarColors.primarySoft,
                    color: lt.entregado ? MoblarColors.success : MoblarColors.primary,
                  ),
                ),
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
      ),
    );
  }
}
