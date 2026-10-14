// Aviso de llegada del arquitecto dentro de la app (feedback de arquitectura,
// 2026-10-14). Mientras no haya notificaciones push (Firebase), con la app
// abierta el cliente ve en el inicio:
//   - "Tu arquitecto va en camino" (en_camino)
//   - "Tu arquitecto llegó" (en_visita)
// y un aviso flotante una vez por cambio.
//
// Para enterarse sin que el cliente recargue, mientras tenga una cita de HOY
// por ocurrir (confirmada, en camino o en visita) se vuelve a pedir /inicio
// cada [intervalo]. Fuera de eso no consulta nada.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';
import '../../util/formato.dart';

/// Lo que el aviso tiene que decir para una cita, o null si nada.
String? textoAvisoArquitecto(Cita c) {
  final quien = (c.arquitecto ?? '').trim().isEmpty ? 'Tu arquitecto' : 'Tu arquitecto ${c.arquitecto!.trim()}';
  return switch (c.estado.clave) {
    'en_camino' => '$quien va en camino.',
    'en_visita' => '$quien llegó.',
    _ => null,
  };
}

bool _esHoy(Cita c, DateTime ahora) {
  final f = parseFecha(c.fecha)?.toLocal();
  return f != null && f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
}

/// Citas de hoy que todavía pueden cambiar de estado por el arquitecto.
List<Cita> citasPorVigilar(List<Cita> citas, DateTime ahora) => [
      for (final c in citas)
        if (_esHoy(c, ahora) && const ['confirmada', 'en_camino', 'en_visita'].contains(c.estado.clave)) c,
    ];

class AvisoArquitecto extends StatefulWidget {
  const AvisoArquitecto({super.key, this.intervalo = const Duration(seconds: 30)});

  final Duration intervalo;

  @override
  State<AvisoArquitecto> createState() => _AvisoArquitectoState();
}

class _AvisoArquitectoState extends State<AvisoArquitecto> {
  Timer? _timer;

  /// Último estado visto por cita: el aviso flotante sale solo al cambiar.
  final _vistos = <String, String>{};

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

  Future<void> _consultar() async {
    if (!mounted) return;
    final app = AppScope.read(context);
    final datos = app.datos;
    if (datos == null || app.cargando) return;
    if (citasPorVigilar(datos.citas, DateTime.now()).isEmpty) return;
    await app.refrescar();
  }

  void _avisarCambios(List<Cita> citas) {
    for (final c in citas) {
      final antes = _vistos[c.id];
      _vistos[c.id] = c.estado.clave;
      final texto = textoAvisoArquitecto(c);
      // La primera vez que se ve la cita no se avisa (es el estado inicial).
      if (antes == null || antes == c.estado.clave || texto == null) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = AppScope.of(context).datos;
    if (datos == null) return const SizedBox.shrink();
    final hoy = citasPorVigilar(datos.citas, DateTime.now());
    _avisarCambios(hoy);
    final activas = [for (final c in hoy) if (textoAvisoArquitecto(c) != null) c];
    if (activas.isEmpty) return const SizedBox.shrink();
    final c = activas.first;
    final llego = c.estado.clave == 'en_visita';
    return Material(
      key: const Key('avisoArquitecto'),
      color: llego ? const Color(0xFFD1FAE5) : MoblarColors.amberSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(llego ? Icons.home_outlined : Icons.directions_car_outlined,
                color: llego ? const Color(0xFF065F46) : const Color(0xFF92400E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                textoAvisoArquitecto(c)!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: llego ? const Color(0xFF065F46) : const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
