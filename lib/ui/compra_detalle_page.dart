import 'package:flutter/material.dart';

import '../data/api_client.dart' show ApiException;
import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'abonar_proyecto_page.dart';
import 'compras_demo.dart';
import 'estado_cuenta.dart';
import 'widgets/adquirir_oferta.dart' show DemoAnticipos, ResultadoAnticipo;
import 'widgets/adquirir_real.dart' show TarjetaMsi;
import 'widgets/comunes.dart';
import 'widgets/pago_visita.dart' show AvisoDemo;
import 'widgets/contacto.dart';
import 'widgets/detalle_mueble.dart';

/// Seguimiento de un mueble: línea de tiempo vertical con las 5 etapas (el
/// 100 % es "tu mueble está listo") y, aparte, la instalación.
///
/// Recibe el id y no la compra para leerla siempre del estado: si el cliente
/// jala para actualizar, la línea de tiempo se redibuja con lo nuevo.
class CompraDetallePage extends StatelessWidget {
  const CompraDetallePage({super.key, required this.compraId});

  final String compraId;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, ResultadoAnticipo>>(
        valueListenable: DemoAnticipos.resultados,
        builder: (context, anticipos, _) => _pagina(context, anticipos),
      );

  /// A qué se abona: la compra real o (demo) la oferta adquirida.
  static DestinoAbono _destino(Compra c, Map<String, ResultadoAnticipo> anticipos) => c.esDemo
      ? DestinoAbono.oferta(
          citaId: c.demoCitaId!,
          clave: c.demoClave,
          saldo: c.cuenta?.saldo ?? 0,
          abonoMinimo: c.pagoTarjeta?.abonoMinimo ?? 1000,
          factura: anticipos[c.demoClave ?? c.demoCitaId]?.factura ?? true,
        )
      : DestinoAbono.compra(c);

  Widget _pagina(BuildContext context, Map<String, ResultadoAnticipo> anticipos) {
    final state = AppScope.of(context);
    final datos = state.datos;
    final compra = datos == null ? null : todasLasCompras(context, datos).where((c) => c.id == compraId).firstOrNull;
    final puedeAbonar = compra != null &&
        (compra.abonar != null || compra.pagoTarjeta != null || compra.abonoDemo != null) &&
        (compra.cuenta?.saldo ?? 0) > 0;

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
                if (compra.esDemo || compra.abonoDemo != null) ...[
                  const AvisoDemo(),
                  const SizedBox(height: 12),
                ],
                _Encabezado(compra: compra),
                if (compra.msi != null && compra.compraAppId != null) ...[
                  const SizedBox(height: 16),
                  TarjetaMsi(compraId: compra.compraAppId!, msi: compra.msi!),
                ],
                if (compra.lineaTiempo.instalacion != null && !compra.esDemo) ...[
                  const SizedBox(height: 16),
                  TarjetaInstalacion(compraId: compra.id, estado: compra.lineaTiempo.instalacion!),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: LineaTiempoVertical(linea: compra.lineaTiempo),
                  ),
                ),
                if (compra.cuenta != null) ...[
                  const SizedBox(height: 16),
                  EstadoCuentaCompra(cuenta: compra.cuenta!, metaFabricacion: compra.metaFabricacion),
                  // Tarjeta, efectivo con PIN y transferencia: reales desde
                  // 2026-11-11 (`abonar`); la demo solo si no viene del ERP.
                  if (puedeAbonar) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('abonarProyecto'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AbonarProyectoPage(
                            destino: _destino(compra, anticipos),
                            tarjeta: compra.pagoTarjeta != null,
                            transferencia: compra.abonoDemo?.transferencia,
                            arquitecto: compra.abonoDemo?.arquitecto,
                            demo: compra.abonoDemo != null,
                            opciones: compra.abonar,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Abonar a mi proyecto'),
                    ),
                  ],
                ],
                // La compra de la demo no existe en el ERP, y la de la app todavía
                // no es un proyecto en marcha: no hay detalle que pedir.
                if (!compra.esDemo && !compra.esCompraApp) ...[
                  const SizedBox(height: 16),
                  DetalleMueble(proyectoId: compra.id),
                ],
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
            MarcaEncabezado(marca: compra.marca, etiqueta: 'Tu proyecto', icono: Icons.chair_outlined),
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
            // Con el mueble listo, el mensaje lo da la tarjeta de instalación.
            if (compra.lineaTiempo.mensaje.isNotEmpty && (compra.lineaTiempo.instalacion == null || compra.esDemo)) ...[
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


/// La instalación, aparte de la barra (2026-11-10). Con el mueble listo, el
/// botón "Quiero agendar mi instalación" deja la solicitud para que un asesor
/// le llame; después muestra en qué va (solicitada, programada, en camino…).
class TarjetaInstalacion extends StatefulWidget {
  const TarjetaInstalacion({super.key, required this.compraId, required this.estado});

  final String compraId;
  final EstadoInstalacion estado;

  @override
  State<TarjetaInstalacion> createState() => _TarjetaInstalacionState();
}

class _TarjetaInstalacionState extends State<TarjetaInstalacion> {
  bool _enviando = false;

  Future<void> _solicitar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);
    try {
      await AppScope.read(context).solicitarInstalacion(widget.compraId);
      messenger.showSnackBar(const SnackBar(content: Text('Listo: un asesor te llamará para agendar tu instalación.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final verde = e.terminada || e.clave == 'programada' || e.clave == 'en_ruta' || e.clave == 'instalando';
    return Card(
      key: const Key('tarjetaInstalacion'),
      color: verde ? const Color(0xFFECFDF5) : const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  e.terminada ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                  color: const Color(0xFF065F46),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.titulo,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.mensaje, style: const TextStyle(color: MoblarColors.textSecondary)),
            if (e.puedeSolicitar) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('solicitarInstalacion'),
                  onPressed: _enviando ? null : _solicitar,
                  icon: _enviando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.event_available_outlined),
                  label: const Text('Quiero agendar mi instalación'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
