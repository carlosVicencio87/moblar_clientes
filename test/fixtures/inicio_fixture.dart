/// Respuesta de GET /api/cliente/inicio con la MISMA forma que se verificó en
/// vivo el 2026-09-27 (cuenta de prueba), con datos inventados.
library;

const inicioJson = r'''
{
  "cliente": {"nombre": "Carlos Prueba"},
  "contacto": {"empresa": "MOBLAR", "telefono": "5530768296", "whatsapp": "https://wa.me/525530768296"},
  "citas": [
    {
      "id": "c-futura",
      "fecha": "2030-03-10T16:00:00+00:00",
      "horario": "10:00",
      "estado": {"clave": "confirmada", "titulo": "Confirmada"},
      "arquitecto": "Ana López",
      "arquitectoFoto": null,
      "arquitectoHabilidades": [
        {"clave": "creatividad", "titulo": "Creatividad en diseños", "estrellas": 4.5, "detalle": ""},
        {"clave": "puntualidad", "titulo": "Puntualidad", "estrellas": null, "detalle": "Muy pronto: se medirá con el registro de llegada a tus citas."},
        {"clave": "atencion", "titulo": "Atención y asesoría", "estrellas": null, "detalle": "Muy pronto: con la opinión de clientes después de su visita."}
      ],
      "arquitectoTelefono": "5512345678",
      "agendoPor": "Estela Ramírez",
      "direccion": "Av. Siempre Viva 742, CDMX",
      "mapsUrl": "https://maps.app.goo.gl/ejemplo",
      "muebles": ["Cocina", "Closet"],
      "costoVisita": null,
      "marca": {"clave": "moblar", "nombre": "MOBLAR", "logo": "logo-moblar.png"}
    },
    {
      "id": "c-pasada",
      "fecha": "2026-08-24T15:00:00+00:00",
      "horario": "09:00",
      "estado": {"clave": "realizada", "titulo": "Visita realizada"},
      "arquitecto": null,
      "muebles": [],
      "costoVisita": null,
      "marca": {"clave": "voreal", "nombre": "VOREAL", "logo": "logo-voreal.jpeg"}
    }
  ],
  "cotizaciones": [
    {"id": "q1", "codigo": "000135", "mueble": "Cocina", "citaId": "c-pasada", "tienePdf": true, "precio": 250000, "comprado": true,
     "comercial": {"imagenDiseno": null, "precio": 250000, "conIva": false, "arquitecto": "Ana López",
       "emitida": "2026-09-28T15:00:00.000Z", "vigenteHasta": "2026-10-13T15:00:00.000Z", "vigente": true,
       "incluye": ["Proceso de fabricación", "Materiales", "Transporte", "Instalación"]},
     "marca": {"clave": "voreal", "nombre": "VOREAL", "logo": "logo-voreal.jpeg"}},
    {"id": "q2", "codigo": null, "mueble": null, "citaId": null, "tienePdf": false, "precio": null, "comprado": false,
     "comercial": {"imagenDiseno": null, "precio": null, "conIva": false, "arquitecto": null,
       "emitida": "2026-08-01T15:00:00.000Z", "vigenteHasta": "2026-08-16T15:00:00.000Z", "vigente": false,
       "incluye": ["Proceso de fabricación", "Materiales", "Transporte", "Instalación"]},
     "marca": {"clave": "desconocida", "nombre": "", "logo": "logo-nueva.png"}}
  ],
  "compras": [
    {
      "id": "p-entregado",
      "codigo": "P-0001",
      "mueble": "Closet",
      "lineaTiempo": {
        "etapaActual": 5,
        "porcentaje": 100,
        "mensaje": "¡Tu mueble está instalado! Gracias por tu confianza.",
        "etapas": [
          {"clave": "pedido", "titulo": "Pedido confirmado", "descripcion": "Recibimos tu pedido.", "situacion": "hecha", "desde": "2026-06-01T12:00:00Z"},
          {"clave": "diseno", "titulo": "Diseño técnico", "descripcion": "d", "situacion": "hecha", "desde": null},
          {"clave": "fabricacion", "titulo": "Fabricación", "descripcion": "f", "situacion": "hecha", "desde": null},
          {"clave": "calidad", "titulo": "Control de calidad", "descripcion": "c", "situacion": "hecha", "desde": null},
          {"clave": "instalacion", "titulo": "Instalación", "descripcion": "i", "situacion": "hecha", "desde": "2026-09-04T18:00:00Z"},
          {"clave": "entregado", "titulo": "Entregado", "descripcion": "e", "situacion": "hecha", "desde": "2026-09-04T18:00:00Z"}
        ]
      },
      "instalacion": {"fecha": "2026-09-04", "horario": "11:00"},
      "pagos": {"total": null, "pagado": null, "saldo": null},
      "marca": {"clave": "osmon", "nombre": "OSMON", "logo": "logo-osmon.jpeg"}
    },
    {
      "id": "p-fabricacion",
      "codigo": "P-0002",
      "mueble": "Cocina",
      "lineaTiempo": {
        "etapaActual": 2,
        "porcentaje": 58,
        "mensaje": "Tu mueble se está fabricando en nuestro taller.",
        "etapas": [
          {"clave": "pedido", "titulo": "Pedido confirmado", "descripcion": "Recibimos tu pedido.", "situacion": "hecha", "desde": "2026-09-01T12:00:00Z"},
          {"clave": "diseno", "titulo": "Diseño técnico", "descripcion": "d", "situacion": "hecha", "desde": "2026-09-05T12:00:00Z"},
          {"clave": "fabricacion", "titulo": "Fabricación", "descripcion": "Tu mueble se está fabricando en nuestro taller.", "situacion": "actual", "desde": "2026-09-20T12:00:00Z"},
          {"clave": "calidad", "titulo": "Control de calidad", "descripcion": "c", "situacion": "pendiente", "desde": null},
          {"clave": "instalacion", "titulo": "Instalación", "descripcion": "i", "situacion": "pendiente", "desde": null},
          {"clave": "entregado", "titulo": "Entregado", "descripcion": "e", "situacion": "pendiente", "desde": null}
        ]
      },
      "instalacion": null,
      "pagos": {"total": null, "pagado": null, "saldo": null},
      "cuenta": {
        "subtotal": 250000, "iva": 0, "total": 250000, "pagado": 100000, "enRevision": 20000,
        "saldo": 150000, "conFactura": false, "visitaAbonada": 500,
        "pagos": [
          {"fecha": "2026-09-20", "monto": 20000, "concepto": "Abono", "metodo": "Transferencia", "estado": "en_revision", "visitaIncluida": null},
          {"fecha": "2026-09-01", "monto": 100000, "concepto": "Anticipo", "metodo": "Transferencia", "estado": "validado", "visitaIncluida": 500}
        ]
      },
      "marca": {"clave": "voreal", "nombre": "VOREAL", "logo": "logo-voreal.jpeg"}
    }
  ]
}
''';

/// Respuesta de GET /api/cliente/proyectos/:id/detalle (sin imagen: en las
/// pruebas de widgets no hay red para Image.network).
const detalleJson = r'''
{
  "id": "p-fabricacion",
  "mueble": "Cocina",
  "imagenDiseno": null,
  "medidas": "240 × 180 cm",
  "piezas": [
    {"nombre": "Alacena", "cantidad": 2, "medidas": "60 × 90 cm", "fondo": "35 cm", "tono": "Nogal Terracota"},
    {"nombre": "Isla", "cantidad": 1, "medidas": null, "fondo": null, "tono": null}
  ],
  "tonos": [
    {"nombre": "Nogal Terracota", "hex": "#8B5A2B"},
    {"nombre": "Blanco Brillante", "hex": null}
  ],
  "incluye": ["Mueble a piso", "Cajones", "Correderas (4)"],
  "porTuCuenta": ["Chimenea"]
}
''';
