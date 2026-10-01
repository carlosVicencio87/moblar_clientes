import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';
import 'widgets/contacto.dart';
import 'widgets/detalle_mueble.dart';

/// Cotizaciones del cliente con su PDF.
class CotizacionesTab extends StatelessWidget {
  const CotizacionesTab({super.key, required this.datos});

  final Inicio datos;

  @override
  Widget build(BuildContext context) {
    return ListaRefrescable(
      onRefrescar: AppScope.read(context).refrescar,
      children: [
        if (datos.cotizaciones.isEmpty)
          const VistaVacia(
            icono: Icons.request_quote_outlined,
            titulo: 'Aún no hay cotizaciones',
            texto: 'Después de la visita, tu arquitecto preparará tu cotización y aparecerá aquí.',
          )
        else ...[
          const TituloSeccion('Tus cotizaciones'),
          for (final c in datos.cotizaciones)
            _TarjetaCotizacion(cotizacion: c, contacto: datos.contacto, nombre: datos.nombre),
        ],
        if (datos.cotizaciones.isEmpty)
          TarjetaAyuda(
            titulo: '¿Dudas sobre tus cotizaciones?',
            contacto: datos.contacto,
            mensaje: mensajeContacto(
              etiqueta: MotivoContacto.cotizaciones,
              nombre: datos.nombre,
              texto: 'Tengo una duda sobre mis cotizaciones.',
            ),
          ),
      ],
    );
  }
}

class _TarjetaCotizacion extends StatefulWidget {
  const _TarjetaCotizacion({required this.cotizacion, required this.contacto, this.nombre});

  final Cotizacion cotizacion;
  final Contacto contacto;
  final String? nombre;

  @override
  State<_TarjetaCotizacion> createState() => _TarjetaCotizacionState();
}

class _TarjetaCotizacionState extends State<_TarjetaCotizacion> {
  bool _abriendo = false;

  /// La URL del PDF es firmada y vence en minutos: se pide al tocar el botón,
  /// nunca antes, y no se guarda.
  Future<void> _verPdf() async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await AppScope.read(context).urlPdf(widget.cotizacion.id);
      if (mounted) await abrirEnlace(context, url, trasEspera: true);
    } on SesionTerminada {
      // AppState ya regresó al cliente a la pantalla de ingreso.
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cotizacion;
    final com = c.comercial;
    final hasta = parseFecha(com?.vigenteHasta);
    final vencida = com != null && !com.vigente && !c.comprado;
    final precio = com?.precio ?? c.precio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: Key('cotizacion-${c.id}'),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MarcaEncabezado(
                marca: c.marca,
                trailing: c.comprado
                    ? const EstadoChip(
                        texto: 'Comprada',
                        color: Color(0xFF065F46),
                        fondo: Color(0xFFD1FAE5),
                      )
                    : vencida
                        ? const EstadoChip(
                            texto: 'Vencida',
                            color: Color(0xFF991B1B),
                            fondo: Color(0xFFFEE2E2),
                          )
                        : null,
              ),
            ),
            // Imagen de Moblo: lo primero que ve el cliente.
            if (com?.imagenDiseno != null) ...[
              const SizedBox(height: 12),
              InkWell(
                key: Key('imagenCotizacion-${c.id}'),
                onTap: () => ampliarImagen(context, com!.imagenDiseno!, titulo: c.mueble),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    color: MoblarColors.surfaceSubtle,
                    child: Image.network(
                      com!.imagenDiseno!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Diseño de tu mueble',
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: MoblarColors.textMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.mueble ?? 'Mueble a la medida',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: MoblarColors.textPrimary,
                    ),
                  ),
                  if (c.codigo != null)
                    Text(
                      'Cotización ${c.codigo}',
                      style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                    ),
                  if (precio != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dinero(precio),
                      key: Key('precioCotizacion-${c.id}'),
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: MoblarColors.primaryDark,
                      ),
                    ),
                    if (com?.conIva == true)
                      const Text(
                        'IVA incluido',
                        style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                      ),
                  ],
                  if (hasta != null && !c.comprado)
                    Dato(
                      icono: vencida ? Icons.event_busy_outlined : Icons.event_available_outlined,
                      texto: vencida
                          ? 'Venció el ${fechaLarga(hasta)}. Pídenos una actualización.'
                          : 'Válida hasta el ${fechaLarga(hasta)}',
                    ),
                  if (com?.arquitecto != null)
                    Dato(icono: Icons.person_outline, texto: 'Tu arquitecto: ${com!.arquitecto}'),
                  if (com != null && com.incluye.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'INCLUYE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: MoblarColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in com.incluye)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: MoblarColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 14, color: MoblarColors.primary),
                                const SizedBox(width: 4),
                                Text(t, style: const TextStyle(fontSize: 12, color: MoblarColors.primaryDark)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (c.tienePdf)
                    OutlinedButton.icon(
                      onPressed: _abriendo ? null : _verPdf,
                      icon: _abriendo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Ver cotización formal'),
                    )
                  else
                    const Text(
                      'La cotización formal estará disponible pronto.',
                      style: TextStyle(color: MoblarColors.textMuted, fontSize: 13),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key('verDetalle-${c.id}'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetalleMueblePage(proyectoId: c.id, titulo: c.mueble),
                        ),
                      ),
                      icon: const Icon(Icons.chair_outlined, size: 18),
                      label: const Text('Ver diseño y lo que incluye'),
                    ),
                  ),
                  // Pregunta sobre ESTA cotización: el mensaje lleva su código.
                  BotonPreguntar(
                    key: Key('preguntarCotizacion-${c.id}'),
                    texto: vencida ? 'Pedir cotización actualizada' : 'Preguntar por esta cotización',
                    contacto: widget.contacto,
                    mensaje: mensajeCotizacion(c, widget.nombre),
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
