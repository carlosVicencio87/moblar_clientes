import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'adquirir_oferta.dart';
import 'pago_visita.dart';

// ---------------------------------------------------------------------------
// Fin de la visita (Carlos, 2026-10-08).
//
// Cuando el arquitecto termina la visita y deja su propuesta, la app del
// cliente abre una pantalla — esté donde esté — que le pide indicar cómo va a
// cubrir la visita:
//   - Iniciar su proyecto: la visita NO se cobra (si ya la había pagado, se
//     abona a lo que paga hoy; ver adquirir_oferta.dart).
//   - Por ahora pagar solo la visita (efectivo con PIN o transferencia).
//   - Decidir después: la propuesta queda en Cotizaciones y la visita en su
//     cita como "Pendiente".
// Primero ve la propuesta y después decide. Solo aplica con pago de visita y
// oferta (hoy: deployment de prueba, modo demostración); en producción no
// aparece nada.
// ---------------------------------------------------------------------------

/// Costo de la visita de [citaId] (0 si la cita no trae pago de visita).
num montoVisitaDe(Inicio datos, String citaId) {
  for (final c in datos.citas) {
    if (c.id == citaId) return c.pagoVisita?.monto ?? 0;
  }
  return 0;
}

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Visita que terminó HOY, con propuesta, y que el cliente todavía no cubre
/// (ni inició su proyecto ni pagó la visita). null si no hay.
({Cita cita, OfertaVisita oferta})? visitaPorCubrir(
  Inicio datos,
  DateTime ahora, {
  Set<String> omitir = const {},
}) {
  for (final o in datos.ofertasVisita) {
    if (omitir.contains(o.citaId) || !o.adquirible) continue;
    if (DemoAnticipos.resultados.value.containsKey(o.citaId)) continue;
    if (DemoPagosVisita.resultados.value.containsKey(o.citaId)) continue;
    Cita? cita;
    for (final c in datos.citas) {
      if (c.id == o.citaId) cita = c;
    }
    if (cita == null || cita.estado.clave != 'realizada' || cita.pagoVisita == null) continue;
    final f = parseFecha(cita.fecha)?.toLocal();
    if (f == null || !_mismoDia(f, ahora)) continue;
    return (cita: cita, oferta: o);
  }
  return null;
}

/// Envuelve la pantalla principal. Mientras hay una visita en curso hoy
/// refresca cada [intervalo]; cuando termina (o al abrir la app ya terminada)
/// abre [VisitaTerminadaPage] una vez por cita en esta sesión.
class VigilanteFinVisita extends StatefulWidget {
  const VigilanteFinVisita({super.key, required this.child, this.intervalo = const Duration(seconds: 15)});

  final Widget child;
  final Duration intervalo;

  @override
  State<VigilanteFinVisita> createState() => _VigilanteFinVisitaState();
}

class _VigilanteFinVisitaState extends State<VigilanteFinVisita> {
  Timer? _timer;
  AppState? _app;
  bool _pidiendo = false;
  bool _abierta = false;

  /// Citas cuya pantalla ya se mostró en esta sesión.
  final _mostradas = <String>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.intervalo, (_) => _sondear());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (!identical(app, _app)) {
      _app?.removeListener(_revisar);
      _app = app..addListener(_revisar);
      WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _app?.removeListener(_revisar);
    super.dispose();
  }

  /// Solo pregunta al servidor si hay una visita en curso hoy.
  Future<void> _sondear() async {
    final app = _app;
    final datos = app?.datos;
    if (app == null || datos == null || _pidiendo || !mounted) return;
    final hoy = DateTime.now();
    final enVisita = datos.citas.any((c) {
      if (c.estado.clave != 'en_visita') return false;
      final f = parseFecha(c.fecha)?.toLocal();
      return f != null && _mismoDia(f, hoy);
    });
    if (!enVisita) return;
    _pidiendo = true;
    try {
      await app.refrescar(); // avisa a _revisar al terminar
    } catch (_) {
      // Sin señal: se reintenta en el siguiente ciclo.
    } finally {
      _pidiendo = false;
    }
  }

  void _revisar() {
    final datos = _app?.datos;
    if (!mounted || _abierta || datos == null) return;
    final v = visitaPorCubrir(datos, DateTime.now(), omitir: _mostradas);
    if (v == null) return;
    _mostradas.add(v.cita.id);
    _abierta = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _abierta = false;
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => VisitaTerminadaPage(cita: v.cita, oferta: v.oferta),
        ),
      );
      _abierta = false;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Tu visita terminó": la propuesta y cómo va a cubrir la visita.
class VisitaTerminadaPage extends StatelessWidget {
  const VisitaTerminadaPage({super.key, required this.cita, required this.oferta});

  final Cita cita;
  final OfertaVisita oferta;

  /// Abre [pagina]; si al volver ya cubrió la visita (compró o pagó), cierra.
  Future<void> _ir(BuildContext context, Widget pagina) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pagina));
    if (!context.mounted) return;
    final cubierta = DemoAnticipos.resultados.value.containsKey(cita.id) ||
        DemoPagosVisita.resultados.value.containsKey(cita.id);
    if (cubierta) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pago = cita.pagoVisita!;
    final o = oferta;
    final nombre = cita.arquitecto ?? o.arquitecto;
    final imagen = o.imagenDiseno;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu visita terminó')),
      body: ListView(
        key: const Key('visitaTerminada'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (o.demo || pago.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          Text(
            nombre == null ? 'Tu arquitecto terminó tu visita' : '$nombre terminó tu visita',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            'Te dejó la propuesta para ${muebleDe(o)}. Revísala y por favor indica cómo vas a cubrir tu visita.',
            style: const TextStyle(color: MoblarColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Card(
            key: const Key('propuestaFinVisita'),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imagen != null)
                  Container(
                    height: 200,
                    color: MoblarColors.surfaceSubtle,
                    child: Image.network(
                      imagen,
                      fit: BoxFit.contain,
                      semanticLabel: 'Diseño de tu mueble',
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: MoblarColors.textMuted),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'TU PROPUESTA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: MoblarColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dinero(o.precioContado),
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: MoblarColors.primaryDark,
                        ),
                      ),
                      const Text('de contado', style: TextStyle(color: MoblarColors.textMuted)),
                      if (o.meses > 0 && o.mensualidad > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'o ${o.meses} meses sin intereses de ${dinero(o.mensualidad)}',
                            style: const TextStyle(color: MoblarColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Cómo vas a cubrir tu visita?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _Eleccion(
            clave: const Key('finVisitaIniciar'),
            icono: Icons.shopping_bag_outlined,
            destacada: true,
            titulo: 'Iniciar mi proyecto',
            texto: 'Tu visita (${dinero(pago.monto)}) no tiene costo. '
                'Anticipo de ${dinero(o.anticipoContado)} de contado, o con tarjeta.',
            onTap: () => _ir(context, AdquirirOfertaPage(oferta: o, montoVisita: pago.monto)),
          ),
          _Eleccion(
            clave: const Key('finVisitaPagar'),
            icono: Icons.payments_outlined,
            titulo: 'Por ahora, pagar solo mi visita · ${dinero(pago.monto)}',
            texto: 'Tu propuesta queda en Cotizaciones. Si después inicias tu proyecto, '
                'este pago se abona a tu anticipo.',
            onTap: () => _ir(context, PagarVisitaPage(cita: cita, pago: pago)),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              key: const Key('finVisitaDespues'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Decidir después'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eleccion extends StatelessWidget {
  const _Eleccion({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
    this.destacada = false,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: clave,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: destacada ? MoblarColors.primary : MoblarColors.border,
          width: destacada ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: MoblarColors.primarySoft,
                child: Icon(icono, color: MoblarColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(texto, style: const TextStyle(color: MoblarColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
