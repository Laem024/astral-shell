# Monitor de recursos

`config/monitor/` instala el comando `astral-monitor`, un lanzador de `btop` para el espacio especial
`resources`. La interfaz de `btop` está en inglés.

## Uso

```bash
astral-monitor [toggle|open|close]
```

- `toggle` es la acción por defecto. Abre el monitor si no está abierto y lo cierra si ya lo está.
- `open` abre o enfoca el monitor sin cerrarlo.
- `close` cierra el espacio especial y termina `btop`.

El atajo principal es `Ctrl + Shift + Esc`. La primera pulsación cierra los paneles de Astral que estén
abiertos, lanza `kitty` con `btop` en el espacio especial `resources` y enfoca la ventana. La segunda
pulsación cierra el espacio y termina el proceso. Si sales de `btop` con `q`, o cierras la ventana con
`Super + Q`, el espacio especial también se cierra.

Con la sesión bloqueada el atajo no abre el monitor, igual que el resto de módulos de Astral.

## Requisitos

- `hyprctl` (Hyprland).
- `jq`.
- `flock` (`util-linux`).
- `kitty`.
- `btop` con soporte de GPU para mostrar la tarjeta NVIDIA.

`btop` está marcado como requerido en `packages/pacman.list`. `kitty` sigue siendo recomendado porque
también lo usa el resto del entorno.

## Instalación

```bash
bash scripts/manage-configs.sh apply monitor
# o dentro de una instalación completa
bash scripts/manage-configs.sh apply all
```

El gestor copia `config/monitor/` a `~/.config/astral-monitor/` y escribe
`~/.local/bin/astral-monitor` con la ruta absoluta del módulo instalado. Si el comando ya existía con
otro contenido, se conserva una copia `.backup-*`.

## Configuración

| Archivo | Función |
| --- | --- |
| `~/.config/astral-monitor/btop.conf` | Cajas visibles, intervalo, GPU, discos, batería y temperaturas |
| `~/.config/astral-monitor/themes/astral.theme` | Paleta de `btop` basada en el tema oscuro de Astral |

`btop.conf` activa `cpu mem gpu0 net proc`, con memoria, swap, discos, red, procesos, batería y
temperaturas. La configuración se instala con `save_config_on_exit = false`, así que los cambios hechos
desde el menú de `btop` no se guardan. Para personalizarla, edita `config/monitor/btop.conf` y vuelve a
aplicar el módulo; el archivo anterior se respalda.

Si el equipo no tiene GPU, quita `gpu0` de `shown_boxes` en `btop.conf` y cambia
`show_gpu_info = "Off"`. Los equipos con AMD o Intel también pueden mostrar su GPU si `btop` la detecta.

## Espacio especial y ventana

El nombre del espacio está en dos lugares:

- `config/hyprland/modules/variables.lua`, en `special_workspaces.resources`.
- `config/monitor/astral-monitor.sh`, en la variable `workspace`.

La regla de `config/hyprland/modules/rules.lua` coloca la ventana de clase `astral-monitor` en
`special:resources`, la deja flotante y la abre a pantalla completa. Si prefieres ver la barra, elimina
`fullscreen = true` de esa regla y ajusta el tamaño con `size` o `maximize`.

El script comprueba que la ventana esté realmente en el espacio especial. Si la regla no se aplica,
intenta moverla con `hyprctl`.

## Pruebas

```bash
bash tests/monitor/run.sh
```

La prueba usa `hyprctl`, `kitty` y `astral-lock` simulados. Comprueba el bloqueo de sesión, el arranque
perezoso, la alternancia, el cierre al salir de `btop`, la ausencia de duplicados, los errores por
comandos ausentes y la instalación del comando.

Comprobaciones manuales en Hyprland:

1. `Ctrl + Shift + Esc` abre `special:resources` con `btop` a pantalla completa.
2. `Ctrl + Shift + Esc` cierra el espacio y termina `btop`.
3. `q` dentro de `btop` cierra el espacio.
4. `Super + Q` con el monitor enfocado cierra la ventana y el espacio.
5. La caja de GPU muestra la tarjeta NVIDIA; sin NVIDIA, el resto del monitor sigue funcionando.
6. El tema `astral` carga con la paleta del entorno.

## Solución de problemas

- **No aparece la ventana:** comprueba `hyprctl clients -j` y busca `"class": "astral-monitor"`.
  Si no existe, revisa la salida de `astral-monitor open`.
- **Se abre en el espacio normal:** verifica la regla `astral-monitor-workspace` en
  `config/hyprland/modules/rules.lua` y recarga Hyprland.
- **No hay caja de GPU:** ejecuta `nvidia-smi` y confirma que `btop` se compiló con soporte de GPU.
- **El atajo no hace nada:** comprueba que `astral-monitor` está en `PATH` y que la sesión no está
  bloqueada.
- **Error de comando ausente:** instala `btop`, `kitty`, `jq` y `flock`, o revisa la notificación de
  Hyprland.

## Validación

```bash
bash -n config/monitor/astral-monitor.sh scripts/configs/monitor.sh
luac -p config/hyprland/modules/*.lua
Hyprland --verify-config -c "$PWD/config/hyprland/hyprland.lua"
bash tests/monitor/run.sh
```

Open/toggle fail closed unless XDG runtime is valid, `astral-shell/lock-pending` is absent, and logind explicitly reports `LockedHint=no`. Privacy is checked again after the mutex and before launching/showing; `close` remains available. The monitor remains independent of Quickshell.
