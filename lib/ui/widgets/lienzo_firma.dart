import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';

// ---------------------------------------------------------------------------
// Firma con canvas (Carlos, 2026-10-26): el cliente firma con el dedo su
// cotización formal. Se guarda como PNG (fondo blanco, tinta oscura), igual
// que la firma del arquitecto en MOBLAR_ARQ y la que captura el wizard del ERP.
// ---------------------------------------------------------------------------

/// Los trazos de la firma. Un trazo = la línea de un dedo sin levantarlo.
class FirmaController extends ChangeNotifier {
  final List<List<Offset>> _trazos = [];
  Size _tamano = Size.zero;

  List<List<Offset>> get trazos => List.unmodifiable(_trazos);

  /// Cuántos puntos lleva dibujados en total.
  int get puntos => _trazos.fold(0, (n, t) => n + t.length);

  /// Un toque suelto no es firma: hacen falta varios puntos.
  bool get firmada => puntos >= 8;

  void _empezar(Offset p) {
    _trazos.add([p]);
    notifyListeners();
  }

  void _seguir(Offset p) {
    if (_trazos.isEmpty) return;
    _trazos.last.add(p);
    notifyListeners();
  }

  void borrar() {
    if (_trazos.isEmpty) return;
    _trazos.clear();
    notifyListeners();
  }

  /// La firma como PNG, al tamaño en que se dibujó por [escala].
  Future<Uint8List> aPng({double escala = 2}) => firmaPng(_trazos, _tamano, escala: escala);
}

/// Dibuja [trazos] en un PNG de [tamano] × [escala], con fondo blanco.
Future<Uint8List> firmaPng(List<List<Offset>> trazos, Size tamano, {double escala = 2}) async {
  final ancho = (tamano.width <= 0 ? 320 : tamano.width) * escala;
  final alto = (tamano.height <= 0 ? 160 : tamano.height) * escala;
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  lienzo.scale(escala);
  lienzo.drawRect(Offset.zero & Size(ancho / escala, alto / escala), Paint()..color = Colors.white);
  _pintarTrazos(lienzo, trazos);
  final imagen = await grabadora.endRecording().toImage(ancho.ceil(), alto.ceil());
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  if (datos == null) throw StateError('No se pudo generar la imagen de la firma.');
  return datos.buffer.asUint8List();
}

final _tinta = Paint()
  ..color = const Color(0xFF0F172A)
  ..strokeWidth = 2.6
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;

void _pintarTrazos(Canvas canvas, List<List<Offset>> trazos) {
  for (final t in trazos) {
    if (t.isEmpty) continue;
    if (t.length == 1) {
      canvas.drawCircle(t.first, 1.4, Paint()..color = _tinta.color);
      continue;
    }
    final path = Path()..moveTo(t.first.dx, t.first.dy);
    for (final p in t.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, _tinta);
  }
}

/// El recuadro donde se firma, con "Borrar".
class LienzoFirma extends StatelessWidget {
  const LienzoFirma({super.key, required this.controller, this.alto = 180});

  final FirmaController controller;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: alto,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MoblarColors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, caja) {
                controller._tamano = Size(caja.maxWidth, caja.maxHeight);
                return RawGestureDetector(
                  key: const Key('lienzoFirma'),
                  behavior: HitTestBehavior.opaque,
                  // Gana el gesto apenas toca: si no, la lista de la página
                  // se lleva el trazo vertical como desplazamiento.
                  gestures: {
                    _PanInmediato: GestureRecognizerFactoryWithHandlers<_PanInmediato>(
                      _PanInmediato.new,
                      (r) => r
                        ..onStart = ((d) => controller._empezar(d.localPosition))
                        ..onUpdate = ((d) => controller._seguir(d.localPosition)),
                    ),
                  },
                  child: CustomPaint(
                    painter: _PintorFirma(controller.trazos),
                    child: controller.trazos.isEmpty
                        ? const Center(
                            child: Text(
                              'Firma aquí con tu dedo',
                              style: TextStyle(color: MoblarColors.textMuted),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('borrarFirma'),
              onPressed: controller.trazos.isEmpty ? null : controller.borrar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Borrar y volver a firmar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanInmediato extends PanGestureRecognizer {
  _PanInmediato() {
    // El trazo empieza donde se apoyó el dedo, no después del primer movimiento.
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _PintorFirma extends CustomPainter {
  _PintorFirma(this.trazos);

  final List<List<Offset>> trazos;

  @override
  void paint(Canvas canvas, Size size) => _pintarTrazos(canvas, trazos);

  @override
  bool shouldRepaint(_PintorFirma old) => true;
}
