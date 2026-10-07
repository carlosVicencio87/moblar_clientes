import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';

/// Tarjeta del QR de llegada mientras el arquitecto va en camino.
///
/// Pregunta al servidor cada [intervalo]. El QR aparece solo cuando el
/// arquitecto ya está a menos de 300 m del domicilio; él lo escanea y la cita
/// pasa sola a "En visita". Si el servidor responde "no_aplica" (función
/// apagada o cita en otro estado) la tarjeta no ocupa espacio.
class TarjetaLlegada extends StatefulWidget {
  const TarjetaLlegada({super.key, required this.citaId, this.intervalo = const Duration(seconds: 8)});

  final String citaId;
  final Duration intervalo;

  @override
  State<TarjetaLlegada> createState() => _TarjetaLlegadaState();
}

class _TarjetaLlegadaState extends State<TarjetaLlegada> {
  LlegadaCita? _llegada;
  Timer? _timer;
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    // Primera consulta después del primer frame (ya hay context con AppScope).
    WidgetsBinding.instance.addPostFrameCallback((_) => _consultar());
    _timer = Timer.periodic(widget.intervalo, (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    if (_pidiendo || !mounted) return;
    _pidiendo = true;
    try {
      final app = AppScope.read(context);
      final l = await app.llegada(widget.citaId);
      if (!mounted) return;
      setState(() => _llegada = l);
      if (l.estado == 'llego') {
        // Ya escaneó: se deja de preguntar y se actualiza la cita ("En visita").
        _timer?.cancel();
        await app.refrescar();
      }
    } catch (_) {
      // Sin señal o error del servidor: se conserva lo último y se reintenta en el siguiente ciclo.
    } finally {
      _pidiendo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _llegada;
    if (l == null || l.estado == 'no_aplica' || l.estado == 'llego' || l.texto.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const Key('tarjetaLlegada'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                l.texto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MoblarColors.textPrimary),
              ),
              if (l.listo) ...[
                const SizedBox(height: 16),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    key: const Key('qrLlegada'),
                    data: l.qr!,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('¿No se puede escanear? Díctale este código:',
                    style: TextStyle(fontSize: 13, color: MoblarColors.textSecondary)),
                const SizedBox(height: 4),
                SelectableText(
                  '${l.codigo!.substring(0, 3)} ${l.codigo!.substring(3)}',
                  key: const Key('codigoLlegada'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: MoblarColors.primaryDark,
                  ),
                ),
              ] else if (l.estado == 'esperando')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
