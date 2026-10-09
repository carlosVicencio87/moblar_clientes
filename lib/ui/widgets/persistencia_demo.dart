import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import 'adquirir_oferta.dart' show DemoAnticipos, ResultadoAnticipo;
import 'pago_visita.dart' show DemoPagosVisita, ResultadoPagoVisita;

// ---------------------------------------------------------------------------
// La demostración sobrevive a recargar la página (Carlos, 2026-10-09).
//
// El anticipo, los abonos y el pago de la visita de la demo no se guardan en
// el ERP; viven en memoria. Este widget los guarda en el teléfono (o en el
// navegador) y los restaura al abrir la app. Se borran al cerrar sesión
// (AppState) o con "Reiniciar demostración".
// ---------------------------------------------------------------------------

Map<String, dynamic> anticipoAJson(ResultadoAnticipo r) => {
      'metodo': r.metodo,
      'monto': r.monto,
      'fecha': r.fecha.toIso8601String(),
      'arquitecto': r.arquitecto,
      'meses': r.meses,
      'totalMueble': r.totalMueble,
      'liquida': r.liquida,
      'factura': r.factura,
      'abonoVisita': r.abonoVisita,
    };

ResultadoAnticipo? anticipoDeJson(Object? v) {
  if (v is! Map) return null;
  final f = DateTime.tryParse('${v['fecha']}');
  final m = v['monto'];
  if (f == null || m is! num || v['metodo'] is! String) return null;
  return ResultadoAnticipo(
    metodo: v['metodo'] as String,
    monto: m,
    fecha: f,
    arquitecto: v['arquitecto'] is String ? v['arquitecto'] as String : null,
    meses: v['meses'] is num ? (v['meses'] as num).toInt() : 1,
    totalMueble: v['totalMueble'] is num ? v['totalMueble'] as num : null,
    liquida: v['liquida'] == true,
    factura: v['factura'] != false,
    abonoVisita: v['abonoVisita'] is num ? v['abonoVisita'] as num : 0,
  );
}

Map<String, dynamic> pagoVisitaAJson(ResultadoPagoVisita r) => {
      'metodo': r.metodo,
      'fecha': r.fecha.toIso8601String(),
      'arquitecto': r.arquitecto,
      'archivo': r.archivo,
    };

ResultadoPagoVisita? pagoVisitaDeJson(Object? v) {
  if (v is! Map) return null;
  final f = DateTime.tryParse('${v['fecha']}');
  if (f == null || v['metodo'] is! String) return null;
  return ResultadoPagoVisita(
    metodo: v['metodo'] as String,
    fecha: f,
    arquitecto: v['arquitecto'] is String ? v['arquitecto'] as String : null,
    archivo: v['archivo'] is String ? v['archivo'] as String : null,
  );
}

/// Todo el estado de la demo en un JSON.
String demoAJson(AppState app) => jsonEncode({
      'v': 1,
      'anticipos': {
        for (final e in DemoAnticipos.resultados.value.entries) e.key: anticipoAJson(e.value),
      },
      'visitas': {
        for (final e in DemoPagosVisita.resultados.value.entries) e.key: pagoVisitaAJson(e.value),
      },
      'abonos': {
        for (final e in app.abonosDemo.entries) e.key: [for (final a in e.value) a.toJson()],
      },
    });

/// Restaura lo guardado. Un JSON dañado o de otra versión se ignora.
void restaurarDemo(String? json, AppState app) {
  if (json == null) return;
  Object? d;
  try {
    d = jsonDecode(json);
  } catch (_) {
    return;
  }
  if (d is! Map || d['v'] != 1) return;
  Map<String, T> mapa<T>(Object? m, T? Function(Object?) leer) {
    final r = <String, T>{};
    if (m is Map) {
      for (final e in m.entries) {
        final x = leer(e.value);
        if (x != null) r['${e.key}'] = x;
      }
    }
    return r;
  }

  DemoAnticipos.resultados.value = mapa(d['anticipos'], anticipoDeJson);
  DemoPagosVisita.resultados.value = mapa(d['visitas'], pagoVisitaDeJson);
  app.restaurarAbonosDemo(mapa<List<AbonoDemo>>(d['abonos'], (v) {
    if (v is! List) return null;
    final l = v.map(AbonoDemo.fromJson).whereType<AbonoDemo>().toList();
    return l.isEmpty ? null : l;
  }));
}

/// Envuelve la pantalla principal: restaura al entrar y guarda cada cambio.
class PersistenciaDemo extends StatefulWidget {
  const PersistenciaDemo({super.key, required this.child});

  final Widget child;

  @override
  State<PersistenciaDemo> createState() => _PersistenciaDemoState();
}

class _PersistenciaDemoState extends State<PersistenciaDemo> {
  AppState? _app;
  bool _listo = false;
  Timer? _guardar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (identical(app, _app)) return;
    _quitar();
    _app = app;
    _cargar(app);
  }

  Future<void> _cargar(AppState app) async {
    restaurarDemo(await app.demo.leer(), app);
    if (!mounted || !identical(app, _app)) return;
    _listo = true;
    DemoAnticipos.resultados.addListener(_cambio);
    DemoPagosVisita.resultados.addListener(_cambio);
    app.addListener(_cambio);
  }

  void _cambio() {
    if (!_listo) return;
    _guardar?.cancel();
    _guardar = Timer(const Duration(milliseconds: 300), () {
      final app = _app;
      // Sin sesión (cerró sesión) no se vuelve a guardar nada.
      if (app == null || app.estado != EstadoApp.conSesion || app.datos == null) return;
      app.demo.guardar(demoAJson(app));
    });
  }

  void _quitar() {
    _guardar?.cancel();
    DemoAnticipos.resultados.removeListener(_cambio);
    DemoPagosVisita.resultados.removeListener(_cambio);
    _app?.removeListener(_cambio);
    _listo = false;
  }

  @override
  void dispose() {
    _quitar();
    // Al cerrar sesión la demo se va con ella (AppState ya borró lo guardado).
    if (_app?.estado != EstadoApp.conSesion) {
      DemoAnticipos.resultados.value = const {};
      DemoPagosVisita.resultados.value = const {};
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
