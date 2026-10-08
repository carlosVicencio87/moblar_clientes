import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';
import '../../util/formato.dart';

/// QR de llegada del arquitecto (GET /api/cliente/citas/:id/llegada).
///
/// El QR solo existe cuando el arquitecto ya está a menos de 300 m del
/// domicilio (lo decide el servidor). Él lo escanea con su app y la cita pasa
/// sola a "En visita". Con la función apagada el servidor responde
/// "no_aplica" y aquí no se muestra nada.
///
/// Tres piezas:
///  - [VigilanteLlegada]: envuelve la pantalla principal; mientras la app está
///    abierta pregunta por las citas de hoy y, cuando el arquitecto llega,
///    abre una alerta con el QR esté donde esté el cliente.
///  - [TarjetaLlegada]: la misma información dentro del detalle de la cita.
///  - [VistaQrLlegada]: el QR y el código, compartido por las dos.

/// QR grande + código de 6 dígitos.
class VistaQrLlegada extends StatelessWidget {
  const VistaQrLlegada({super.key, required this.llegada});

  final LlegadaCita llegada;

  @override
  Widget build(BuildContext context) {
    final codigo = llegada.codigo!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: QrImageView(
            key: const Key('qrLlegada'),
            data: llegada.qr!,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text('¿No se puede escanear? Díctale este código:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MoblarColors.textSecondary)),
        const SizedBox(height: 4),
        SelectableText(
          codigo.length == 6 ? '${codigo.substring(0, 3)} ${codigo.substring(3)}' : codigo,
          key: const Key('codigoLlegada'),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: MoblarColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta dentro del detalle de la cita mientras el arquitecto va en camino.
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
        _timer?.cancel();
        await app.refrescar();
      }
    } catch (_) {
      // Sin señal: se conserva lo último y se reintenta en el siguiente ciclo.
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
                VistaQrLlegada(llegada: l),
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

/// Envuelve la pantalla principal: cuando el arquitecto llega, abre una
/// alerta con el QR aunque el cliente esté en otra pestaña o pantalla.
class VigilanteLlegada extends StatefulWidget {
  const VigilanteLlegada({super.key, required this.child, this.intervalo = const Duration(seconds: 8)});

  final Widget child;
  final Duration intervalo;

  @override
  State<VigilanteLlegada> createState() => _VigilanteLlegadaState();
}

class _VigilanteLlegadaState extends State<VigilanteLlegada> {
  Timer? _timer;
  bool _pidiendo = false;

  /// Claves (QR) que ya se avisaron: la alerta sale una vez por llegada.
  final _avisadas = <String>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.intervalo, (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Citas de HOY confirmadas o en camino: las únicas donde puede llegar alguien.
  List<Cita> _candidatas() {
    final datos = AppScope.read(context).datos;
    if (datos == null) return const [];
    final hoy = DateTime.now();
    return datos.citas.where((c) {
      if (c.estado.clave != 'confirmada' && c.estado.clave != 'en_camino') return false;
      final f = parseFecha(c.fecha)?.toLocal();
      return f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    }).toList();
  }

  Future<void> _consultar() async {
    if (_pidiendo || !mounted) return;
    final citas = _candidatas();
    if (citas.isEmpty) return;
    _pidiendo = true;
    try {
      final app = AppScope.read(context);
      var refrescar = false;
      for (final c in citas) {
        final l = await app.llegada(c.id);
        if (!mounted) return;
        // El estado de la lista se quedó atrás (el arquitecto ya salió o ya llegó).
        if ((l.estado == 'esperando' || l.estado == 'listo') && c.estado.clave == 'confirmada') refrescar = true;
        if (l.estado == 'llego') refrescar = true;
        if (l.listo && _avisadas.add(l.qr!)) {
          // ignore: unawaited_futures
          showDialog<void>(
            context: context,
            builder: (_) => _DialogoLlegada(cita: c, inicial: l),
          );
        }
      }
      if (refrescar && mounted) await app.refrescar();
    } catch (_) {
      // Sin señal: se reintenta en el siguiente ciclo.
    } finally {
      _pidiendo = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// La alerta: "Tu arquitecto llegó" con el QR. Se cierra sola cuando el
/// arquitecto escanea (la cita pasa a "En visita").
class _DialogoLlegada extends StatefulWidget {
  const _DialogoLlegada({required this.cita, required this.inicial});

  final Cita cita;
  final LlegadaCita inicial;

  @override
  State<_DialogoLlegada> createState() => _DialogoLlegadaState();
}

class _DialogoLlegadaState extends State<_DialogoLlegada> {
  late LlegadaCita _l = widget.inicial;
  Timer? _timer;
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _consultar());
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
      final l = await app.llegada(widget.cita.id);
      if (!mounted) return;
      if (l.estado == 'llego') {
        _timer?.cancel();
        Navigator.of(context).pop();
        await app.refrescar();
        return;
      }
      setState(() => _l = l);
    } catch (_) {
      // Sin señal: se queda el último QR.
    } finally {
      _pidiendo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.cita.arquitecto;
    return AlertDialog(
      key: const Key('alertaLlegada'),
      title: Text(nombre == null ? '¡Tu arquitecto llegó!' : '¡$nombre llegó!', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pídele que escanee este código para comenzar la visita.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            if (_l.listo)
              VistaQrLlegada(llegada: _l)
            else
              Text(_l.texto, textAlign: TextAlign.center, style: const TextStyle(color: MoblarColors.textSecondary)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
