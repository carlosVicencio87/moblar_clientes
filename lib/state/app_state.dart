import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/session_store.dart';

enum EstadoApp { arrancando, sinSesion, conSesion }

/// Estado único de la app: sesión + datos de /inicio.
///
/// Regla: si el servidor responde 401 en cualquier momento (código revocado o
/// regenerado por la operadora, pase vencido), la sesión se borra y el cliente
/// regresa a la pantalla de ingreso con un aviso.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store});

  final ClienteApi api;
  final SessionStore store;

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

  Future<void> salir() => _cerrar();

  Future<void> _cerrar({String? aviso}) async {
    _token = null;
    datos = null;
    errorCarga = null;
    this.aviso = aviso;
    await store.borrar();
    estado = EstadoApp.sinSesion;
    notifyListeners();
  }
}
