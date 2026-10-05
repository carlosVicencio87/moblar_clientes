import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/app_scope.dart';
import '../../theme.dart';
import 'comunes.dart';

/// Imagen del diseño (Moblo), tonos y "lo que incluye tu pedido".
///
/// Se pide al servidor al mostrarse (la imagen es una URL firmada que vence):
/// no viaja en /inicio para no hacerlo pesado.
class DetalleMueble extends StatefulWidget {
  const DetalleMueble({super.key, required this.proyectoId});

  final String proyectoId;

  @override
  State<DetalleMueble> createState() => _DetalleMuebleState();
}

class _DetalleMuebleState extends State<DetalleMueble> {
  Future<DetalleProyecto>? _carga;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carga ??= AppScope.read(context).detalleProyecto(widget.proyectoId);
  }

  void _reintentar() {
    setState(() => _carga = AppScope.read(context).detalleProyecto(widget.proyectoId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DetalleProyecto>(
      future: _carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          // SesionTerminada: AppState ya regresó al ingreso.
          if (snap.error is SesionTerminada) return const SizedBox.shrink();
          final mensaje = snap.error is ApiException
              ? (snap.error as ApiException).mensaje
              : const ErrorServidor().mensaje;
          return Card(
            key: const Key('detalleMuebleError'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(mensaje, style: const TextStyle(color: MoblarColors.textSecondary)),
                  ),
                  TextButton(onPressed: _reintentar, child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        final d = snap.data!;
        if (!d.tieneContenido) return const SizedBox.shrink();
        return Column(
          key: const Key('detalleMueble'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.imagenDiseno != null) ...[
              _Diseno(url: d.imagenDiseno!, titulo: d.mueble),
              const SizedBox(height: 16),
            ],
            if (d.tonos.isNotEmpty) ...[
              _Tonos(tonos: d.tonos),
              const SizedBox(height: 16),
            ],
            if (d.medidas != null || d.incluye.isNotEmpty || d.piezas.isNotEmpty || d.porTuCuenta.isNotEmpty)
              _Incluye(detalle: d),
          ],
        );
      },
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MoblarColors.textPrimary),
      );
}

class _Diseno extends StatelessWidget {
  const _Diseno({required this.url, this.titulo});

  final String url;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('disenoMueble'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _Titulo('Tu diseño'),
          ),
          InkWell(
            onTap: () => ampliarImagen(context, url, titulo: titulo),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                semanticLabel: 'Diseño de tu mueble',
                loadingBuilder: (_, hijo, progreso) => progreso == null
                    ? hijo
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'No pudimos cargar la imagen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MoblarColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Toca la imagen para verla completa.',
              style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre la imagen a pantalla completa con zoom.
void ampliarImagen(BuildContext context, String url, {String? titulo}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(titulo ?? 'Tu diseño'),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// "#8B5A2B" → Color; null si no es válido.
Color? colorDeHex(String? hex) {
  final v = (hex ?? '').replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) return null;
  return Color(int.parse('FF$v', radix: 16));
}

class _Tonos extends StatelessWidget {
  const _Tonos({required this.tonos});

  final List<Tono> tonos;

  @override
  Widget build(BuildContext context) {
    final conFotos = tonos.where((t) => t.tieneFotos).toList();
    final sinFotos = tonos.where((t) => !t.tieneFotos).toList();
    return Card(
      key: const Key('tonosMueble'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Titulo('Tonos'),
            if (conFotos.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text(
                'Toca un tono para verlo en grande.',
                style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final t in conFotos) _MuestraTono(tono: t)],
              ),
            ],
            if (sinFotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in sinFotos) _ChipTono(tono: t)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Miniatura (300×300) con el nombre debajo; abre la galería.
class _MuestraTono extends StatelessWidget {
  const _MuestraTono({required this.tono});

  final Tono tono;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    final t = tono;
    final fotos = [for (final r in (t.galeria.isNotEmpty ? t.galeria : [t.miniatura!])) api.recurso(r)];
    return SizedBox(
      width: 88,
      child: InkWell(
        key: Key('muestraTono-${t.nombre}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GaleriaTonoPage(nombre: t.nombre, imagenes: fotos),
          ),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 88,
                height: 88,
                color: colorDeHex(t.hex) ?? MoblarColors.surfaceSubtle,
                child: t.miniatura == null
                    ? null
                    : Image.network(
                        api.recurso(t.miniatura!),
                        fit: BoxFit.cover,
                        semanticLabel: 'Muestra del tono ${t.nombre}',
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: MoblarColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tono sin fotos: el círculo de color de siempre.
class _ChipTono extends StatelessWidget {
  const _ChipTono({required this.tono});

  final Tono tono;

  @override
  Widget build(BuildContext context) {
    final t = tono;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: MoblarColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MoblarColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: colorDeHex(t.hex) ?? MoblarColors.primaryTint,
              shape: BoxShape.circle,
              border: Border.all(color: MoblarColors.border),
            ),
            child: colorDeHex(t.hex) == null
                ? const Icon(Icons.palette_outlined, size: 14, color: MoblarColors.primaryDark)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(t.nombre, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Galería a pantalla completa de un tono (1600×1200), con zoom y deslizar.
class GaleriaTonoPage extends StatefulWidget {
  const GaleriaTonoPage({super.key, required this.nombre, required this.imagenes});

  final String nombre;

  /// URL completas.
  final List<String> imagenes;

  @override
  State<GaleriaTonoPage> createState() => _GaleriaTonoPageState();
}

class _GaleriaTonoPageState extends State<GaleriaTonoPage> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.imagenes.length;
    return Scaffold(
      key: const Key('galeriaTono'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.nombre),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: n,
              onPageChanged: (i) => setState(() => _actual = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    widget.imagenes[i],
                    fit: BoxFit.contain,
                    semanticLabel: '${widget.nombre}, foto ${i + 1} de $n',
                    loadingBuilder: (_, hijo, progreso) => progreso == null
                        ? hijo
                        : const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    errorBuilder: (_, _, _) => const Text(
                      'No pudimos cargar la imagen.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (n > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < n; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _actual ? Colors.white : Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Text(
              'Foto de referencia: el tono real puede variar un poco con la luz y la pantalla.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Incluye extends StatelessWidget {
  const _Incluye({required this.detalle});

  final DetalleProyecto detalle;

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    return Card(
      key: const Key('incluyeMueble'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Titulo('Lo que incluye tu pedido'),
            if (d.medidas != null) Dato(icono: Icons.straighten, texto: 'Medidas generales: ${d.medidas}'),
            if (d.incluye.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final t in d.incluye) _Renglon(icono: Icons.check_circle_outline, texto: t),
            ],
            if (d.piezas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'PIEZAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: MoblarColors.textMuted,
                ),
              ),
              for (final p in d.piezas) _RenglonPieza(pieza: p),
            ],
            if (d.porTuCuenta.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'CORRE POR TU CUENTA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: MoblarColors.textMuted,
                ),
              ),
              for (final t in d.porTuCuenta) _Renglon(icono: Icons.info_outline, texto: t),
            ],
          ],
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: MoblarColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(color: MoblarColors.textPrimary))),
        ],
      ),
    );
  }
}

class _RenglonPieza extends StatelessWidget {
  const _RenglonPieza({required this.pieza});

  final PiezaPedido pieza;

  @override
  Widget build(BuildContext context) {
    final p = pieza;
    final datos = [
      p.medidas,
      if (p.fondo != null) 'fondo ${p.fondo}',
      p.tono,
    ].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.cantidad > 1 ? '${p.nombre} × ${p.cantidad}' : p.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600, color: MoblarColors.textPrimary),
          ),
          if (datos.isNotEmpty)
            Text(datos, style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Página con el detalle del mueble, para abrirlo desde una cotización.
class DetalleMueblePage extends StatelessWidget {
  const DetalleMueblePage({super.key, required this.proyectoId, this.titulo});

  final String proyectoId;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo ?? 'Tu mueble')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [DetalleMueble(proyectoId: proyectoId)],
      ),
    );
  }
}
