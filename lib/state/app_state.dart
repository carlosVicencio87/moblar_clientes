import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../util/formato.dart';

enum EstadoApp { arrancando, sinSesion, conSesion }

/// Estado único de la app: sesión + datos de /inicio.
///
/// Regla: si el servidor responde 401 en cualquier momento (código revocado o
/// regenerado por la operadora, pase vencido), la sesión se borra y el cliente
/// regresa a la pantalla de ingreso con un aviso.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store, PagoPendienteStore? pagos})
      : pagos = pagos ?? MemoryPagoPendienteStore();

  final ClienteApi api;
  final SessionStore store;

  /// Pago con tarjeta en curso (sobrevive a recargar la página en web).
  final PagoPendienteStore pagos;

  /// Resultado de un pago con tarjeta para mostrar arriba (lo cierra el cliente).
  String? avisoPago;

  EstadoApp estado = EstadoApp.arrancando;
  Inicio? datos;
  String? aviso; // mensaje para la pantalla de ingreso
  String? errorCarga; // error al refrescar con sesión válida
  bool cargando = false;
  String? _token;

  Future<void> arrancar() async {
    _token = await store.leer();
    if (_token == null) {
      estado = EstadoApp.sinSesion;
      notifyListeners();
      return;
    }
    estado = EstadoApp.conSesion;
    notifyListeners();
    await refrescar();
    await revisarPagoPendiente();
  }

  /// Lanza [ApiException] para que la pantalla de ingreso muestre el motivo.
  Future<void> entrar(String codigo) async {
    final sesion = await api.entrar(codigo);
    _token = sesion.token;
    await store.guardar(sesion.token);
    aviso = null;
    estado = EstadoApp.conSesion;
    notifyListeners();
    await refrescar();
  }

  Future<void> refrescar() async {
    final token = _token;
    if (token == null) return;
    cargando = true;
    errorCarga = null;
    notifyListeners();
    try {
      datos = await api.inicio(token);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      return;
    } on ApiException catch (e) {
      errorCarga = e.mensaje;
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  /// Detalle del mueble (imagen, tonos, lo que incluye). No se guarda en el
  /// estado: la imagen es una URL firmada que vence, se pide al abrir.
  Future<DetalleProyecto> detalleProyecto(String proyectoId) async {
    final token = _token;
    if (token == null) throw const SesionTerminada();
    try {
      return await api.detalleProyecto(token, proyectoId);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      rethrow;
    }
  }

  /// Comprobante de un pago: se pide al abrir el detalle, no se guarda.
  Future<Comprobante> comprobantePago(String pagoId) async {
    final token = _token;
    if (token == null) throw const SesionTerminada();
    try {
      return await api.comprobantePago(token, pagoId);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      rethrow;
    }
  }

  /// QR de llegada del arquitecto para esta cita (ver [LlegadaCita]).
  Future<LlegadaCita> llegada(String citaId) async {
    final token = _token;
    if (token == null) throw const SesionTerminada();
    try {
      return await api.llegada(token, citaId);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      rethrow;
    }
  }

  Future<Uri> urlPdf(String cotizacionId) async {
    final token = _token;
    if (token == null) throw const SesionTerminada();
    try {
      return await api.urlPdf(token, cotizacionId);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      rethrow;
    }
  }

  // ---- Abonar con tarjeta (link de Clip) ----

  /// Demostración: abonos a cada oferta adquirida (por cita), solo en
  /// memoria, igual que el anticipo de la demo.
  final Map<String, List<AbonoDemo>> abonosDemo = {};

  List<AbonoDemo> abonosDe(String citaId) => List.unmodifiable(abonosDemo[citaId] ?? const []);

  void registrarAbonoDemo(String citaId, AbonoDemo a) {
    abonosDemo[citaId] = [...?abonosDemo[citaId], a];
    notifyListeners();
  }

  /// Links ya cerrados en esta sesión (el aviso y el abono se cuentan una vez).
  final Set<String> _linksCerrados = {};

  Future<CotizacionAbono> cotizarAbono(DestinoAbono d, {num? monto, bool liquidar = false}) =>
      _conToken((t) => d.oferta
          ? api.cotizarAbonoOferta(t, d.id, saldo: d.saldo, factura: d.factura, monto: monto, liquidar: liquidar)
          : api.cotizarAbono(t, d.id, monto: monto, liquidar: liquidar));

  /// Genera el link y lo guarda como pendiente ANTES de abrir Clip.
  Future<LinkPagoTarjeta> crearPagoTarjeta(DestinoAbono d, {num? monto, bool liquidar = false}) async {
    final l = await _conToken((t) => d.oferta
        ? api.crearPagoTarjetaOferta(t, d.id, saldo: d.saldo, factura: d.factura, monto: monto, liquidar: liquidar)
        : api.crearPagoTarjeta(t, d.id, monto: monto, liquidar: liquidar));
    await pagos.guardar(PagoPendiente(
      id: l.id,
      ticket: l.ticket,
      compraId: d.id,
      neto: l.cotizacion.neto,
      cobro: l.cotizacion.cobro,
      oferta: d.oferta,
    ));
    return l;
  }

  /// Revisa el pago guardado como pendiente (al arrancar la app).
  Future<EstadoPagoTarjeta?> revisarPagoPendiente() async {
    final p = await pagos.leer();
    if (p == null) return null;
    return revisarPago(p);
  }

  /// Revisa un pago con tarjeta. Si ya terminó (pagado, vencido o cancelado)
  /// deja el aviso, lo olvida y (en la demo) suma el abono; si sigue
  /// pendiente, no cambia nada. Nunca lanza: un fallo de red se reintenta en
  /// la siguiente revisión.
  Future<EstadoPagoTarjeta?> revisarPago(PagoPendiente p) async {
    final token = _token;
    if (token == null) return null;
    final EstadoPagoTarjeta e;
    try {
      e = await api.estadoPagoTarjeta(token, p.id, p.ticket);
    } on SesionTerminada catch (x) {
      await _cerrar(aviso: x.mensaje);
      return null;
    } on ApiException {
      return null;
    }
    if (e.pendiente) return e;
    if ((await pagos.leer())?.id == p.id) await pagos.borrar();
    if (!_linksCerrados.add(p.id)) return e;
    if (e.pagado) {
      if (p.oferta) {
        abonosDemo[p.compraId] = [
          ...?abonosDemo[p.compraId],
          AbonoDemo(fecha: DateTime.now(), monto: p.neto, metodo: 'Tarjeta', validado: true),
        ];
      }
      avisoPago = e.registrado
          ? 'Recibimos tu pago de ${dinero(p.neto)} con tarjeta. Ya está en tu estado de cuenta.'
          : 'Recibimos tu pago con tarjeta: ${dinero(p.neto)} para tu mueble'
              '${e.recibo != null ? ' (recibo ${e.recibo})' : ''}. '
              'Prueba: todavía no se suma solo a tu estado de cuenta.';
      if (e.registrado) await refrescar();
    } else if (e.estado == 'vencido' || e.estado == 'cancelado') {
      avisoPago = 'Tu link de pago con tarjeta venció sin pagarse. Puedes generar otro cuando quieras.';
    }
    notifyListeners();
    return e;
  }

  /// El cliente decidió no pagar el link en curso.
  Future<void> olvidarPagoPendiente() => pagos.borrar();

  void cerrarAvisoPago() {
    avisoPago = null;
    notifyListeners();
  }

  Future<T> _conToken<T>(Future<T> Function(String token) f) async {
    final token = _token;
    if (token == null) throw const SesionTerminada();
    try {
      return await f(token);
    } on SesionTerminada catch (e) {
      await _cerrar(aviso: e.mensaje);
      rethrow;
    }
  }

  Future<void> salir() => _cerrar();

  Future<void> _cerrar({String? aviso}) async {
    _token = null;
    datos = null;
    errorCarga = null;
    avisoPago = null;
    abonosDemo.clear();
    this.aviso = aviso;
    await store.borrar();
    await pagos.borrar();
    estado = EstadoApp.sinSesion;
    notifyListeners();
  }
}
