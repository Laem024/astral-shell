# Tema SDDM Astral

Tema de inicio de sesión para SDDM 0.21 o superior con Qt 6. Usa el sistema de
diseño de Astral (`docs/design-system.md`) en modo oscuro por defecto o claro, con
un cielo animado y una tarjeta de acceso centrada que solo aparece en la pantalla
activa.

La interfaz está en inglés. La configuración vive en `theme.conf`; después de
instalar el tema, edítala con privilegios:

```bash
sudoedit /usr/share/sddm/themes/astral/theme.conf
```

Los cambios se aplican la próxima vez que arranque SDDM. El tema no reinicia el
greeter ni la sesión actual.

## Fondo

`background` acepta:

- Un preset: `aurora`, `nebula`, `dusk` o `void`.
- Una ruta relativa al tema, por ejemplo `assets/backgrounds/mi-fondo.jpg`.
- Una ruta absoluta legible por el usuario `sddm`, por ejemplo
  `/usr/share/backgrounds/mi-fondo.jpg`.

Para copiar una imagen al tema y actualizar `theme.conf` de una vez:

```bash
sudo astral-sddm-background aurora
sudo astral-sddm-background /ruta/a/mi-fondo.jpg
astral-sddm-background --list
```

## Opciones principales

| Clave | Valor por defecto | Efecto |
| --- | --- | --- |
| `mode` | `dark` | `dark` o `light` (cualquier otro valor usa `dark`) |
| `background` | `aurora` | Preset, ruta relativa o absoluta |
| `backgroundMode` | `fill` | `fill`, `fit`, `stretch` o `tile` |
| `backgroundDrift` | `true` | Deriva lenta del fondo |
| `overlay` | `0.5` en oscuro, `0.72` en claro | Tinte del fondo hacia la paleta (0 a 1) |
| `animations` | `true` | Entrada, estrellas, fugaces, parpadeo y sacudida |
| `stars` | `true` | Estrellas titilantes |
| `starDensity` | `1.0` | Densidad de estrellas |
| `shootingStars` | `true` | Estrellas fugaces |
| `meteorCount` | `2` | Fugaces por pantalla |
| `meteorAngle` | `28` | Ángulo diagonal en grados |
| `scale` | `1.0` | Escala general de la interfaz |
| `clockFormat` | `24h` | `24h` o `12h` |
| `activationMode` | `click` | `click` o `primary` |
| `inactiveDim` | `0.45` | Atenuación de pantallas inactivas |
| `showAvatar` | `true` | Foto o iniciales del usuario |
| `showSession` | `true` | Selector de escritorio |
| `showPower` | `true` | Apagar, reiniciar y suspender |
| `showHostname` | `true` | Nombre del equipo |
| `showKeyboard` | `true` | Distribución de teclado activa |
| `avatar` | vacío | Avatar común opcional |

Los colores salen de la paleta del modo elegido. Las claves opcionales
`backgroundColor`, `surfaceColor`, `textColor`, `mutedColor`, `accentColor`,
`lavenderColor`, `goldColor` y `alertColor` solo reemplazan un color si tienen
un valor; déjalas vacías o bórralas para volver a la paleta.

## Modo claro

Pon `mode=light` en `theme.conf` para la paleta clara de Astral. Ambos modos usan
los mismos valores que Quickshell (`config/quickshell/settings.json`).

Las instalaciones previas conservan su `theme.conf` al actualizar. Si tenía
colores fijos antiguos (`accentColor`, `surfaceColor`, etc.) o `glassOpacity`,
bórralos para que se aplique la paleta nueva.

## Confirmaciones

Apagar y reiniciar usan el color de alerta y piden una segunda pulsación en
cuatro segundos. Suspender se ejecuta de inmediato.

## Pantallas

SDDM crea una vista por monitor. En `activationMode=click`, la pantalla con el
foco de teclado muestra el panel; las demás muestran el cielo atenuado y un
aviso clicable. Al cambiar de pantalla se destruye el panel anterior y se
borra la contraseña. En `activationMode=primary` solo la pantalla primaria
permite iniciar sesión.

En X11 el cambio de foco funciona directamente. En el greeter Wayland depende
de que el compositor acepte la activación de la ventana; si no lo hace, usa
`activationMode=primary`.

## Usuarios y avatares

El tema usa `userModel` de SDDM. Los avatares se resuelven en este orden:

1. `~/.face.icon` del usuario.
2. `/usr/share/sddm/faces/<usuario>.face.icon`.
3. La foto de AccountsService.
4. `faces/.face.icon` del tema, que incluye el emblema Astral.

Si no hay ninguna imagen válida, el panel muestra las iniciales.

## Sesiones

El selector usa `sessionModel`, por lo que solo aparecen sesiones `.desktop`
instaladas y ejecutables: Hyprland, KDE Plasma, etc. SDDM recuerda la última
sesión elegida. Al pulsar el botón de sesión, la lista se despliega sobre el
botón, no sobre el campo de contraseña.

## Teclado

La distribución de teclado activa se muestra en la esquina superior derecha,
junto al nombre del equipo. Con varias distribuciones configuradas, un clic
pasa a la siguiente. Usa `showKeyboard=false` para ocultarla.

## Estructura

```text
Main.qml                 Raíz por pantalla
design/Theme.qml         Paleta, modos y opciones
components/              Fondo, estrellas, reloj, tarjeta, botones, avatar
assets/backgrounds/      Cuatro fondos incluidos
assets/texture/          Grano fino del fondo
faces/.face.icon         Avatar por defecto del tema
theme.conf               Opciones
metadata.desktop         Metadatos de SDDM
```
