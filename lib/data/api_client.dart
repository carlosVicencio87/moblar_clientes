import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

/// Errores que la interfaz sabe explicar al cliente.
sealed class ApiException implements Exception {
  const ApiException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// 401 en /sesion: código inexistente o revocado (el servidor no distingue).
class CodigoInvalido extends ApiException {
  const CodigoInvalido(super.mensaje);
}

/// 429: demasiados intentos desde esta red.
class DemasiadosIntentos extends ApiException {
  const DemasiadosIntentos(super.mensaje);
}

/// 401 en cualquier otra ruta: el pase venció o la operadora lo revocó.
class SesionTerminada extends ApiException {
  /// También llega aquí cuando el mismo código se usó para entrar en otro
  /// dispositivo: solo una sesión activa por cliente (2026-09-29).
  const SesionTerminada()
      : super('Tu sesión se cerró: tu código se usó en otro dispositivo o fue '
            'actualizado. Vuelve a entrar con tu código.');
}

class SinConexion extends ApiException {
  const SinConexion()
      : super('No hay conexión. Revisa tu internet e intenta de nuevo.');
}

/// 422 al abonar con tarjeta: el monto no cumple la regla (mínimo, saldo...).
class AbonoInvalido extends ApiException {
  const AbonoInvalido(super.mensaje);
}

class ErrorServidor extends ApiException {
  const ErrorServidor([super.mensaje = 'No pudimos cargar tu información. Intenta de nuevo.']);
}

class Sesion {
  const Sesion({required this.token, required this.nombre});
  final String token;
  final String? nombre;
}

/// Cliente de /api/cliente/* del ERP. Único lugar de la app que habla HTTP.
class ClienteApi {
  ClienteApi({http.Client? client, String? base, String? bypass})
      : _http = client ?? http.Client(),
        _base = (base ?? AppConfig.apiBase).replaceAll(RegExp(r'/+$'), ''),
        _bypass = bypass ?? AppConfig.vercelBypass;

  final http.Client _http;
  final String _base;
  final String _bypass;

  static const _timeout = Duration(seconds: 20);

  /// Ruta de un archivo público del ERP ("/tonos/oporto-mini.webp") → URL
  /// completa. Las URL que ya traen esquema se dejan igual.
  String recurso(String ruta) {
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) return ruta;
    return '$_base${ruta.startsWith('/') ? '' : '/'}$ruta';
  }

  Map<String, String> _headers({String? token, bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (_bypass.isNotEmpty) 'x-vercel-protection-bypass': _bypass,
      };

  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_timeout);
    } on TimeoutException {
      throw const SinConexion();
    } on http.ClientException {
      // Sin dart:io a propósito (la app también compila para web): en
      // celular, package:http envuelve el SocketException en un
      // ClientException, así que este catch cubre la falta de red en ambos.
      throw const SinConexion();
    }
  }

  Map<String, dynamic> _cuerpo(http.Response r) {
    try {
      final v = jsonDecode(utf8.decode(r.bodyBytes));
      return v is Map<String, dynamic> ? v : const {};
    } on FormatException {
      return const {};
    }
  }

  String? _errorDe(Map<String, dynamic> cuerpo) =>
      cuerpo['error'] is String ? cuerpo['error'] as String : null;

  /// POST /api/cliente/sesion
  Future<Sesion> entrar(String codigo) async {
    final r = await _enviar(() => _http.post(
          Uri.parse('$_base/api/cliente/sesion'),
          headers: _headers(json: true),
          body: jsonEncode({'codigo': codigo}),
        ));
    final cuerpo = _cuerpo(r);
    switch (r.statusCode) {
      case 200:
        final token = cuerpo['token'];
        if (token is! String || token.isEmpty) throw const ErrorServidor();
        final cliente = cuerpo['cliente'];
        return Sesion(
          token: token,
          nombre: cliente is Map && cliente['nombre'] is String ? cliente['nombre'] as String : null,
        );
      case 401:
        throw CodigoInvalido(_errorDe(cuerpo) ??
            'El código no es correcto. Revísalo o pide uno nuevo a atención a clientes.');
      case 429:
        throw DemasiadosIntentos(_errorDe(cuerpo) ??
            'Demasiados intentos. Espera unos minutos e intenta de nuevo.');
      default:
        throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    }
  }

  /// GET /api/cliente/inicio
  Future<Inicio> inicio(String token) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/inicio'),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    if (r.statusCode != 200) throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    return Inicio.fromJson(cuerpo);
  }

  /// GET /api/cliente/cotizaciones/:id/pdf → URL firmada (vence en minutos:
  /// se pide justo antes de abrirla, nunca se guarda).
  /// GET /api/cliente/pagos/:id/comprobante
  Future<Comprobante> comprobantePago(String token, String pagoId) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/pagos/$pagoId/comprobante'),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 404) {
      throw const ErrorServidor('Este pago no tiene comprobante disponible.');
    }
    final url = cuerpo['url'];
    if (r.statusCode != 200 || url is! String) {
      throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    }
    return Comprobante(url: Uri.parse(url), esPdf: cuerpo['tipo'] == 'pdf');
  }

  /// GET /api/cliente/proyectos/:id/detalle
  Future<DetalleProyecto> detalleProyecto(String token, String proyectoId) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/proyectos/$proyectoId/detalle'),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 404) {
      throw const ErrorServidor('No encontramos el detalle de este mueble.');
    }
    if (r.statusCode != 200) {
      throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    }
    return DetalleProyecto.fromJson(cuerpo);
  }

  /// GET /api/cliente/citas/:id/llegada — se consulta seguido mientras el
  /// arquitecto va en camino; nunca se guarda.
  Future<LlegadaCita> llegada(String token, String citaId) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/citas/$citaId/llegada'),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    // 404: servidor sin la ruta todavía o cita ajena → simplemente no se muestra nada.
    if (r.statusCode == 404) return const LlegadaCita(estado: 'no_aplica', texto: '');
    if (r.statusCode != 200) {
      throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    }
    return LlegadaCita.fromJson(cuerpo);
  }

  Future<Uri> urlPdf(String token, String cotizacionId) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/cotizaciones/$cotizacionId/pdf'),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 404) {
      throw const ErrorServidor('Esta cotización todavía no tiene documento disponible.');
    }
    final url = cuerpo['url'];
    if (r.statusCode != 200 || url is! String) {
      throw ErrorServidor(_errorDe(cuerpo) ?? const ErrorServidor().mensaje);
    }
    return Uri.parse(url);
  }

  /// POST /api/cliente/proyectos/:id/pago-tarjeta — con [cotizar] solo el
  /// desglose; sin él, el servidor genera el link de Clip.
  Future<Map<String, dynamic>> _pagoTarjeta(
    String token,
    String compraId, {
    num? monto,
    required bool liquidar,
    required bool cotizar,
  }) async {
    final r = await _enviar(() => _http.post(
          Uri.parse('$_base/api/cliente/proyectos/$compraId/pago-tarjeta'),
          headers: _headers(token: token, json: true),
          body: jsonEncode({
            'monto': ?monto,
            'liquidar': liquidar,
            'cotizar': cotizar,
          }),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    final cuerpo = _cuerpo(r);
    if (r.statusCode == 422) throw AbonoInvalido(_errorDe(cuerpo) ?? 'Revisa el monto.');
    if (r.statusCode == 404) {
      throw ErrorServidor(_errorDe(cuerpo) ?? 'El pago con tarjeta no está disponible para esta compra.');
    }
    if (r.statusCode != 200) {
      throw ErrorServidor(_errorDe(cuerpo) ?? 'No pudimos generar tu pago. Intenta de nuevo.');
    }
    return cuerpo;
  }

  Future<CotizacionAbono> cotizarAbono(String token, String compraId, {num? monto, bool liquidar = false}) async =>
      CotizacionAbono.fromJson(
        await _pagoTarjeta(token, compraId, monto: monto, liquidar: liquidar, cotizar: true),
      );

  Future<LinkPagoTarjeta> crearPagoTarjeta(String token, String compraId, {num? monto, bool liquidar = false}) async {
    final l = LinkPagoTarjeta.fromJson(
      await _pagoTarjeta(token, compraId, monto: monto, liquidar: liquidar, cotizar: false),
    );
    if (l.id.isEmpty || !l.url.startsWith('https://') || l.ticket.isEmpty) {
      throw const ErrorServidor('No pudimos generar tu pago. Intenta de nuevo.');
    }
    return l;
  }

  /// GET /api/cliente/pagos-tarjeta/:id?t= — 404 (link ajeno o función
  /// apagada) se trata como "desconocido".
  Future<EstadoPagoTarjeta> estadoPagoTarjeta(String token, String id, String ticket) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('$_base/api/cliente/pagos-tarjeta/$id').replace(queryParameters: {'t': ticket}),
          headers: _headers(token: token),
        ));
    if (r.statusCode == 401) throw const SesionTerminada();
    if (r.statusCode == 404) return const EstadoPagoTarjeta(estado: 'desconocido');
    final cuerpo = _cuerpo(r);
    if (r.statusCode != 200) {
      throw ErrorServidor(_errorDe(cuerpo) ?? 'No pudimos revisar tu pago. Intenta de nuevo.');
    }
    return EstadoPagoTarjeta.fromJson(cuerpo);
  }
}
