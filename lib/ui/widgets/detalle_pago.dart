import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';
import 'detalle_mueble.dart' show ampliarImagen;

/// Detalle de un pago en una hoja grande: monto, estado, datos y el
/// comprobante que se adjuntó (para que el cliente sepa qué se registró).
Future<void> mostrarDetallePago(BuildContext context, PagoCliente pago) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => DetallePago(pago: pago, scroll: scroll),
    ),
  );
}

class DetallePago extends StatelessWidget {
  const DetallePago({super.key, required this.pago, this.scroll});

  final PagoCliente pago;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final p = pago;
    final fecha = parseFechaCalendario(p.fecha) ?? parseFecha(p.fecha);
    return ListView(
      key: const Key('detallePago'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Text(
          'Detalle del pago',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                dinero(p.monto),
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: MoblarColors.primaryDark,
                ),
              ),
            ),
            p.validado
                ? const EstadoChip(texto: 'Validado', color: Color(0xFF065F46), fondo: Color(0xFFD1FAE5))
                : const EstadoChip(texto: 'En revisión', color: Color(0xFF92400E), fondo: MoblarColors.amberSoft),
          ],
        ),
        if (!p.validado)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Lo estamos revisando; se sumará a tu pagado cuando lo validemos.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        const SizedBox(height: 12),
        Dato(icono: Icons.label_outline, texto: p.concepto),
        if (fecha != null) Dato(icono: Icons.event_outlined, texto: capitalizar(fechaLarga(fecha))),
        if (p.metodo != null) Dato(icono: Icons.payments_outlined, texto: p.metodo!),
        if (p.referencia != null) Dato(icono: Icons.tag, texto: 'Referencia ${p.referencia}'),
        if (p.visitaIncluida != null)
          Dato(
            icono: Icons.home_work_outlined,
            texto: 'Incluye el costo de la visita (${dinero(p.visitaIncluida!)})',
          ),
        const SizedBox(height: 20),
        const Text(
          'COMPROBANTE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: MoblarColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        if (p.tieneComprobante && p.id != null)
          _Comprobante(pagoId: p.id!)
        else
          const Text(
            'Este pago no tiene comprobante adjunto.',
            key: Key('sinComprobante'),
            style: TextStyle(color: MoblarColors.textMuted),
          ),
      ],
    );
  }
}

/// Pide la URL firmada al abrirse (vence en minutos; no se guarda).
class _Comprobante extends StatefulWidget {
  const _Comprobante({required this.pagoId});

  final String pagoId;

  @override
  State<_Comprobante> createState() => _ComprobanteState();
}

class _ComprobanteState extends State<_Comprobante> {
  Future<Comprobante>? _carga;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carga ??= AppScope.read(context).comprobantePago(widget.pagoId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Comprobante>(
      future: _carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          if (snap.error is SesionTerminada) return const SizedBox.shrink();
          final mensaje = snap.error is ApiException
              ? (snap.error as ApiException).mensaje
              : const ErrorServidor().mensaje;
          return Row(
            children: [
              Expanded(child: Text(mensaje, style: const TextStyle(color: MoblarColors.textSecondary))),
              TextButton(
                onPressed: () => setState(
                  () => _carga = AppScope.read(context).comprobantePago(widget.pagoId),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          );
        }
        final c = snap.data!;
        if (c.esPdf) {
          return OutlinedButton.icon(
            key: const Key('abrirComprobantePdf'),
            onPressed: () => abrirEnlace(context, c.url),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Abrir comprobante (PDF)'),
          );
        }
        final url = c.url.toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const Key('imagenComprobante'),
              onTap: () => ampliarImagen(context, url, titulo: 'Comprobante'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: MoblarColors.surfaceSubtle,
                  constraints: const BoxConstraints(minHeight: 200),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    semanticLabel: 'Comprobante del pago',
                    loadingBuilder: (_, hijo, progreso) => progreso == null
                        ? hijo
                        : const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No pudimos cargar la imagen.',
                          style: TextStyle(color: MoblarColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Toca la imagen para verla completa.',
                style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }
}
