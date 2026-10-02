import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';

/// Contacto con atención a clientes desde CADA sección (decisión 2026-09-29:
/// se quitó la pestaña "Atención"). El mensaje de WhatsApp empieza con una
/// etiqueta entre corchetes —`[CITA …]`, `[COTIZACIÓN …]`, `[PROYECTO …]`—
/// para que contact center sepa de qué se trata y lo clasifique.

/// Etiquetas: siempre al inicio del mensaje, en mayúsculas.
abstract final class MotivoContacto {
  static const cita = 'CITA';
  static const citas = 'CITAS';
  static const cotizacion = 'COTIZACIÓN';
  static const cotizaciones = 'COTIZACIONES';
  static const proyecto = 'PROYECTO';
  static const compras = 'COMPRAS';
  static const nuevaCita = 'NUEVA CITA';
  static const pagos = 'PAGOS';
}

/// `[ETIQUETA referencia] Hola, soy Nombre. texto`
String mensajeContacto({
  required String etiqueta,
  String? referencia,
  String? nombre,
  required String texto,
}) {
  final ref = (referencia ?? '').trim();
  final quien = (nombre ?? '').trim();
  final cabecera = ref.isEmpty ? '[$etiqueta]' : '[$etiqueta $ref]';
  final saludo = quien.isEmpty ? 'Hola.' : 'Hola, soy $quien.';
  return '$cabecera $saludo $texto';
}

String mensajeCita(Cita cita, String? nombre) {
  final fecha = parseFecha(cita.fecha);
  final hora = horaLegible(cita.horario);
  final cuando = [if (fecha != null) fechaLarga(fecha), if (hora.isNotEmpty) hora].join(' a las ');
  return mensajeContacto(
    etiqueta: MotivoContacto.cita,
    referencia: fecha == null ? null : fechaCorta(fecha),
    nombre: nombre,
    texto: cuando.isEmpty
        ? 'Tengo una duda sobre mi cita.'
        : 'Tengo una duda sobre mi cita del $cuando.',
  );
}

String mensajeCotizacion(Cotizacion c, String? nombre) => mensajeContacto(
      etiqueta: MotivoContacto.cotizacion,
      referencia: c.codigo,
      nombre: nombre,
      texto: 'Tengo una duda sobre mi cotización'
          '${c.mueble == null ? '' : ' de ${c.mueble}'}'
          '${c.codigo == null ? '' : ' (${c.codigo})'}.',
    );

String mensajeProyecto(Compra c, String? nombre) => mensajeContacto(
      etiqueta: MotivoContacto.proyecto,
      referencia: c.codigo,
      nombre: nombre,
      texto: 'Quiero saber sobre mi ${c.mueble ?? 'mueble'}'
          '${c.codigo == null ? '' : ' (pedido ${c.codigo})'}.',
    );

/// Duda sobre la oferta que dejó el arquitecto al terminar la visita. Aún no
/// hay código de cotización: la referencia es la fecha de la visita.
String mensajeOfertaVisita(OfertaVisita oferta, String? nombre) {
  final fecha = parseFecha(oferta.fechaVisita);
  return mensajeContacto(
    etiqueta: MotivoContacto.cotizacion,
    referencia: fecha == null ? null : fechaCorta(fecha),
    nombre: nombre,
    texto: fecha == null
        ? 'Tengo una duda sobre la cotización que me dejó mi arquitecto en la visita.'
        : 'Tengo una duda sobre la cotización que me dejó mi arquitecto en la visita del ${fechaLarga(fecha)}.',
  );
}

/// Pedir otra visita: contact center agenda por WhatsApp.
String mensajeNuevaCita(String? nombre) => mensajeContacto(
      etiqueta: MotivoContacto.nuevaCita,
      nombre: nombre,
      texto: 'Quiero agendar una nueva cita.',
    );

/// Mensaje directo al arquitecto: sin etiqueta, porque no pasa por
/// contact center.
String mensajeArquitecto(Cita cita, String? nombre) {
  final fecha = parseFecha(cita.fecha);
  final quien = (nombre ?? '').trim();
  final saludo = quien.isEmpty ? 'Hola.' : 'Hola, soy $quien.';
  return fecha == null
      ? '$saludo Te escribo por mi cita con MOBLAR.'
      : '$saludo Te escribo por mi cita del ${fechaLarga(fecha)}.';
}

/// Teléfono y WhatsApp a usar: lo que mande el servidor o, si falta, el de
/// respaldo de la app. Moblar atiende a todas las marcas por ahora.
class ContactoResuelto {
  ContactoResuelto(Contacto c)
      : telefono = c.telefono.isNotEmpty ? c.telefono : AppConfig.telefonoAtencion,
        whatsapp = c.whatsapp.isNotEmpty
            ? c.whatsapp
            : '52${c.telefono.isNotEmpty ? c.telefono : AppConfig.telefonoAtencion}';

  final String telefono;
  final String whatsapp;

  /// "5530768296" → "55 3076 8296"
  String get telefonoLegible {
    final d = telefono.replaceAll(RegExp(r'\D'), '');
    return d.length == 10 ? '${d.substring(0, 2)} ${d.substring(2, 6)} ${d.substring(6)}' : telefono;
  }
}

/// Dos botones, WhatsApp (con el mensaje ya escrito) y llamar.
class BotonesContacto extends StatelessWidget {
  const BotonesContacto({
    super.key,
    required this.contacto,
    required this.mensaje,
    this.compactos = false,
  });

  final Contacto contacto;
  final String mensaje;

  /// Compactos: para ir dentro de una tarjeta de la lista.
  final bool compactos;

  @override
  Widget build(BuildContext context) {
    final c = ContactoResuelto(contacto);
    final alto = compactos ? 40.0 : 48.0;
    final estilo = OutlinedButton.styleFrom(
      minimumSize: Size.fromHeight(alto),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('contactoWhatsApp'),
            style: estilo,
            onPressed: () => abrirEnlace(context, enlaceWhatsApp(c.whatsapp, mensaje: mensaje)),
            icon: const Icon(Icons.chat_outlined, size: 20),
            label: const Text('WhatsApp'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('contactoLlamar'),
            style: estilo,
            onPressed: () => abrirEnlace(context, Uri(scheme: 'tel', path: c.telefono)),
            icon: const Icon(Icons.call_outlined, size: 20),
            label: const Text('Llamar'),
          ),
        ),
      ],
    );
  }
}

/// Enlace discreto "Preguntar por esta …" dentro de una tarjeta: abre
/// WhatsApp con el motivo ya escrito. Es el contacto de cada tarjeta de las
/// listas (decisión 2026-09-30: sin tarjeta de ayuda repetida al final).
class BotonPreguntar extends StatelessWidget {
  const BotonPreguntar({
    super.key,
    required this.texto,
    required this.contacto,
    required this.mensaje,
    this.color,
  });

  final String texto;
  final Contacto contacto;
  final String mensaje;

  /// Para tarjetas de fondo oscuro (la cita destacada).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: color == null ? null : TextButton.styleFrom(foregroundColor: color),
        onPressed: () => abrirEnlace(
          context,
          enlaceWhatsApp(ContactoResuelto(contacto).whatsapp, mensaje: mensaje),
        ),
        icon: const Icon(Icons.chat_outlined, size: 18),
        label: Text(texto),
      ),
    );
  }
}

/// Tarjeta "¿Necesitas ayuda?". Solo cuando la sección está vacía: si hay
/// tarjetas, cada una trae su propio contacto.
class TarjetaAyuda extends StatelessWidget {
  const TarjetaAyuda({
    super.key,
    required this.titulo,
    required this.contacto,
    required this.mensaje,
  });

  final String titulo;
  final Contacto contacto;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Card(
        key: const Key('tarjetaAyuda'),
        color: MoblarColors.primarySoft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.support_agent, color: MoblarColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Una persona de nuestro equipo te atiende.',
                style: TextStyle(color: MoblarColors.textSecondary),
              ),
              const SizedBox(height: 12),
              BotonesContacto(contacto: contacto, mensaje: mensaje),
            ],
          ),
        ),
      ),
    );
  }
}
