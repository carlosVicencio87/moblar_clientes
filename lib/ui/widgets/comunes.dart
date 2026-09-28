import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../theme.dart';

/// Logo y nombre de la empresa que atiende el pedido. Es lo único que cambia
/// entre marcas (decisión 2026-09-27): el resto de la tarjeta es idéntico.
class MarcaEncabezado extends StatelessWidget {
  const MarcaEncabezado({super.key, required this.marca, this.trailing});

  final Marca marca;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            color: MoblarColors.surface,
            child: Image.asset(marca.asset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            marca.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: MoblarColors.textSecondary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Pastilla de estado ("Confirmada", "Fabricación", …).
class EstadoChip extends StatelessWidget {
  const EstadoChip({
    super.key,
    required this.texto,
    this.color = MoblarColors.primaryDark,
    this.fondo = MoblarColors.primarySoft,
  });

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Renglón ícono + texto dentro de una tarjeta.
class Dato extends StatelessWidget {
  const Dato({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: MoblarColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: const TextStyle(color: MoblarColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Pantalla vacía amable ("Todavía no tienes citas").
class VistaVacia extends StatelessWidget {
  const VistaVacia({super.key, required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        children: [
          Icon(icono, size: 56, color: MoblarColors.primaryTint),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MoblarColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MoblarColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Título de sección dentro de una lista.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: MoblarColors.textMuted,
        ),
      ),
    );
  }
}

/// Abre un enlace fuera de la app (WhatsApp, marcador, PDF). Si el teléfono
/// no puede abrirlo, avisa en vez de fallar en silencio.
Future<void> abrirEnlace(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No pudimos abrir el enlace en este teléfono.')),
    );
  }
}

/// Enlace de WhatsApp con mensaje prellenado. [numero] ya con lada de país
/// o como URL completa de wa.me.
Uri enlaceWhatsApp(String numeroOUrl, {String? mensaje}) {
  final base = numeroOUrl.startsWith('http')
      ? Uri.parse(numeroOUrl)
      : Uri.parse('https://wa.me/${numeroOUrl.replaceAll(RegExp(r'\D'), '')}');
  return mensaje == null ? base : base.replace(queryParameters: {'text': mensaje});
}

/// Lista con "jalar para actualizar" que vuelve a pedir /inicio.
class ListaRefrescable extends StatelessWidget {
  const ListaRefrescable({super.key, required this.onRefrescar, required this.children});

  final Future<void> Function() onRefrescar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: children,
      ),
    );
  }
}
