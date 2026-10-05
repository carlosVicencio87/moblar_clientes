import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../util/formato.dart';
import 'comunes.dart';

// ---------------------------------------------------------------------------
// Pago de la visita — ESQUELETO DE DEMOSTRACIÓN (decisiones de Carlos,
// 2026-10-02).
//
//   - Monto fijo; solo transferencia o efectivo.
//   - Transferencia: datos para transferir + subir comprobante → en revisión.
//   - Efectivo: el arquitecto escribe SU PIN personal en esta pantalla para
//     confirmar que recibió el dinero.
//
// Todavía no hay nada en el servidor: el resultado vive solo en memoria
// mientras la app está abierta (DemoPagosVisita) para poder mostrar el flujo
// completo a gerencia. Cuando se apruebe, este estado lo dará /inicio.
// ---------------------------------------------------------------------------

/// Resultado de un pago hecho en la demostración.
class ResultadoPagoVisita {
  const ResultadoPagoVisita({
    required this.metodo,
    required this.fecha,
    this.arquitecto,
    this.archivo,
  });

  /// "transferencia" | "efectivo"
  final String metodo;
  final DateTime fecha;

  /// Quién confirmó con su PIN (efectivo).
  final String? arquitecto;

  /// Nombre del comprobante (transferencia).
  final String? archivo;

  bool get esEfectivo => metodo == 'efectivo';
}

/// Estado de la demostración, por id de cita. Solo en memoria.
class DemoPagosVisita {
  DemoPagosVisita._();

  static final resultados = ValueNotifier<Map<String, ResultadoPagoVisita>>(const {});

  static void registrar(String citaId, ResultadoPagoVisita r) {
    resultados.value = {...resultados.value, citaId: r};
  }

  static void reiniciar(String citaId) {
    resultados.value = {...resultados.value}..remove(citaId);
  }
}

/// PIN que la demostración rechaza, para poder enseñar el error.
const pinIncorrectoDemo = '0000';
const largoPin = 4;

// ---------------------------------------------------------------------------
// Tarjeta en el detalle de la cita
// ---------------------------------------------------------------------------

class TarjetaPagoVisita extends StatelessWidget {
  const TarjetaPagoVisita({super.key, required this.cita, required this.pago});

  final Cita cita;
  final PagoVisita pago;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, ResultadoPagoVisita>>(
      valueListenable: DemoPagosVisita.resultados,
      builder: (context, resultados, _) {
        final r = resultados[cita.id];
        final (chip, color, fondo) = r == null
            ? ('Pendiente', const Color(0xFF92400E), MoblarColors.amberSoft)
            : r.esEfectivo
                ? ('Pagada', const Color(0xFF065F46), const Color(0xFFD1FAE5))
                : ('En revisión', const Color(0xFF92400E), MoblarColors.amberSoft);
        return Card(
          key: const Key('tarjetaPagoVisita'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pago.demo) ...[
                  const AvisoDemo(),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: MoblarColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pago de tu visita',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    EstadoChip(texto: chip, color: color, fondo: fondo),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  dinero(pago.monto),
                  key: const Key('montoVisita'),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: MoblarColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                if (r == null) ...[
                  Text(
                    pago.promesaRegistrada
                        ? 'Al agendar te informamos el costo de la visita. Lo pagas el día de tu visita, por transferencia o en efectivo.'
                        : 'Se paga el día de tu visita, por transferencia o en efectivo.',
                    key: const Key('textoPromesaVisita'),
                    style: const TextStyle(color: MoblarColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('pagarVisita'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PagarVisitaPage(cita: cita, pago: pago),
                      ),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pagar mi visita'),
                  ),
                ] else ...[
                  Dato(
                    icono: r.esEfectivo ? Icons.verified_outlined : Icons.receipt_long_outlined,
                    texto: r.esEfectivo
                        ? 'Pagada en efectivo. La recibió ${r.arquitecto ?? 'tu arquitecto'}.'
                        : 'Recibimos tu comprobante. Lo revisamos y te confirmamos.',
                  ),
                  Dato(
                    icono: Icons.event_outlined,
                    texto: '${capitalizar(fechaLarga(r.fecha))}, ${_hora(r.fecha)}',
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Este pago se abonará a tu compra si contratas tu mueble.',
                    style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                  ),
                  if (pago.demo)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('reiniciarDemoVisita'),
                        onPressed: () => DemoPagosVisita.reiniciar(cita.id),
                        child: const Text('Reiniciar demostración'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _hora(DateTime f) {
  final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
  final m = f.minute.toString().padLeft(2, '0');
  return '$h:$m ${f.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// Aviso visible de que nada se guarda todavía.
class AvisoDemo extends StatelessWidget {
  const AvisoDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('avisoDemo'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MoblarColors.amberSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: Color(0xFF92400E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demostración: todavía no se guarda ningún pago.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Elegir método
// ---------------------------------------------------------------------------

class PagarVisitaPage extends StatelessWidget {
  const PagarVisitaPage({super.key, required this.cita, required this.pago});

  final Cita cita;
  final PagoVisita pago;

  Future<void> _abrir(BuildContext context, Widget pagina) async {
    final listo = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => pagina),
    );
    if (listo == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar mi visita')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (pago.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          const Text('Monto de tu visita', style: TextStyle(color: MoblarColors.textMuted)),
          Text(
            dinero(pago.monto),
            style: const TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: MoblarColors.primaryDark,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Cómo quieres pagar?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (pago.aceptaTransferencia)
            _OpcionMetodo(
              clave: const Key('metodoTransferencia'),
              icono: Icons.account_balance_outlined,
              titulo: 'Transferencia',
              texto: 'A la cuenta de tu arquitecto: te damos sus datos y subes tu comprobante.',
              onTap: () => _abrir(
                context,
                TransferenciaVisitaPage(cita: cita, pago: pago, datos: pago.transferencia!),
              ),
            )
          else if (pago.transferenciaAlLlegar)
            // La visita se transfiere a la cuenta propia del arquitecto; sus
            // datos aparecen cuando llega y escanea el QR.
            const _MetodoPendiente(
              clave: Key('metodoTransferenciaAlLlegar'),
              icono: Icons.account_balance_outlined,
              titulo: 'Transferencia',
              texto: 'A la cuenta de tu arquitecto. Sus datos aparecerán aquí cuando llegue y escanee el QR.',
            ),
          if (pago.aceptaEfectivo)
            _OpcionMetodo(
              clave: const Key('metodoEfectivo'),
              icono: Icons.payments_outlined,
              titulo: 'Efectivo',
              texto: 'Se lo entregas a tu arquitecto y él lo confirma con su PIN en tu pantalla.',
              onTap: () => _abrir(context, EfectivoVisitaPage(cita: cita, pago: pago)),
            ),
        ],
      ),
    );
  }
}

/// Forma de pago que todavía no se puede usar (se muestra, sin tocar).
class _MetodoPendiente extends StatelessWidget {
  const _MetodoPendiente({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: clave,
      color: MoblarColors.surfaceSubtle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: MoblarColors.border,
              child: Icon(icono, color: MoblarColors.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MoblarColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(texto, style: const TextStyle(color: MoblarColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.qr_code_2, color: MoblarColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OpcionMetodo extends StatelessWidget {
  const _OpcionMetodo({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: clave,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: MoblarColors.primarySoft,
                child: Icon(icono, color: MoblarColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(texto, style: const TextStyle(color: MoblarColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MoblarColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transferencia
// ---------------------------------------------------------------------------

/// Transferencia de la visita: la pantalla genérica con el registro de la demo.
class TransferenciaVisitaPage extends StatelessWidget {
  const TransferenciaVisitaPage({
    super.key,
    required this.cita,
    required this.pago,
    required this.datos,
  });

  final Cita cita;
  final PagoVisita pago;
  final DatosTransferencia datos;

  @override
  Widget build(BuildContext context) => TransferenciaPagoPage(
        monto: pago.monto,
        datos: datos,
        demo: pago.demo,
        paraQue: 'de tu visita',
        onEnviado: (archivo) => DemoPagosVisita.registrar(
          cita.id,
          ResultadoPagoVisita(metodo: 'transferencia', fecha: DateTime.now(), archivo: archivo),
        ),
      );
}

/// Pantalla de transferencia reutilizable (visita, anticipo): datos para
/// transferir con botón de copiar y subir comprobante. Queda "En revisión".
class TransferenciaPagoPage extends StatefulWidget {
  const TransferenciaPagoPage({
    super.key,
    required this.monto,
    required this.datos,
    required this.demo,
    required this.paraQue,
    required this.onEnviado,
    this.titulo = 'Pagar por transferencia',
  });

  final num monto;
  final DatosTransferencia datos;
  final bool demo;

  /// "de tu visita", "del anticipo de tu mueble": completa la frase del concepto.
  final String paraQue;
  final String titulo;

  /// Recibe el nombre del comprobante elegido.
  final void Function(String? archivo) onEnviado;

  @override
  State<TransferenciaPagoPage> createState() => _TransferenciaPagoPageState();
}

class _TransferenciaPagoPageState extends State<TransferenciaPagoPage> {
  /// En la demo no se abre la galería: se simula el archivo elegido.
  String? _archivo;

  void _elegirComprobante() {
    setState(() => _archivo = 'comprobante_${widget.datos.concepto.toLowerCase()}.jpg');
  }

  void _enviar() {
    widget.onEnviado(_archivo);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comprobante enviado. Lo revisamos y te confirmamos.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          Card(
            key: const Key('datosTransferencia'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '1. Transfiere a esta cuenta',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (d.ejemplo)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Datos de ejemplo: aún no se configura la cuenta real.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _DatoCopiable(etiqueta: 'Monto', valor: dinero(widget.monto), copiar: widget.monto.toStringAsFixed(2)),
                  _DatoCopiable(etiqueta: 'Banco', valor: d.banco),
                  _DatoCopiable(etiqueta: 'Beneficiario', valor: d.beneficiario),
                  _DatoCopiable(
                    clave: const Key('copiarClabe'),
                    etiqueta: 'CLABE',
                    valor: d.clabeLegible,
                    copiar: d.clabe,
                  ),
                  _DatoCopiable(
                    clave: const Key('copiarConcepto'),
                    etiqueta: 'Concepto',
                    valor: d.concepto,
                    destacado: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe el concepto tal cual: así sabemos que el pago es ${widget.paraQue}.',
                    style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '2. Sube tu comprobante',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Una foto o captura de pantalla, o el PDF que te da tu banco.',
                    style: TextStyle(color: MoblarColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_archivo == null)
                    OutlinedButton.icon(
                      key: const Key('elegirComprobante'),
                      onPressed: _elegirComprobante,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Elegir comprobante'),
                    )
                  else
                    Container(
                      key: const Key('comprobanteElegido'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MoblarColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MoblarColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, color: MoblarColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_archivo!, overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _archivo = null),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('enviarComprobante'),
            onPressed: _archivo == null ? null : _enviar,
            child: const Text('Enviar comprobante'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tu pago quedará "En revisión" hasta que nuestro equipo lo confirme.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MoblarColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DatoCopiable extends StatelessWidget {
  const _DatoCopiable({
    this.clave,
    required this.etiqueta,
    required this.valor,
    this.copiar,
    this.destacado = false,
  });

  final Key? clave;
  final String etiqueta;
  final String valor;

  /// Lo que se copia; por omisión, el valor mostrado.
  final String? copiar;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: const TextStyle(fontSize: 12, color: MoblarColors.textMuted)),
                Text(
                  valor,
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
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: copiar ?? valor));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$etiqueta copiado'), duration: const Duration(seconds: 2)),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Efectivo: el arquitecto confirma con su PIN personal
// ---------------------------------------------------------------------------

/// Efectivo de la visita: la pantalla genérica con el registro de la demo.
class EfectivoVisitaPage extends StatelessWidget {
  const EfectivoVisitaPage({super.key, required this.cita, required this.pago});

  final Cita cita;
  final PagoVisita pago;

  @override
  Widget build(BuildContext context) => EfectivoPinPage(
        monto: pago.monto,
        arquitecto: cita.arquitecto,
        demo: pago.demo,
        onConfirmado: () => DemoPagosVisita.registrar(
          cita.id,
          ResultadoPagoVisita(metodo: 'efectivo', fecha: DateTime.now(), arquitecto: cita.arquitecto),
        ),
      );
}

/// Pantalla de efectivo reutilizable (visita, anticipo): el cliente entrega el
/// dinero y el arquitecto escribe SU PIN personal en esta pantalla.
class EfectivoPinPage extends StatefulWidget {
  const EfectivoPinPage({
    super.key,
    required this.monto,
    required this.arquitecto,
    required this.demo,
    required this.onConfirmado,
    this.titulo = 'Pagar en efectivo',
  });

  final num monto;
  final String? arquitecto;
  final bool demo;
  final String titulo;
  final VoidCallback onConfirmado;

  @override
  State<EfectivoPinPage> createState() => _EfectivoPinPageState();
}

class _EfectivoPinPageState extends State<EfectivoPinPage> {
  /// false: instrucciones para el cliente. true: teclado para el arquitecto.
  bool _turnoArquitecto = false;
  String _pin = '';
  String? _error;

  String get _arquitecto => widget.arquitecto ?? 'tu arquitecto';

  void _tecla(String d) {
    if (_pin.length >= largoPin) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _confirmar() {
    // DEMO: sin servidor. Cualquier PIN de 4 dígitos sirve, salvo 0000 para
    // poder enseñar el error. El real se valida en el ERP contra el PIN del
    // arquitecto asignado a esta cita.
    if (_pin == pinIncorrectoDemo) {
      setState(() {
        _pin = '';
        _error = 'PIN incorrecto. Intenta de nuevo.';
      });
      return;
    }
    widget.onConfirmado();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pago en efectivo confirmado por $_arquitecto.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.demo) ...[
            const AvisoDemo(),
            const SizedBox(height: 16),
          ],
          if (!_turnoArquitecto) ..._instrucciones() else ..._teclado(),
        ],
      ),
    );
  }

  List<Widget> _instrucciones() => [
        Card(
          key: const Key('instruccionesEfectivo'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entrega ${dinero(widget.monto)} a $_arquitecto',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Dato(
                  icono: Icons.looks_one_outlined,
                  texto: 'Entrégale el efectivo a tu arquitecto.',
                ),
                const Dato(
                  icono: Icons.looks_two_outlined,
                  texto: 'Pásale tu teléfono: él escribirá su PIN personal en esta pantalla para confirmar que lo recibió.',
                ),
                const Dato(
                  icono: Icons.looks_3_outlined,
                  texto: 'Listo: el pago queda registrado a tu nombre, con fecha y hora.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('turnoArquitecto'),
          onPressed: () => setState(() => _turnoArquitecto = true),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Ya entregué el efectivo'),
        ),
      ];

  List<Widget> _teclado() => [
        Text(
          'Para $_arquitecto',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: MoblarColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          'Confirma que recibiste ${dinero(widget.monto)} en efectivo',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Escribe tu PIN personal',
          textAlign: TextAlign.center,
          style: TextStyle(color: MoblarColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Row(
          key: const Key('puntosPin'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < largoPin; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? MoblarColors.primaryDark : Colors.transparent,
                  border: Border.all(color: MoblarColors.primaryDark, width: 2),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 28,
          child: Center(
            child: _error == null
                ? null
                : Text(
                    _error!,
                    key: const Key('errorPin'),
                    style: const TextStyle(color: MoblarColors.danger, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                for (final fila in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(children: [for (final d in fila) _Tecla(texto: d, onTap: () => _tecla(d))]),
                Row(
                  children: [
                    _Tecla(
                      clave: const Key('pinBorrar'),
                      icono: Icons.backspace_outlined,
                      onTap: _borrar,
                    ),
                    _Tecla(texto: '0', onTap: () => _tecla('0')),
                    _Tecla(
                      clave: const Key('pinConfirmar'),
                      icono: Icons.check,
                      resaltada: true,
                      onTap: _pin.length == largoPin ? _confirmar : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _turnoArquitecto = false;
            _pin = '';
            _error = null;
          }),
          child: const Text('Regresar'),
        ),
      ];
}

class _Tecla extends StatelessWidget {
  const _Tecla({this.clave, this.texto, this.icono, this.resaltada = false, required this.onTap});

  final Key? clave;
  final String? texto;
  final IconData? icono;
  final bool resaltada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activa = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: resaltada
              ? (activa ? MoblarColors.primary : MoblarColors.primaryTint)
              : MoblarColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: clave ?? (texto == null ? null : Key('pin-$texto')),
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              child: Center(
                child: texto != null
                    ? Text(
                        texto!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: MoblarColors.textPrimary,
                        ),
                      )
                    : Icon(icono, color: resaltada ? Colors.white : MoblarColors.primaryDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
