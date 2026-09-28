# moblar_clientes

App de clientes MOBLAR (Flutter, Android/iOS): el cliente entra con el código
que le da contact center al agendar su cita y ve **Citas**, **Cotizaciones**
(PDF), **Mi compra** (línea de tiempo de su mueble) y **Atención**.

La app no trae llaves de Supabase: solo habla con `/api/cliente/*` del ERP
(Osmon-moblar-CAML). Plan y decisiones: `claude/APP_CLIENTES_PLAN.md` del
proyecto.

## Primera vez

```powershell
cd C:\Users\mihaw\moblar\moblar_clientes
flutter create --org com.moblar --project-name moblar_clientes --platforms android,ios .
flutter pub get
flutter analyze
flutter test
```

`flutter create .` solo agrega lo que falta (gradle, iOS, MainActivity); no
toca `lib/`, `test/` ni el `AndroidManifest.xml` que ya viene.

## Correr

Producción (después del PR a master):

```powershell
flutter run
```

Contra el preview de `carlosV_dev_local` (protegido por Vercel):

```powershell
flutter run `
  --dart-define=API_BASE=https://osmon-moblar-caml-git-carlosvdevlocal-moblar.vercel.app `
  --dart-define=VERCEL_BYPASS=<secreto de Protection Bypass for Automation>
```

El secreto del bypass no se sube al repo ni se pega en el chat.

## Estructura

```
lib/
  config.dart              API_BASE / VERCEL_BYPASS (--dart-define)
  theme.dart               paleta de BRAND.md
  data/                    modelos (espejo de clientePortal.ts), cliente HTTP, token seguro
  state/                   AppState (sesión + datos) y AppScope
  ui/                      login, barra inferior y las 4 secciones
  util/formato.dart        fechas, dinero, código (espejo de clienteAcceso.ts)
test/                      modelos, formato, API, estado y widgets
```

## Versión web

La misma app corre en el navegador y se publica **dentro del ERP** en
`https://caml.osmon-moblar.xyz/clientes` (mismo dominio que `/api/cliente`,
sin CORS). En web no hace falta `API_BASE`: la app habla con el dominio que la
sirve, así que el preview de Vercel prueba contra su preview.

Primera vez en un equipo (genera lo que falte de `web/`, respeta lo que ya existe):

```powershell
flutter create --platforms web .
```

Publicar una versión nueva:

```powershell
.\tool\publicar_web.ps1          # ERP en ..\Osmon-moblar-CAML
# o: .\tool\publicar_web.ps1 -Erp C:\ruta\al\Osmon-moblar-CAML
```

Luego, en el ERP: `git add public/clientes`, commit y push.

Probar en local sin publicar: `flutter run -d chrome --dart-define=API_BASE=https://caml.osmon-moblar.xyz`
no funciona (el navegador bloquea otro dominio): para probar web usa el preview
de Vercel después de publicar.
