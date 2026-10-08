import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme.dart';
import 'citas_tab.dart';
import 'compras_tab.dart';
import 'cotizaciones_tab.dart';
import 'widgets/llegada_qr.dart';
import 'widgets/visita_terminada.dart';

/// Pantalla principal con la barra inferior: Citas · Cotizaciones · Mi compra.
///
/// "Mi compra" solo aparece cuando el cliente ya compró algo (2026-09-29).
/// Sin compras, al entrar se abre directo el detalle de su próxima cita
/// (pedido del stakeholder, 2026-09-30); al regresar queda en Citas.
/// El contacto con atención a clientes vive dentro de cada sección.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum Seccion { citas, cotizaciones, compra }

class _HomeShellState extends State<HomeShell> {
  /// null hasta que llegan los datos: entonces se abre en "Mi compra" si el
  /// cliente ya compró (lo que más le interesa) o en "Citas" si no. Se guarda
  /// la SECCIÓN y no el índice, porque la barra cambia de tamaño cuando
  /// aparece "Mi compra".
  Seccion? _seccion;

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
    final hayCompras = datos != null && datos.compras.isNotEmpty;
    final secciones = [
      Seccion.citas,
      Seccion.cotizaciones,
      if (hayCompras) Seccion.compra,
    ];
    if (datos != null) {
      if (_seccion == null) {
        // Primera vez que llegan los datos en esta sesión (no al refrescar).
        final proxima = hayCompras ? null : CitasTab.proxima(datos, DateTime.now());
        if (proxima != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) abrirCita(context, proxima);
          });
        }
      }
      _seccion ??= hayCompras ? Seccion.compra : Seccion.citas;
      // Si la sección elegida desapareció (no debería), se vuelve a Citas.
      if (!secciones.contains(_seccion)) _seccion = Seccion.citas;
    }
    final indice = _seccion == null ? 0 : secciones.indexOf(_seccion!);

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
              index: indice,
              children: [
                for (final s in secciones)
                  switch (s) {
                    Seccion.citas => CitasTab(datos: datos),
                    Seccion.cotizaciones => CotizacionesTab(datos: datos),
                    Seccion.compra => ComprasTab(datos: datos),
                  },
              ],
            ),
          ),
        ],
      );
    }

    // Cuando el arquitecto llega, alerta con el QR esté donde esté el cliente;
    // cuando termina, la pantalla para cubrir la visita.
    return VigilanteFinVisita(
      child: VigilanteLlegada(
      child: Scaffold(
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
              selectedIndex: indice,
              onDestinationSelected: (i) => setState(() => _seccion = secciones[i]),
              destinations: [
                for (final s in secciones)
                  switch (s) {
                    Seccion.citas => const NavigationDestination(
                        icon: Icon(Icons.event_outlined),
                        selectedIcon: Icon(Icons.event),
                        label: 'Citas',
                      ),
                    Seccion.cotizaciones => const NavigationDestination(
                        icon: Icon(Icons.request_quote_outlined),
                        selectedIcon: Icon(Icons.request_quote),
                        label: 'Cotizaciones',
                      ),
                    Seccion.compra => const NavigationDestination(
                        icon: Icon(Icons.chair_outlined),
                        selectedIcon: Icon(Icons.chair),
                        label: 'Mi compra',
                      ),
                  },
              ],
            ),
      ),
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
