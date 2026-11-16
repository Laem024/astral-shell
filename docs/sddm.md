# Tema SDDM Astral

Tema de inicio de sesión para SDDM 0.21 o superior con Qt 6. Usa la paleta
oscura de Astral Shell, un cielo animado con estrellas titilantes y estrellas
fugaces diagonales, y un panel de cristal centrado que solo aparece en la
pantalla activa. La composición combina un reloj tipográfico grande, capas
translúcidas con grano fino y un único campo de contraseña. La interfaz está en
inglés.

El tema vive en el repositorio (`config/sddm/astral/`) para poder aplicarlo,
pero al instalarse se copia completo a `/usr/share/sddm/themes/astral` y deja de
depender del repositorio. No se instalan paquetes adicionales: SDDM y
`qt6-declarative` ya son requisitos del proyecto.

## Instalación y actualización

`./install.sh` y `./install.sh update` ejecutan `scripts/install-sddm.sh` con el
modo correspondiente, después de aplicar las configuraciones y antes de los
ayudantes de energía.

- **`install`**: crea o refresca el tema Astral.
- **`update`**: instala el tema si falta y lo refresca si ya existe.
- Solo se toca `/usr/share/sddm/themes/astral`. Otros temas de SDDM no se
  leen, no se copian y no se modifican.
- No se crean copias de seguridad de temas.
- Si ya existe un directorio ajeno llamado `astral`, el instalador aborta sin
  sustituirlo.
- Si existe `theme.conf`, se conserva para no perder personalizaciones. El
  resto de QML, fondos y metadatos se actualiza. Si el archivo no existe, se
  instala el valor por defecto.
- El tema instalado no contiene rutas al repositorio.

También se instala:

| Ruta | Función |
| --- | --- |
| `/usr/share/sddm/themes/astral/` | Tema completo y autocontenido |
| `/etc/sddm.conf.d/zz-astral-theme.conf` | Selecciona `Current=astral` y activa los avatares |
| `/usr/local/bin/astral-sddm-background` | Cambia el fondo del tema |

No se reinicia SDDM: reiniciarlo cerraría la sesión actual. El tema aparece la
próxima vez que arranque el greeter, normalmente al reiniciar o cerrar sesión.

### Aplicar solo el tema

```bash
bash scripts/install-sddm.sh --help
bash scripts/install-sddm.sh install
bash scripts/install-sddm.sh update
```

El script pide `sudo` para escribir en `/usr/share` y `/etc`. La opción interna
`--stage DIR` permite probarlo sin privilegios y sin tocar el sistema.

### Precedencia de la configuración de SDDM

SDDM lee `/usr/lib/sddm/sddm.conf.d/`, después `/etc/sddm.conf.d/` y finalmente
`/etc/sddm.conf`. El archivo `zz-astral-theme.conf` gana frente a otros archivos
de `/etc/sddm.conf.d/`, pero un `/etc/sddm.conf` con `Current=` tiene prioridad.
El instalador avisa si detecta ese caso.

## Multi monitor y pantalla activa

SDDM 0.21 crea una vista QML por monitor. El tema usa eso para dibujar el mismo
cielo animado en todas las pantallas y un panel de acceso distinto en la
activa.

- En `activationMode=click` (por defecto), la pantalla con el foco de teclado
  muestra el campo de contraseña. Las demás muestran el cielo atenuado, el reloj
  y el aviso **Click to sign in here**. Al hacer clic en una pantalla inactiva,
  el tema solicita la activación de esa ventana.
- En `activationMode=primary`, solo la pantalla primaria permite iniciar sesión;
  las demás muestran **Sign in on the primary display**.
- Solo hay una ventana con foco de teclado, así que solo hay una contraseña
  activa a la vez.
- Al desactivar una pantalla se destruye su panel y se borra el texto de la
  contraseña.
- En X11, que es el `DisplayServer` por defecto de SDDM, el cambio de foco
  funciona directamente. En el greeter Wayland depende de que el compositor
  acepte `requestActivate()`; si no lo hace, cambia a `activationMode=primary`.

El monitor primario se puede ajustar desde el firmware, el compositor o la
configuración de pantallas del sistema.

## Personalización

Edita el archivo instalado:

```bash
sudoedit /usr/share/sddm/themes/astral/theme.conf
```

Los cambios se aplican en el siguiente arranque del greeter. Las claves ausentes
usan los valores por defecto del QML, así que una actualización no rompe un
`theme.conf` antiguo.

| Clave | Valor por defecto | Efecto |
| --- | --- | --- |
| `background` | `aurora` | Preset, ruta relativa o absoluta |
| `backgroundMode` | `fill` | `fill`, `fit`, `stretch` o `tile` |
| `backgroundDrift` | `true` | Deriva lenta del fondo |
| `overlay` | `0.24` | Oscurecimiento del fondo |
| `glassOpacity` | `0.52` | Opacidad del panel de cristal (0 a 1) |
| `animations` | `true` | Entrada, estrellas, fugaces y shake |
| `stars` | `true` | Estrellas titilantes |
| `starDensity` | `1.0` | Densidad de estrellas |
| `shootingStars` | `true` | Estrellas fugaces |
| `meteorCount` | `2` | Fugaces por pantalla |
| `meteorAngle` | `28` | Ángulo diagonal en grados |
| `scale` | `1.0` | Escala general |
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

### Fondos

El tema incluye cuatro fondos originales:

- `aurora`: verdes y ámbar, con una aurora vertical.
- `nebula`: azules y lavanda.
- `dusk`: horizonte cálido y verde profundo.
- `void`: casi negro con polvo cian.

Para usar uno:

```ini
background=dusk
```

También se aceptan rutas relativas al tema y rutas absolutas. El usuario `sddm`
debe poder leer la imagen; si está dentro de un home con permisos `700`, la
lectura puede fallar.

### Cambiar el fondo con el helper

```bash
sudo astral-sddm-background aurora
sudo astral-sddm-background /ruta/a/mi-fondo.jpg
astral-sddm-background --list
```

El helper copia la imagen personalizada a `assets/backgrounds/custom.<ext>` y
actualiza solo la clave `background` de Astral. No toca otros temas, no crea
copias de seguridad y no reinicia SDDM. Acepta JPG, PNG y WebP.

## Usuarios y avatares

El tema usa `userModel` de SDDM. Si hay más de un usuario, la fila del usuario
abre un selector. El avatar se resuelve en este orden:

1. `~/.face.icon` del usuario.
2. `/usr/share/sddm/faces/<usuario>.face.icon`.
3. La foto de AccountsService.
4. `faces/.face.icon` del tema, con el emblema Astral.

Si no hay imagen válida, el panel muestra las iniciales. La clave `avatar` de
`theme.conf` permite forzar un avatar común.

## Sesiones

El selector usa `sessionModel`, por lo que solo lista sesiones `.desktop`
instaladas y ejecutables: Hyprland, KDE Plasma, etc. No hay una lista fija en el
tema. SDDM recuerda la última sesión elegida.

## Idioma

Todos los textos de la interfaz están en inglés. La fecha se formatea con
`en_US` para que no cambie con el locale del sistema. El formato del reloj se
elige con `clockFormat`.

La distribución de teclado activa aparece en la esquina superior derecha. Si
hay más de una configurada, al pulsarla se pasa a la siguiente. Se puede
ocultar con `showKeyboard=false`.

## Pruebas

### Instalador y helper, sin root

```bash
bash tests/sddm/run.sh
```

La prueba usa `--stage` en un directorio temporal y comprueba instalación,
actualización, preservación de `theme.conf`, rechazo de un tema ajeno, ausencia
de copias de seguridad, ausencia de rutas al repositorio y el helper de fondo.

### Arranque QML

```bash
bash tests/sddm/greeter.sh
```

Arranca `sddm-greeter-qt6 --test-mode` con la plataforma `offscreen`, revisa el
journal reciente y falla si aparecen errores de sintaxis, tipos o propiedades.

### Vista previa manual

```bash
sddm-greeter-qt6 --test-mode --theme "$PWD/config/sddm/astral"
```

Abre el greeter de prueba sobre la sesión actual. Puede cubrir las pantallas;
ciérralo con `Ctrl+C` o matando el proceso. Comprueba:

- Un solo panel de acceso y un solo campo de contraseña.
- Cambio de pantalla al hacer clic (o modo primario).
- Reloj, fecha en inglés y nombre del equipo.
- Avatar, usuario y selector de sesión.
- Fondo, estrellas titilantes y fugaces.
- Contraseña incorrecta, shake y mensaje en inglés.
- Cambio de fondo desde `theme.conf` y con `astral-sddm-background`.

### Comprobación estática

```bash
bash -n install.sh scripts/*.sh
git diff --check
```

El panel no usa efectos de desenfoque ni módulos QML adicionales: las capas de
cristal, el brillo superior, la sombra y el grano se dibujan con `Rectangle`,
`Gradient` e `Image`. Por eso el tema sigue funcionando con los mismos
requisitos de Qt 6 y también en el renderizador por software.

## Diagnóstico

- **El greeter muestra el tema de respaldo:** revisa el journal con
  `journalctl -b | grep sddm-greeter` y corrige el error QML indicado.
- **No aparece el tema:** comprueba `/etc/sddm.conf.d/zz-astral-theme.conf` y
  que ningún `/etc/sddm.conf` anterior imponga otro `Current=`.
- **El avatar no aparece:** revisa `~/.face.icon` y
  `/usr/share/sddm/faces/<usuario>.face.icon`; el usuario `sddm` debe poder
  leerlos.
- **El fondo personalizado no se ve:** usa el helper o una ruta legible por
  `sddm`; evita imágenes dentro de un home con permisos `700`.
- **El clic entre pantallas no cambia el foco:** usa
  `activationMode=primary`.
- **Los cambios no se aplican:** el greeter solo lee el tema al arrancar; no se
  reinicia desde `install.sh`. Reinicia o cierra sesión.

## Desinstalación manual

No hay un desinstalador automático. Para retirar solo Astral:

```bash
sudo rm -rf /usr/share/sddm/themes/astral
sudo rm -f /etc/sddm.conf.d/zz-astral-theme.conf
sudo rm -f /usr/local/bin/astral-sddm-background
```

Después selecciona otro tema o elimina el `Current=` que apunte a Astral. No se
tocan otros temas.
