import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/api_client.dart';
import '../state/app_scope.dart';
import '../theme.dart';
import '../util/formato.dart';
import 'widgets/comunes.dart';

/// Ingreso con el código que la operadora de contact center le entregó al
/// cliente al agendar su cita (formato XXXX-XXXX).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _codigo = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codigo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_enviando || !codigoCompleto(_codigo.text)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await AppScope.read(context).entrar(normalizarCodigo(_codigo.text));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aviso = AppScope.of(context).aviso;
    final mensaje = _error ?? aviso;
    final listo = codigoCompleto(_codigo.text);

    return Scaffold(
      backgroundColor: MoblarColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/brand/logo-moblar.png', height: 72),
                  const SizedBox(height: 32),
                  const Text(
                    'Sigue tu mueble',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: MoblarColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escribe el código que te dimos al agendar tu cita.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MoblarColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('campoCodigo'),
                    controller: _codigo,
                    enabled: !_enviando,
                    autocorrect: false,
                    enableSuggestions: false,
                    // visiblePassword: teclado alfanumérico sin autocompletar.
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _entrar(),
                    inputFormatters: [CodigoInputFormatter()],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'XXXX-XXXX',
                      hintStyle: TextStyle(color: MoblarColors.textMuted, letterSpacing: 4),
                    ),
                  ),
                  if (mensaje != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('mensajeLogin'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _error != null ? const Color(0xFFFEE2E2) : MoblarColors.amberSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mensaje,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _error != null ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('botonEntrar'),
                    onPressed: listo && !_enviando ? _entrar : null,
                    child: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => abrirEnlace(
                      context,
                      enlaceWhatsApp(
                        '52${AppConfig.telefonoAtencion}',
                        mensaje: '[ACCESO] Hola, necesito mi código para la app de Moblar.',
                      ),
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('¿No tienes tu código? Escríbenos'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mayúsculas, solo caracteres del alfabeto del código y guion automático
/// después del cuarto ("k7qm4x" → "K7QM-4X"). Acepta pegar "k7qm 4xrt".
class CodigoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final limpio = normalizarCodigo(newValue.text)
        .split('')
        .where(alfabetoCodigo.contains)
        .join();
    final texto = formatearCodigo(limpio);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
