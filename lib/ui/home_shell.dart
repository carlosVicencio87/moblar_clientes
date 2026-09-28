import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme.dart';
import 'atencion_tab.dart';
import 'citas_tab.dart';
import 'compras_tab.dart';
import 'cotizaciones_tab.dart';

/// Pantalla principal con la barra inferior:
/// Citas · Cotizaciones · Mi compra · Atención.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _citas = 0, _compra = 2;

  /// null hasta que llegan los datos: entonces se abre en "Mi compra" si el
  /// cliente ya compró (lo que más le interesa) o en "Citas" si no.
  int? _indice;

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Para volver a entrar necesitarás tu código de acceso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (salir == true && mounted) await AppScope.read(context).salir();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final datos = state.datos;
    if (datos != null) _indice ??= datos.compras.isNotEmpty ? _compra : _citas;

    final Widget cuerpo;
    if (datos == null) {
      cuerpo = state.errorCarga != null
          ? _ErrorCarga(mensaje: state.errorCarga!, onReintentar: state.refrescar)
          : const Center(child: CircularProgressIndicator());
    } else {
      cuerpo = Column(
        children: [
          if (state.errorCarga != null)
            _AvisoDesactualizado(mensaje: state.errorCarga!, onReintentar: state.refrescar),
          Expanded(
            child: IndexedStack(
              index: _indice!,
              children: [
                CitasTab(datos: datos),
                CotizacionesTab(datos: datos),
                ComprasTab(datos: datos),
                AtencionTab(datos: datos),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Image.asset('assets/brand/logo-moblar.png', height: 30),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _confirmarSalida,
          ),
        ],
      ),
      body: cuerpo,
      bottomNavigationBar: datos == null
          ? null
          : NavigationBar(
              selectedIndex: _indice!,
              onDestinationSelected: (i) => setState(() => _indice = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Citas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote),
                  label: 'Cotizaciones',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chair_outlined),
                  selectedIcon: Icon(Icons.chair),
                  label: 'Mi compra',
                ),
                NavigationDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent),
                  label: 'Atención',
                ),
              ],
            ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: MoblarColors.textMuted),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Ya hay datos pero el último refresco falló: se siguen mostrando los
/// anteriores con un aviso discreto.
class _AvisoDesactualizado extends StatelessWidget {
  const _AvisoDesactualizado({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MoblarColors.amberSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFF92400E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(mensaje, style: const TextStyle(color: Color(0xFF92400E), fontSize: 13)),
            ),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
