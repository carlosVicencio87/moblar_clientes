import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';

// ---------------------------------------------------------------------------
// Centro de avisos (Carlos, 2026-10-29): compras, pagos validados o
// rechazados, cotización formal lista y avance del mueble. Al abrirlo, todo
// queda visto. Tocar un aviso regresa a la sección que corresponde.
// ---------------------------------------------------------------------------

/// La campana con el número de avisos nuevos.
class CampanaAvisos extends StatelessWidget {
  const CampanaAvisos({super.key, required this.onIr});

  /// Destino del aviso que tocó (citas | cotizaciones | compra).
  final void Function(String destino) onIr;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final nuevos = state.avisosNuevos;
    return IconButton(
      key: const Key('campanaAvisos'),
      tooltip: nuevos == 0 ? 'Avisos' : '$nuevos avisos nuevos',
      icon: Badge(
        isLabelVisible: nuevos > 0,
        label: Text(nuevos > 9 ? '9+' : '$nuevos'),
        child: Icon(nuevos > 0 ? Icons.notifications_active_outlined : Icons.notifications_none),
      ),
      onPressed: () async {
        final destino = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const AvisosPage()),
        );
        if (destino != null) onIr(destino);
      },
    );
  }
}

class AvisosPage extends StatefulWidget {
  const AvisosPage({super.key});

  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  /// Lo que estaba sin ver al abrir: se marca como "nuevo" en la lista.
  Set<String>? _nuevos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      final avisos = state.datos?.avisos ?? const <Aviso>[];
      setState(() => _nuevos = {for (final a in avisos.take(state.avisosNuevos)) a.id});
      state.marcarAvisosVistos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final avisos = state.datos?.avisos ?? const <Aviso>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: avisos.isEmpty
          ? const VistaVacia(
              icono: Icons.notifications_none,
              titulo: 'Sin avisos por ahora',
              texto: 'Aquí te avisaremos de tus pagos, tu cotización y el avance de tu mueble.',
            )
          : ListaRefrescable(
              onRefrescar: state.refrescar,
              children: [
                for (final a in avisos)
                  _TarjetaAviso(
                    aviso: a,
                    nuevo: _nuevos?.contains(a.id) ?? false,
                    onTap: () => Navigator.of(context).pop(a.destino),
                  ),
              ],
            ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.nuevo, required this.onTap});

  final Aviso aviso;
  final bool nuevo;
  final VoidCallback onTap;

  IconData get _icono => switch (aviso.destino) {
        'compra' => Icons.chair_outlined,
        'citas' => Icons.event_outlined,
        _ => Icons.request_quote_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final m = aviso.momento?.toLocal();
    return Card(
      key: Key('aviso-${aviso.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: nuevo ? const Color(0xFFEFF6FF) : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(_icono, color: MoblarColors.primary),
        title: Text(aviso.titulo, style: TextStyle(fontWeight: nuevo ? FontWeight.w700 : FontWeight.w600)),
        subtitle: Text(
          '${aviso.texto}${m == null ? '' : '\n${fechaCorta(m)}'}',
          style: const TextStyle(color: MoblarColors.textSecondary),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
      ),
    );
  }
}
