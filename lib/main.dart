import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api_client.dart';
import 'data/session_store.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    api: ClienteApi(),
    store: SecureSessionStore(),
    pagos: SecurePagoPendienteStore(),
    demo: SecureDemoStore(),
  )..arrancar();
  runApp(MoblarClientesApp(state: state));
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
        title: 'Moblar',
        debugShowCheckedModeBanner: false,
        theme: moblarTheme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Raiz(),
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
      body: Center(
        child: Image.asset('assets/brand/logo-moblar.png', width: 160),
      ),
    );
  }
}
