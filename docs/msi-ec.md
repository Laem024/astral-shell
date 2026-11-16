# Controlador MSI EC (opcional)

Alternativa para el límite de carga en el **Katana GF76 11UD**. No se aplica a otros equipos, que omiten esta fase.
Es opcional: el resto de la integración de energía funciona sin ella. Ver [energía](energia.md).

## Versión fijada

- Firmware EC probado: `17L2EMS1.106`. El controlador nativo de `7.3.3-1-cachyos` lo rechazó.
- Revisión fijada: [MControlSuite/msi-ec c8cbd48](https://github.com/MControlSuite/msi-ec/tree/c8cbd48ed01f5c4fa7e34ff622a66f5a5380c705), versión 0.18.
  Reconoce la familia `17L2EMS1.1` sin parámetros forzados.
- Los umbrales de carga, de 10 a 100, están presentes en `BAT1`. El valor `0` significa "sin informar", no un límite del 0 %.
  La instalación no elige ni escribe ningún porcentaje.

## Orden de la instalación

En este modelo, ambos modos (`install` y `update`) siguen este orden:

1. Reutiliza y verifica el código administrado en `/usr/src/msi-ec-0.18`, si existe. Si otro controlador ya ofrece umbrales, lo conserva.
   Si no hay ningún controlador cargado, intenta primero `modprobe msi-ec` nativo.
2. Si falla el nativo y falta el código externo, descarga **solo** la revisión fijada a un destino temporal.
   Verifica los SHA-256 de los cinco archivos originales en una copia privada antes de compilar con root.
3. Resuelve `dkms`, `clang`, `lld`, `make` y las cabeceras de los kernels CachyOS instalados, únicamente si se necesita esta alternativa.
4. Registra `msi-ec/0.18` en DKMS. Omite las compilaciones ya instaladas y compila para los kernels CachyOS con cabeceras.
   Las actualizaciones pueden retirar las cabeceras del kernel en ejecución: los kernels instalados se preparan sin depender de esas cabeceras antiguas.
5. Carga el módulo si procede y registra `msi-ec` en `/etc/modules-load.d/msi-ec.conf`.
   Nunca descarga el módulo en uso ni fuerza firmware. Si el kernel en ejecución ya fue retirado, el módulo queda preparado para el próximo arranque.

La fuente instalada también se verifica durante `update`, sin volver a descargarla si coincide. Un código alterado, una configuración DKMS distinta,
una versión cargada diferente o un fallo de compilación detienen la fase con un error explícito.
Una actualización no selecciona versiones nuevas de upstream automáticamente.

DKMS detecta el compilador del kernel: LLVM para el kernel compilado con Clang y GCC para el LTS compilado con GCC.
La configuración anterior que fijaba LLVM se migra con respaldo en `/var/lib/astral-shell/backups/`.
DKMS archiva el módulo nativo y coloca el externo en `updates/dkms/`, para poder restaurar el anterior al desinstalar.

El controlador externo puede fallar tras cambios del kernel. Con Secure Boot activo, revisa la firma del módulo.
La instalación no cambia la configuración de Secure Boot.

## Comandos

```bash
bash scripts/install-msi-ec.sh --stage ORIGEN NUEVO_DESTINO   # valida un código descargado sin instalarlo
bash tests/power/msi-source.sh ORIGEN                         # ORIGEN es el checkout de la revisión fijada; no requiere root
bash tests/power/msi-install.sh ORIGEN
```

## Pruebas

Las pruebas `tests/power/msi-*.sh` usan comandos simulados. Cubren ambos modos del instalador, la repetición sin recompilar,
kernels nuevos sin cabeceras antiguas, fuentes alteradas, dependencias ausentes, fallos de compilación y la preferencia por controladores existentes.

Queda pendiente en hardware real: carga de 0.18 tras reinicio, reconstrucción en un kernel futuro y umbrales en `BAT1` con una política elegida.

## Reversión

Quita únicamente la entrada `msi-ec` de `/etc/modules-load.d/msi-ec.conf`, o restaura su respaldo, y ejecuta:

```bash
sudo dkms remove -m msi-ec -v 0.18 --all
sudo depmod -a
```

El módulo cargado continúa hasta que lo descargues explícitamente o hasta el próximo reinicio. Mientras el código administrado siga en `/usr/src/msi-ec-0.18`,
los instaladores volverán a resolver DKMS. Para retirarlo por completo, archívalo fuera de `/usr/src` y excluye la fase MSI del flujo de energía.

## Diagnóstico

```bash
dkms status -m msi-ec -v 0.18
modinfo -n msi-ec
journalctl -k -b --no-pager -g 'msi[_-]ec'
```

Downloads use `$XDG_CACHE_HOME/astral-shell/msi` (default `~/.cache`). Privileged staging uses a private root-owned `/run/astral-shell` directory and ignores user XDG paths. Each run removes only its own staging directory.
