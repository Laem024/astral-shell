# Notificaciones

Astral implementa el servidor de notificaciones de la sesión dentro de Quickshell. No se instala ningún daemon adicional
ni un servicio systemd. El servicio (`data/NotificationService.qml`) arranca una sola vez con la barra
y lo usan los popups, el historial y la política de sonido.

## Historial y No molestar

- El historial guarda las últimas 100 notificaciones normales **solo en memoria**. Se pierde al reiniciar o recargar Quickshell.
  No se escribe nada en disco.
- LOG cuenta las no leídas en todos los monitores. Abrir **Notifications** las marca como leídas, incluidas las que llegan mientras la página está visible.
- La cabecera del historial muestra el total; LOG muestra solo las no leídas. La barra de herramientas permanece visible al desplazarse.
- Acciones de historial: No molestar (con interruptor **Enabled/Disabled**), eliminar una notificación y borrar todo el historial.
- Una notificación que reemplaza a otra actualiza la existente y la sube al principio.
- **No molestar** oculta los popups, pero las notificaciones normales siguen en el historial.
- Las críticas y las de tiempo cero explícito permanecen visibles.

## Popups

- Hasta tres popups, arriba a la derecha del monitor enfocado, separados 6 píxeles escalados y sin solapar la barra.
  Cada popup se queda en su monitor original; si ese monitor se desconecta, pasa al primero disponible.
- Duración por defecto de 6 segundos. Respeta el tiempo de espera del remitente. Pasar el ratón pausa el temporizador.
- **Hide** solo oculta el popup. **Delete** y **Clear history** cierran la notificación correspondiente.
- Las notificaciones normales conservan sus acciones después de que el popup expire.
  Las transitorias se cierran con motivo `expired` cuando se ocultan o caducan.
- Una notificación idéntica sin cambios no reinicia el temporizador: Quickshell 0.3.2 no emite señal en ese caso.

Cada pantalla mantiene una superficie transparente con máscara de entrada vacía cuando no hay popups.
Así, una nueva notificación actualiza el contenido sin crear ventanas ni pedir foco de teclado.
Los botones de los popups tampoco reciben foco de teclado.

## Acciones y seguridad

- Las acciones usan [`NotificationAction.invoke()`](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Notifications/NotificationAction/),
  que mantiene las notificaciones residentes.
- Pulsar el resumen o **Open** ejecuta la acción predeterminada o abre la entrada de escritorio que Quickshell encuentre.
  Si no hay ninguna, **Open** se oculta.
- Un cierre solicitado por el remitente conserva el texto en el historial y elimina las acciones remotas.
- Títulos y cuerpos se muestran como texto plano. Nunca se ejecuta contenido recibido como comando de shell.

## Política de sonido de notificaciones

`data/NotificationSoundPolicy.qml`, instanciado una vez por `shell.qml`, silencia mientras **No molestar** está activo
los flujos de PipeWire cuyo `media.role` es `Notification` o `Event`. Al desactivarlo restaura el estado de silencio anterior.

- No cambia el volumen del dispositivo de salida, la música, las llamadas ni el micrófono.
- Cubre los flujos existentes y los nuevos que se identifiquen.
- Las aplicaciones que reproducen sonidos sin ese rol no se pueden silenciar de forma selectiva: desactiva esos sonidos en la aplicación.
- Un sonido muy corto puede empezar antes de que PipeWire exponga el flujo.

## Pruebas

```bash
bash tests/notifications/run.sh          # D-Bus aislado y Qt sin pantalla
bash tests/notifications/run-focus.sh    # requiere una sesión Hyprland
busctl --user status org.freedesktop.Notifications   # ¿quién posee el servicio?
```

Solo un proceso puede poseer `org.freedesktop.Notifications`. Si otro daemon lo tiene, detenlo mediante su configuración de sesión antes de probar Astral.
Quickshell registra el conflicto y reintenta cuando el otro propietario se cierra.
No ejecutes a la vez la barra instalada y la copia del repositorio al probar la entrega de notificaciones.

Prueba manual con `notify-send` y `xdg-open`:

```bash
accion=$(notify-send \
  --app-name="Prueba astral" \
  --icon=folder \
  --expire-time=0 \
  --action="open-folder=Abrir carpeta" \
  "Archivo disponible" \
  "Pulsa Abrir carpeta para abrir tu carpeta personal.")

if [ "$accion" = "open-folder" ]; then
  xdg-open "$HOME"
fi
```

El remitente espera la acción y abre el explorador. Sirve para validar el flujo de acciones de cualquier notificación con botones.

Validación manual en CachyOS: navegación con teclado, pantallas pequeñas, colocación en el monitor enfocado,
desconexión de monitores y supresión de sonido con la aplicación real que emite la alerta.

File openings use one `common/ApplicationLaunch.qml` instance per operation, with literal arguments, XDG environment, `Type=exec`, `ExitType=cgroup` and environment expansion disabled. Video detection, launch status and the file-manager-to-terminal fallback are retained.
