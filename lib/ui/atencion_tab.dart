import 'package:flutter/material.dart';

import '../config.dart';
import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import 'widgets/comunes.dart';

/// Atención a clientes: WhatsApp y llamada. Por ahora Moblar atiende a todas
/// las marcas (decisión 2026-09-27); cuando lleguen los datos de cada
/// empresa, el servidor mandará el contacto que corresponda y esta pantalla
/// no cambia.
class AtencionTab extends StatelessWidget {
  const AtencionTab({super.key, required this.datos});

  final Inicio datos;

  @override
  Widget build(BuildContext context) {
    final contacto = datos.contacto;
    final telefono = contacto.telefono.isNotEmpty ? contacto.telefono : AppConfig.telefonoAtencion;
    final whatsapp = contacto.whatsapp.isNotEmpty ? contacto.whatsapp : '52$telefono';

    return ListaRefrescable(
      onRefrescar: AppScope.read(context).refrescar,
      children: [
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.support_agent, size: 48, color: MoblarColors.primary),
                const SizedBox(height: 12),
                const Text(
                  'Estamos para ayudarte',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Escríbenos o llámanos y una persona del equipo de ${contacto.empresa} '
                  'te atiende con gusto.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MoblarColors.textSecondary),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('botonWhatsApp'),
                  onPressed: () => abrirEnlace(
                    context,
                    enlaceWhatsApp(whatsapp, mensaje: _saludo()),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('botonLlamar'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => abrirEnlace(context, Uri(scheme: 'tel', path: telefono)),
                  icon: const Icon(Icons.call_outlined),
                  label: Text('Llamar al ${_telefonoLegible(telefono)}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _Consejo(
          icono: Icons.lock_outline,
          texto: 'Tu código de acceso es personal. Nadie de nuestro equipo te lo pedirá '
              'por teléfono ni por mensaje.',
        ),
        const _Consejo(
          icono: Icons.refresh,
          texto: 'Desliza hacia abajo en cualquier sección para ver la información más reciente.',
        ),
      ],
    );
  }

  String _saludo() {
    final nombre = datos.nombre;
    return nombre == null ? 'Hola, necesito ayuda.' : 'Hola, soy $nombre. Necesito ayuda.';
  }
}

/// "5530768296" → "55 3076 8296"
String _telefonoLegible(String t) {
  final d = t.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return t;
  return '${d.substring(0, 2)} ${d.substring(2, 6)} ${d.substring(6)}';
}

class _Consejo extends StatelessWidget {
  const _Consejo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: MoblarColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: const TextStyle(fontSize: 13, color: MoblarColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
