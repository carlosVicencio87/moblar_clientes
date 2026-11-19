import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api_client.dart';
import 'data/session_store.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';
import 'util/soporte.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // "Ver como cliente" desde el ERP (2026-11-17): el pase viene en el
  // fragmento, vive solo en memoria y no toca nada guardado en el navegador.
  final tokenSoporte = kIsWeb ? tokenSoporteDe(Uri.base) : null;
  final state = tokenSoporte != null
      ? AppState(api: ClienteApi(), store: MemorySessionStore()..token = tokenSoporte, soporte: true)
      : AppState(
          api: ClienteApi(),
          store: SecureSessionStore(),
          pagos: SecurePagoPendienteStore(),
          demo: SecureDemoStore(),
          avisos: SecureAvisosStore(),
        );
  state.arrancar();
  runApp(MoblarClientesApp(state: state));
  if (tokenSoporte != null) {
    // Quitar el pase de la barra de direcciones (y del historial).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemNavigator.routeInformationUpdated(uri: Uri(path: '/'), replace: true);
    });
  }
}

class MoblarClientesApp extends StatefulWidget {
  const MoblarClientesApp({super.key, required this.state});

  final AppState state;

  @override
  State<MoblarClientesApp> createState() => _MoblarClientesAppState();
}

class _MoblarClientesAppState extends State<MoblarClientesApp> {
  final _navegador = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_alCambiarSesion);
  }

  @override
  void dispose() {
    widget.state.removeListener(_alCambiarSesion);
    super.dispose();
  }

  /// Si la sesión termina (401, código revocado) con un detalle abierto
  /// encima, se cierra todo para que el ingreso quede a la vista.
  void _alCambiarSesion() {
    if (widget.state.estado == EstadoApp.sinSesion) {
      _navegador.currentState?.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        navigatorKey: _navegador,
        title: 'Tu visita',
        debugShowCheckedModeBanner: false,
        theme: moblarTheme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Raiz(),
        builder: widget.state.soporte ? (context, child) => FranjaSoporte(child: child!) : null,
      ),
    );
  }
}

/// Decide qué pantalla ve el cliente según haya o no sesión.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final estado = AppScope.of(context).estado;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (estado) {
        EstadoApp.arrancando => const _Arranque(key: ValueKey('arranque')),
        EstadoApp.sinSesion => const LoginPage(key: ValueKey('login')),
        EstadoApp.conSesion => const HomeShell(key: ValueKey('home')),
      },
    );
  }
}

class _Arranque extends StatelessWidget {
  const _Arranque({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoblarColors.surface,
      body: const Center(
        child: Icon(Icons.event_available_outlined, size: 72, color: MoblarColors.primary),
      ),
    );
  }
}

/// Franja fija arriba en modo soporte: quien la ve sabe que es solo lectura.
class FranjaSoporte extends StatelessWidget {
  const FranjaSoporte({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF7A4A00),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      textoFranjaSoporte,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
      ],
    );
  }
}
