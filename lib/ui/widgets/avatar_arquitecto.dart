import 'package:flutter/material.dart';

import '../../theme.dart';

/// Foto del arquitecto o, si no hay (o no carga), sus iniciales.
class AvatarArquitecto extends StatelessWidget {
  const AvatarArquitecto({super.key, required this.nombre, this.fotoUrl, this.tamano = 56});

  final String? nombre;
  final String? fotoUrl;
  final double tamano;

  static String iniciales(String? nombre) {
    final partes = (nombre ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    final dos = partes.length > 1 ? partes[0][0] + partes[1][0] : partes[0][0];
    return dos.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final respaldo = Container(
      color: MoblarColors.primaryTint,
      alignment: Alignment.center,
      child: Text(
        iniciales(nombre),
        style: TextStyle(
          fontSize: tamano * 0.36,
          fontWeight: FontWeight.w700,
          color: MoblarColors.primaryDark,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: tamano,
        child: fotoUrl == null
            ? respaldo
            : Image.network(
                fotoUrl!,
                fit: BoxFit.cover,
                semanticLabel: nombre == null ? 'Foto del arquitecto' : 'Foto de $nombre',
                errorBuilder: (_, _, _) => respaldo,
                loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : respaldo,
              ),
      ),
    );
  }
}
