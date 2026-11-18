# Conectividad, audio y música

Controles en vivo del panel: Wi-Fi, Bluetooth, VPN, sonido y reproductores MPRIS.
Los servicios viven en `config/quickshell/astral-bar/data/`, y las tarjetas en `config/quickshell/astral-bar/panel/`.
No se instalan paquetes adicionales, salvo los ya listados en el catálogo.

## Panel de conexiones

La categoría **Connections** abre con un selector Wi-Fi/Bluetooth/VPN, un estado breve y una sola sección visible.
Los controladores siguen activos al cambiar de sección; se conservan adaptadores, búsqueda, formularios y perfiles.

Cada tarjeta comparte la misma cabecera: sigilo de color, etiqueta monoespaciada, título, estado y un interruptor cuando
el transporte lo admite. Wi-Fi usa cian, Bluetooth lavanda y VPN dorado. Las listas se separan con un control segmentado
(**Available/Saved**, **Saved/Nearby**) y los formularios, la importación y las confirmaciones sustituyen el contenido de
la tarjeta; Escape vuelve a la lista.

Los componentes compartidos están en `panel/`: `ConnectionMark.qml` (sigilo), `ConnectionTabs.qml` (control segmentado),
`StatusPill.qml` (etiqueta de estado), `PanelSwitch.qml` y `EmptyState.qml` (listas vacías o no disponibles).

## Wi-Fi (NetworkManager)

`panel/WifiCard.qml` sustituye la vista previa por controles reales de NetworkManager.

- Elige un adaptador, escanea, conecta, desconecta o activa un perfil guardado aunque no aparezca en el escaneo.
- Las redes se agrupan por SSID y seguridad, por adaptador. La conexión activa muestra su potencia y un botón de desconexión.
- Las pestañas **Available** y **Saved** separan redes cercanas y perfiles almacenados.
- Los formularios y la confirmación de **olvidar** se muestran en una vista dedicada; Cancelar o Escape vuelve a la lista y borra las credenciales pendientes.
- Redes ocultas: SSID exacto, con seguridad Abierta, WPA/WPA2 Personal o WPA3 Personal.
  Si existe un perfil compatible, se reutiliza. Los nuevos usan DHCP y no se conectan automáticamente hasta que la activación funcione.
- Si falla la creación o la activación, solo se elimina el UUID nuevo. Los perfiles empresariales (EAP y certificados) se pueden activar,
  pero deben crearse con un editor externo. La interfaz no gestiona Ethernet.

Las contraseñas viajan por stdin (`connection up ... passwd-file /dev/stdin`). Nunca aparecen en argumentos de procesos,
ni en archivos del panel. Los saltos de línea y los NUL no se admiten. No se usa sudo ni un agente de autenticación adicional:
hace falta el permiso existente de NetworkManager y PolicyKit.

`data/NetworkData.qml` comparte adaptadores, puntos de acceso, perfiles y errores entre monitores. Cada comando de `NmCommand.qml`
tiene un límite de 30 segundos. Los refrescos de lectura se hacen cada 15 segundos si hay tarjeta Wi-Fi, y cada 60 si no.
Solo **Scan** solicita un escaneo explícito.

## Bluetooth (BlueZ)

`panel/BluetoothCard.qml` usa `data/BluetoothData.qml` y un proceso interactivo de `bluetoothctl`.

- **Scan** dura 20 segundos (o hasta **Stop scan**). Conecta, desconecta, reconecta y olvida dispositivos.
- Las pestañas **Saved** y **Nearby** separan dispositivos guardados y detectados. Los conectados aparecen primero.
- El emparejamiento y el olvido usan una vista dedicada. Olvidar pide confirmación y elimina el emparejamiento, incluso si está activo.
- Admite PIN, passkey y confirmación explícita. Tras emparejar, confirma, marca como confiable y conecta.
- Al cerrar la última vista de Conexiones se detiene el escaneo y se cancela el emparejamiento pendiente.
- Tiempos: 30 segundos por comando y 120 segundos para emparejar. Los PIN no se registran ni se guardan.
- La reconexión es manual. La interfaz no reintenta conexiones perdidas en segundo plano.

Requiere `bluez` y `bluez-utils`, un servicio Bluetooth en ejecución y permisos de sesión adecuados.

## VPN (NetworkManager)

`panel/VpnCard.qml` y `data/VpnData.qml` gestionan los perfiles de NetworkManager.

- Lista los perfiles WireGuard (`wireguard`) y OpenVPN (`vpn` con servicio `org.freedesktop.NetworkManager.openvpn`).
  Los túneles creados solo con `wg-quick` u `openvpn-client` no aparecen.
- Conectar y desconectar usan `nmcli connection up|down`. Ninguna VPN se activa automáticamente.
- **Import profile** navega desde `$HOME` con filtros `*.conf` y `*.ovpn`. Un `.ovpn` se importa como OpenVPN; un `.conf`
  se importa como WireGuard por defecto y permite elegir OpenVPN antes de confirmar.
- La importación (`nmcli connection import type ... file ...`) y el borrado (`nmcli connection delete`) piden confirmación.
  Borrar un perfil activo corta ese túnel.
- El panel nunca lee ni muestra el contenido de los archivos: NetworkManager guarda las claves en sus perfiles del sistema.
- No hay formulario de credenciales: si un perfil OpenVPN las necesita y no las tiene guardadas, la activación falla y se muestra el error.
- Requiere `networkmanager`. OpenVPN necesita `networkmanager-openvpn`; WireGuard usa el módulo del kernel y no requiere `wireguard-tools`.
- Prueba aislada: `bash tests/vpn/run.sh` usa un `nmcli` simulado y no activa conexiones reales.

## Sonido (PipeWire)

El icono de volumen y la categoría Sound abren `panel/SoundPage.qml`.

- Sin resúmenes repetidos: las secciones compactas **Output** y **Microphone** eligen el dispositivo predeterminado y controlan volumen y silencio.
- La mezcla de aplicaciones muestra cada flujo de reproducción por separado. Los flujos de grabación no aparecen.
  Varios flujos de una misma aplicación tienen filas separadas con sus descripciones.
- Cambiar el dispositivo predeterminado usa la política normal del gestor de sesión. No hay enrutamiento por aplicación.
- Los deslizadores escriben de 0 a 100 % en incrementos de 1 %, sin cambiar el silencio. Un valor externo superior a 100 % se conserva sin modificar al abrir la página.
- `data/AudioData.qml` comparte el estado de PipeWire con la barra. `panel/VolumeControl.qml` es el control reutilizable.
- `components/SoundGlyph.qml` reúne los iconos del panel (altavoz, auriculares, micrófono, pantalla, mezclador y flujo)
  en el mismo lenguaje de líneas de 24 × 24 que el resto de instrumentos.

## Música (MPRIS)

- `data/MediaData.qml` es el singleton compartido por todas las barras y por la página de música.
- `data/MediaService.qml` contiene la selección, las capacidades y el progreso.
- La carátula de la barra y del panel usa el recorte redondeado compartido; los paneles pequeños conservan desplazamiento y selector de reproductor.
- La barra muestra portada (o un motivo musical de respaldo), título, artista y progreso. En modo compacto, solo los controles.
  Pulsar la portada o el título abre la página de música.
- Selector: **Automatic** mantiene el reproductor actual si está sonando; si no, elige uno que esté sonando y después el primero disponible.
  Una elección manual persiste entre monitores hasta volver a **Automatic** o hasta que ese reproductor se cierre.
- Las instancias `playerctld` se ocultan si hay reproductores directos. Los nombres repetidos reciben el nombre del servicio como sufijo.
- La página de música muestra la portada con su proporción original, controles abajo y barra de posición.
  Aleatorio y repetir (Off → Track → Playlist → Off) siguen las capacidades del reproductor.
- Teclado: Tab para los controles, Enter o Espacio para activar, y las flechas en el deslizador de posición.
  Sin duración conocida se muestra `—`, sin porcentaje inventado. La posición se actualiza cada segundo mientras suena.

No hay controles de cola ni sondeo de TrackList: la música usa solo el servicio MPRIS nativo de Quickshell.

## Pruebas

Estas pruebas no modifican dotfiles activos ni controlan reproductores reales. Lista completa en [pruebas](pruebas.md):

```bash
bash tests/network/run.sh
bash tests/bluetooth/run.sh
bash tests/audio/run.sh
bash tests/audio/run-controls.sh     # usa PipeWire real con dispositivos virtuales temporales
bash tests/media/run.sh
bash tests/media/run-layout.sh
```

Validación manual recomendada en una sesión gráfica: el icono de conexión con Wi-Fi y Ethernet a la vez (gana Ethernet), cambios de SSID,
contraseñas incorrectas, redes ocultas, reconexión tras reinicio, dispositivos Bluetooth reales, emparejamiento y su rechazo,
dos aplicaciones reproduciendo, silencio independiente, cambio de dispositivo, desconexión de dispositivos y reproductores MPRIS reales.
Compara con `nmcli device status`, `wpctl get-volume @DEFAULT_AUDIO_SINK@` y `upower -d`.
No desconectes el equipo activo ni reinicies servicios para ejecutar la validación básica.
