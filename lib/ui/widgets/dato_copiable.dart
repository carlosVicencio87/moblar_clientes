import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';

/// Un dato de la transferencia (beneficiario, CLABE, concepto…) que se copia
/// con un toque: en todo el renglón o en el ícono. 2026-11-20: antes solo
/// estaba en el pago de la visita y los abonos; ahora también al comprar.
class DatoCopiable extends StatelessWidget {
  const DatoCopiable({
    super.key,
    this.clave,
    required this.etiqueta,
    required this.valor,
    this.copiar,
    this.destacado = false,
  });

  /// Key del botón de copiar (para las pruebas).
  final Key? clave;
  final String etiqueta;
  final String valor;

  /// Lo que se copia; por omisión, el valor mostrado (la CLABE se copia sin
  /// espacios aunque se muestre en grupos).
  final String? copiar;
  final bool destacado;

  Future<void> _copiar(BuildContext context) async {
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      await Clipboard.setData(ClipboardData(text: copiar ?? valor));
    } catch (_) {
      m
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo copiar $etiqueta. Mantén presionado el dato para copiarlo.')),
        );
      return;
    }
    // Uno tras otro (beneficiario, CLABE, concepto) sin hacer fila de avisos.
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Copiado: $etiqueta'), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _copiar(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
                  SelectableText(
                    valor,
                    onTap: () => _copiar(context),
                    style: TextStyle(
                      fontSize: destacado ? 18 : 15,
                      fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
                      color: destacado ? MoblarColors.primaryDark : MoblarColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: clave,
              tooltip: 'Copiar $etiqueta',
              icon: const Icon(Icons.copy_outlined, size: 20),
              color: MoblarColors.primary,
              onPressed: () => _copiar(context),
            ),
          ],
        ),
      ),
    );
  }
}
