// Saltos entre secciones del inicio desde pantallas internas (feedback de
// arquitectura, 2026-10-14): p. ej. desde el pago de la visita, "Ver mi
// cotización" regresa al inicio y abre Cotizaciones.
import 'package:flutter/foundation.dart';

/// Cada vez que cambia, HomeShell abre la pestaña Cotizaciones.
final irACotizaciones = ValueNotifier<int>(0);
