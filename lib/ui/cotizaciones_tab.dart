import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';

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
          for (final c in datos.cotizaciones) _TarjetaCotizacion(cotizacion: c),
        ],
      ],
    );
  }
}

class _TarjetaCotizacion extends StatefulWidget {
  const _TarjetaCotizacion({required this.cotizacion});

  final Cotizacion cotizacion;

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarcaEncabezado(
                marca: c.marca,
                trailing: c.comprado
                    ? const EstadoChip(
                        texto: 'Comprada',
                        color: Color(0xFF065F46),
                        fondo: Color(0xFFD1FAE5),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                c.mueble ?? 'Mueble a la medida',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: MoblarColors.textPrimary,
                ),
              ),
              if (c.codigo != null) Dato(icono: Icons.tag, texto: 'Cotización ${c.codigo}'),
              if (c.precio != null) Dato(icono: Icons.payments_outlined, texto: dinero(c.precio!)),
              const SizedBox(height: 12),
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
                  label: const Text('Ver cotización'),
                )
              else
                const Text(
                  'El documento estará disponible pronto.',
                  style: TextStyle(color: MoblarColors.textMuted, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
