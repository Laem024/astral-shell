# Tema SDDM Astral

Tema de inicio de sesión para SDDM 0.21 o superior con Qt 6. Usa la paleta oscura
de Astral Shell, un cielo animado con estrellas titilantes y estrellas fugaces,
y un panel de cristal centrado que solo aparece en la pantalla activa.

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
| `background` | `aurora` | Preset, ruta relativa o absoluta |
| `backgroundMode` | `fill` | `fill`, `fit`, `stretch` o `tile` |
| `backgroundDrift` | `true` | Deriva lenta del fondo |
| `overlay` | `0.24` | Oscurecimiento del fondo (0 a 1) |
| `glassOpacity` | `0.52` | Opacidad del panel de cristal (0 a 1) |
| `animations` | `true` | Entrada, estrellas, fugaces y shake |
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
| `accentColor` | `#B1D7CB` | Color principal |
| `lavenderColor` | `#C6CCD2` | Color secundario |
| `goldColor` | `#E4B882` | Fechas y detalles |
| `textColor` | `#F4EEDF` | Texto principal |
| `mutedColor` | `#B1B5AD` | Texto secundario |
| `surfaceColor` | `#202629` | Panel de acceso |
| `backgroundColor` | `#151918` | Fondo base |
| `alertColor` | `#FF957C` | Errores |

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
design/Theme.qml         Paleta y opciones
components/              Fondo, estrellas, reloj, panel y popups
assets/backgrounds/      Cuatro fondos incluidos
assets/texture/          Grano fino del fondo
faces/.face.icon         Avatar por defecto del tema
theme.conf               Opciones
metadata.desktop         Metadatos de SDDM
```
