# Guía de Implementación e Instalación: pos-peripherals-agent

Esta guía detalla los pasos para instalar, compilar y ejecutar **`pos-peripherals-agent`** tanto en entornos de **Desarrollo** como de **Producción**, desglosada por sistema operativo (**Windows**, **Linux** y **macOS**).

---

## Canal de evaluación y recuperación

Durante el prototipo se mantiene la versión base 1.2.0. El job
`publish-preview` de [CI](../.github/workflows/ci.yml) solo publica tras un push a
`main` con pruebas y builds de los tres targets exitosos. No publica desde PRs
ni ejecuciones manuales. La primera ejecución remota y sus descargas deben
verificarse antes de afirmar que el canal está operativo.

El prerelease `preview` es móvil y no es el release estable `latest`. Sus paquetes
incluyen SHA completo en el nombre y `build-manifest.json` con versión, target,
fecha UTC y run/intento. Verificar el `.sha256` del archivo descargado y
`SHA256SUMS.txt` tras extraerlo. Los builds obsoletos no reemplazan el canal.
Los tags estables `vX.Y.Z` siguen separados e inmutables.

El preview anterior conserva binarios, documentos y hashes en
`preview-archive-<release-id>`. Ante un fallo durante la promoción, el publicador
intenta restaurar el tag y release anteriores. Si el rollback falla, CI falla
explícitamente: no considerar el canal coherente hasta revisar el SHA del tag,
el manifiesto y todos los activos.

Para recuperar manualmente un preview, con autorización explícita: inspeccionar
el archivo histórico completo, confirmar su SHA/hashes, devolver el nuevo release
a un borrador con su tag `preview-build-*`, restaurar únicamente el ref `preview`
al SHA anterior y devolver el release archivado al nombre de tag `preview`.
Verificar nuevamente los tres paquetes y sus descargas. Nunca mover un tag
`vX.Y.Z`, mezclar activos de builds o borrar históricos como atajo.
Los borradores de preparaciones fallidas/obsoletas y archivos históricos se
conservan para inspección; su limpieza requiere una decisión de retención
autorizada.

## 1. Requisitos Previos Globales

### 1.1 Instalar Rust y Cargo
En cualquier sistema operativo, la instalación oficial de Rust se realiza con:

- **macOS / Linux:**
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source "$HOME/.cargo/env"
  ```
- **Windows:**
  Descargar y ejecutar el instalador oficial **`rustup-init.exe`** desde [https://rustup.rs](https://rustup.rs).
  *Nota:* Requiere los "Visual Studio Build Tools" (C++ build tools) seleccionados durante la instalación.

Verificar instalación:
```bash
rustc --version
cargo --version
```

---

## 2. Instalación en Ambiente de Desarrollo

El ambiente de desarrollo permite compilar rápido con depuración, logs detallados y modo de simulación de hardware activado (ideal si no tienes una báscula física conectada al computador).

### 2.1 En Windows (Desarrollo)
1. Abrir PowerShell o Windows Terminal en la carpeta del proyecto:
   ```powershell
   cd pos-peripherals-agent
   ```
2. Generar el archivo de configuración local:
   ```powershell
   copy config.example.toml config.toml
   ```
3. En `config.toml`, verificar que `simulation_mode = true` en la sección `[scale]`.
4. Ejecutar el servidor en modo desarrollo:
   ```powershell
   cargo run
   ```
   *Alternativa rápida:* Doble clic en `scripts\run_windows.bat`.

### 2.2 En macOS (Desarrollo y Paquete Precompilado)
1. Abrir la Terminal en la carpeta del agente o del paquete descomprimido.
2. Asignar permisos de ejecución y retirar la marca de cuarentena de macOS (Gatekeeper):
   ```bash
   chmod +x pos-peripherals-agent scripts/run_macos_linux.sh
   ```
   > **Nota sobre macOS Gatekeeper:** Los scripts no eliminan la cuarentena automáticamente. Verificar primero origen, checksum y firma cuando exista. Si macOS bloquea el binario, detenerse y revisar la autorización con el administrador en *Ajustes del Sistema > Privacidad y Seguridad*. No borrar recursivamente atributos del paquete.
3. Copiar plantilla de configuración (si no existe):
   ```bash
   cp config.example.toml config.toml
   ```
4. Si conectas un adaptador USB-Serial (Prolific / FTDI / CH340), identifica el puerto con:
   ```bash
   ls -la /dev/tty.usb*
   ```
   Y ajusta `port = "/dev/tty.usbserial-XXXX"` en `config.toml`. Si no tienes báscula física, deja `simulation_mode = true`.
5. Ejecutar:
   ```bash
   ./scripts/run_macos_linux.sh
   # O directamente con cargo si compilas desde código fuente:
   cargo run
   ```

### 2.3 En Linux (Ubuntu / Debian / RHEL) (Desarrollo)

#### Aceptación de trabajos RAW en Linux/macOS

El servicio necesita un cliente CUPS (`lpr` o, si este no está instalado, `lp`) y
una cola accesible para el usuario del servicio. Etiquetas, tickets RAW, matriz y
gaveta comparten el mismo despacho: `lpr -l`, con alternativa `lp -o raw`
únicamente cuando el ejecutable `lpr` no existe. La simulación solo es explícita.

Un exit code exitoso confirma aceptación del despacho, no salida física del
papel ni apertura de gaveta. Un rechazo, señal o fallo de ejecución devuelve
HTTP 500 con `status: error`; un timeout devuelve HTTP 504. No se reenvía un
trabajo tras rechazo o timeout. Revisar cola, disponibilidad de CUPS, nombre de
destino y permisos desde la cuenta del servicio antes de reintentar. Un timeout
puede ocurrir después de que la cola aceptó el trabajo y el reintento puede
duplicarlo. El archivo temporal RAW se elimina al finalizar la operación.
No se registran payloads RAW ni stdout/stderr del comando en esta ruta.
1. Instalar librerías de desarrollo del sistema necesarias para compilar `serialport`:
   ```bash
   # Ubuntu / Debian
   sudo apt-get update && sudo apt-get install -y build-essential pkg-config libudev-dev
   # Fedora / RHEL
   sudo dnf install -y gcc pkg-config systemd-devel
   ```
2. Permisos de puerto serial (agrega tu usuario al grupo `dialout` o `tty`):
   ```bash
   sudo usermod -aG dialout $USER
   # Cerrar sesión y volver a entrar para aplicar cambios de grupo
   ```
3. Copiar configuración y ejecutar:
   ```bash
   cp config.example.toml config.toml
   cargo run
   ```

---

## 3. Instalación en Ambiente de Producción

En producción, el binario debe:
1. Compilarse con optimizaciones máximas (`--release`), reduciendo el tamaño a ~5 MB.
2. Ejecutarse desatendidamente en segundo plano como un **servicio del sistema operativo** con reinicio automático si la máquina se apaga o reinicia.

---

### 3.1 PRODUCCIÓN EN WINDOWS (PCs Facturadoras de Tienda)

Este es el entorno principal de las cajas donde operan los cajeros y facturadores.

---

#### Método A: Despliegue con Paquete Oficial Precompilado (Recomendado)

Este método utiliza el archivo oficial descargable `omnibridge-pos-windows-x86_64.zip` (disponible en GitHub Releases) y configura el servicio permanente de Windows mediante NSSM en menos de 2 minutos.

##### Paso 1: Descargar y Descomprimir en `C:\PosAgent`
1. Descarga el paquete `omnibridge-pos-windows-x86_64.zip` de la última versión.
2. Descomprime su contenido dentro de la carpeta:
   ```text
   C:\PosAgent
   ```
   *(La carpeta debe contener directamente: `pos-peripherals-agent.exe`, `config.toml`, `installer\`, etc.)*

##### Paso 2: Preparar Carpeta de Utilidades (`tools`)
Abre **PowerShell como Administrador** (clic derecho en Inicio $\rightarrow$ *Terminal (Administrador)* o *PowerShell (Administrador)*), navega al directorio y copia las utilidades de impresión y servicio:

```powershell
Set-Location -Path "C:\PosAgent"
Copy-Item -Recurse .\installer\tools .\tools
```
*(Esto deja listos `C:\PosAgent\tools\nssm.exe` y `C:\PosAgent\tools\SumatraPDF.exe` para impresión silenciosa de tickets).*

##### Paso 3: Colocar la Licencia Comercial (`license.key`)
Copia el archivo `license.key` provisto para el comercio directamente en la raíz de la carpeta:
```text
C:\PosAgent\license.key
```

##### Paso 4: Ajustar Configuración en `C:\PosAgent\config.toml`
Abre `config.toml` con el Bloc de notas para verificar los periféricos:
```toml
[server]
host = "127.0.0.1"     # Modo A (estándar loopback): solo esta caja
port = 8989
legacy_print_port = 0  # 0 = deshabilitado (usar puerto unificado 8989)
legacy_label_port = 0  # 0 = deshabilitado (usar puerto unificado 8989)
cors_origins = []      # Origen HTTPS exacto del POS web que corre en esta caja
api_key = ""           # Vacía en Modo A

[scale]
port = "auto"          # "auto" para escaneo automático de puerto COM, o "COM3", "COM4", etc.
baud_rate = 9600       # 9600 estándar (o 4800 según la balanza)
timeout_ms = 1000
simulation_mode = false  # false en producción con báscula física (true solo para pruebas sin cable)

[printer]
default_printer = "POS-80"               # Nombre exacto en el SO de la ticketera térmica
default_label_printer = "3nStar 4B-2054L" # Nombre de la etiquetadora de código de barras
default_matrix_printer = "Generic / Text Only"
default_document_printer = "auto"
sumatra_path = "tools\\SumatraPDF.exe"
sumatra_args = "-print-to {printer} -print-settings noscale -silent {file}"
```

##### Paso 5: Instalar y Configurar el Servicio con NSSM
Dispones de dos alternativas para instalar el servicio en Windows:

**Opción 1: Ejecutar el Script Automatizado (Recomendado)**
```powershell
Set-Location -Path "C:\PosAgent"
powershell -ExecutionPolicy Bypass -File .\scripts\install_windows_service.ps1
```
*(El script detecta la carpeta, prepara las herramientas, instala el servicio en NSSM y lo inicia automáticamente).*

**Opción 2: Ejecutar los Comandos Manuales Paso a Paso**
```powershell
# 1. Instalar el ejecutable como servicio nativo de Windows
.\tools\nssm.exe install OmniBridgePos "C:\PosAgent\pos-peripherals-agent.exe"

# 2. Configurar la carpeta de trabajo (fundamental para leer config.toml y license.key)
.\tools\nssm.exe set OmniBridgePos AppDirectory "C:\PosAgent"

# 3. Asignar descripción clara en el panel de Servicios de Windows
.\tools\nssm.exe set OmniBridgePos Description "OmniBridge POS - Agente Universal de Periféricos (Báscula, Tickets, Etiquetas y Gaveta)"

# 4. Configurar arranque automático al encender el equipo (antes de iniciar sesión)
.\tools\nssm.exe set OmniBridgePos Start SERVICE_AUTO_START

# 5. Configurar auto-recuperación si ocurre algún imprevisto
.\tools\nssm.exe set OmniBridgePos AppRestartDelay 3000

# 6. Iniciar el servicio inmediatamente
Start-Service OmniBridgePos
```

##### Paso 6: Verificación y Estado
1. **Comprobar en PowerShell:**
   ```powershell
   Get-Service OmniBridgePos
   ```
   *Debe responder con `Status: Running`.*
2. **Comprobar en el navegador:**
   Abre [**http://127.0.0.1:8989/**](http://127.0.0.1:8989/).  
   El panel permite consultar licencia y periféricos. Verificar el servicio y realizar pruebas físicas desde el POS; abrir el panel no garantiza licencia PRO, impresión ni pesada.

---

#### Comandos Útiles de Mantenimiento en Windows

| Acción | Comando en PowerShell (como Administrador) |
| :--- | :--- |
| **Instalar servicio automáticamente** | `powershell -ExecutionPolicy Bypass -File .\scripts\install_windows_service.ps1` |
| **Desinstalar servicio automáticamente** | `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_windows_service.ps1` |
| **Menú de Salud y Gestión POS-80 (1 clic)** | Doble clic en `.\scripts\printer_health.bat` *(auto-eleva a Administrador)* |
| **Diagnosticar colas POS-80 (CLI)** | `powershell -ExecutionPolicy Bypass -File .\scripts\printer_health.ps1` |
| **Consolidar duplicados POS-80 y predeterminada** | `powershell -ExecutionPolicy Bypass -File .\scripts\printer_health.ps1 -Repair` |
| **Limpieza profunda para reinstalar driver** | `powershell -ExecutionPolicy Bypass -File .\scripts\printer_health.ps1 -CleanInstall` |
| **Página de prueba en POS-80** | `powershell -ExecutionPolicy Bypass -File .\scripts\printer_health.ps1 -TestPrint` |
| **Habilitar acceso SSH para soporte remoto** | Ver [§3.5 Habilitación de OpenSSH Server en Windows](#35-habilitación-de-openssh-server-en-windows-para-soporte-y-diagnóstico-remoto) |
| **Reiniciar servicio** *(tras cambiar config.toml o license.key)* | `Restart-Service OmniBridgePos` |
| **Detener servicio** | `Stop-Service OmniBridgePos` |
| **Iniciar servicio** | `Start-Service OmniBridgePos` |
| **Consultar estado actual** | `Get-Service OmniBridgePos` |
| **Desinstalar manualmente con NSSM** | `C:\PosAgent\tools\nssm.exe remove OmniBridgePos confirm` |

---

#### Método B: Compilación desde Código Fuente (Solo para Desarrolladores)

Si estás modificando el código fuente en Windows:
```powershell
cd C:\pos-peripherals-agent
cargo build --locked --release
New-Item -ItemType Directory -Path "C:\PosAgent" -Force
Copy-Item "target\release\pos-peripherals-agent.exe" "C:\PosAgent\pos-peripherals-agent.exe"
Copy-Item "config.example.toml" "C:\PosAgent\config.toml"
Copy-Item -Recurse "installer\tools" "C:\PosAgent\tools"
```
Luego procede con el **Paso 5** del Método A para registrar el servicio con NSSM.

---

### 3.2 PRODUCCIÓN EN LINUX (Servidores / Terminales Ubuntu POS)

Para estaciones de facturación y servidores corriendo Ubuntu, Debian, CentOS o RHEL:

#### Método Automatizado (Recomendado)
Ejecuta el script instalador con privilegios de superusuario desde la carpeta del paquete o repositorio:

```bash
# 1. Instalar y habilitar servicio systemd permanente
sudo bash scripts/install_linux_service.sh

# 2. Verificar estado
sudo systemctl status omnibridge
```

*El script usa `/opt/omnibridge` y `/etc/systemd/system/omnibridge.service`. Conserva la cuenta root y el grupo `dialout`; exige que el grupo exista antes de modificar el servicio. Copia configuración inicial solo si falta y verifica gestor + HTTP antes de anunciar éxito.*

#### Comandos de Mantenimiento en Linux:
| Acción | Comando |
| :--- | :--- |
| **Reiniciar servicio** | `sudo systemctl restart omnibridge` |
| **Detener servicio** | `sudo systemctl stop omnibridge` |
| **Ver registros en vivo** | `sudo journalctl -u omnibridge -f` |
| **Desinstalar servicio** | `sudo bash scripts/uninstall_linux_service.sh` |

---

### 3.3 PRODUCCIÓN EN MACOS (Estaciones de Prueba / POS macOS)

Para terminales de punto de venta corriendo macOS:

#### Método Automatizado (Recomendado)
Ejecuta el script instalador para registrar el demonio permanente en `launchd`:

```bash
# 1. Instalar demonio permanente launchd
sudo bash scripts/install_macos_service.sh

# 2. Verificar en el navegador
open http://127.0.0.1:8989/
```

*El script usa `/usr/local/bin/pos-peripherals-agent`, `/Library/Application Support/OmniBridgePOS` y `/Library/LaunchDaemons/com.omnibridge.pos.plist`. Conserva la cuenta del LaunchDaemon y registra con `launchctl bootstrap`. No elimina la cuarentena de Gatekeeper.*

#### Comandos de Mantenimiento en macOS:
| Acción | Comando |
| :--- | :--- |
| **Reiniciar servicio** | `sudo launchctl kickstart -k system/com.omnibridge.pos` |
| **Ver registros de salida** | `tail -f /Library/Logs/OmniBridgePOS/agent.log` |
| **Desinstalar servicio** | `sudo bash scripts/uninstall_macos_service.sh` |

---

### 3.4 Actualización controlada y diagnóstico sin periféricos

Descargar y verificar el paquete completo (checksum y firma cuando exista) en
una carpeta **separada del destino instalado**. No descomprimir sobre un servicio
en ejecución: hacerlo reemplaza archivos antes de que el instalador pueda
detenerlo o respaldarlo. Los scripts toman el paquete junto a su propia carpeta,
no un directorio de trabajo arbitrario.

Ejecutar el instalador de la plataforma desde ese paquete:

```sh
# Linux: instalación o actualización; puerto esperado opcional, por defecto 8989
sudo bash scripts/install_linux_service.sh 8989
# macOS: instalación o actualización
sudo bash scripts/install_macos_service.sh 8989
```

```powershell
# PowerShell como Administrador, conservando el directorio ya instalado
.\scripts\install_windows_service.ps1 -InstallDir 'C:\PosAgent' -Port 8989
```

El puerto debe coincidir con la configuración guardada. El argumento no modifica
esa configuración; solo selecciona la comprobación HTTP. El asistente Inno Setup
acepta `/AGENTPORT=8989`, validado como entero de 1 a 65535 antes de detener el
servicio. Un servicio Windows ya registrado en otro directorio se rechaza:
esta actualización no migra rutas.

- Los scripts respaldan binario/unidad Unix o binario/herramientas Windows,
  detienen el servicio antes del reemplazo y conservan configuración y licencia
  existentes. Nunca copian ni sustituyen la clave maestra local.
- Los archivos iniciales se crean solo si faltan. Los respaldos se retienen en
  `install-backup.*` (Unix) o `install-backup-*` (Windows), con permisos privados;
  no se borran automáticamente.
- Unix verifica hasta diez veces gestor + `/api/v1/health/live`, con timeout
  HTTP de dos segundos e intervalos de un segundo. Windows usa hasta diez
  comprobaciones del mismo endpoint y del servicio.
- Si falla el reemplazo, los scripts intentan restaurar sus archivos respaldados
  y reiniciar la instalación anterior. **Siempre devuelven error**, aunque la
  recuperación funcione. Si no consiguen detener el nuevo servicio, no restauran
  un binario que podría seguir en ejecución; se requiere intervención técnica.
- Si falla una primera instalación sin binario anterior, intentan detener el
  servicio nuevo y retienen archivos para diagnóstico; no inventan un rollback.
- El asistente gráfico detiene el servicio antes de copiar y conserva una copia
  `.previous-*` del binario. Su recuperación es limitada a ese binario: ante
  fallo, revisar herramientas/registro y recuperar manualmente antes de reabrir
  la caja. No equivale al respaldo de los scripts.
- Las cuentas y rutas actuales no cambian. Esto no certifica mínimo privilegio
  ni corrige automáticamente los permisos heredados de datos Windows.

Diagnóstico de **solo lectura**, sin impresión, pesada, pulso de gaveta ni purga:

```sh
sudo bash scripts/diagnose_service.sh 8989
```

```powershell
.\scripts\diagnose_service.ps1 -Port 8989
```

Salida 0 requiere gestor activo y respuesta HTTP válida; salida distinta de cero
indica fallo o estado inaccesible. No muestra secretos de configuración. Liveness
no verifica periféricos, autenticación, configuración cargada ni SHA del proceso;
otro proceso en el puerto puede responder. Contrastar el PID/ruta del gestor y
el checksum instalado, revisar logs sin compartir credenciales y repetir las
pruebas físicas de impresión/pesada/gaveta desde el POS antes de aceptar la caja.

Para soporte asistido sin escribir comandos en consola, hacer doble clic en:

```cmd
.\scripts\printer_health.bat
```

Este lanzador solicita elevación UAC de Administrador automáticamente y presenta
un menú interactivo de 5 opciones: diagnosticar colas y puertos USB, reparar y
unificar colas a una sola POS-80 predeterminada, realizar limpieza profunda
para reinstalar driver, enviar página de prueba y salir.

Para diagnosticar las colas `POS-80`, sus variantes `Copy`, `Copia` o
`copy of` vía PowerShell CLI, ejecutar primero sin cambios:

```powershell
.\scripts\printer_health.ps1
```

La salida 0 confirma una sola cola utilizable llamada `POS-80`; la salida 2
indica que requiere corrección. Para reparar, abrir PowerShell como
Administrador y ejecutar:

```powershell
.\scripts\printer_health.ps1 -Repair
```

La reparación solicita confirmación, detiene temporalmente `OmniBridgePos` si
está activo, cancela únicamente los trabajos de esa familia, reinicia el
Spooler cuando existe `PendingDeletion`, desactiva el modo de administración
automática de impresora predeterminada por Windows (`LegacyDefaultPrinterMode`),
fija `POS-80` como predeterminada, conserva el controlador, elimina las colas
hermanas y normaliza el nombre a `POS-80`. Para omitir la confirmación en
soporte desatendido se puede agregar `-Confirm:$false`; para hacerla
predeterminada explícitamente, `-SetDefault`.

Para casos donde el controlador o la cola quedaron corruptos y se requiere
dejar el sistema 100% limpio para reinstalar desde `C:\POS Printer Driver V7.17`:

```powershell
.\scripts\printer_health.ps1 -CleanInstall
```

Este procedimiento detiene el Spooler, elimina los archivos temporales retenidos
en `C:\Windows\System32\spool\PRINTERS`, reinicia el Spooler, elimina todas las
colas `POS-80` / `POS-58` corruptas, localiza el instalador ejecutable en
`C:\POS Printer Driver V7.17` y ofrece lanzarlo con las instrucciones de selección
de puerto USB y fijación predeterminada.

Para verificar la comunicación física con la ticketera enviando una página de prueba:

```powershell
.\scripts\printer_health.ps1 -TestPrint
```

Si hay varias colas igualmente utilizables, el script se detiene para evitar
eliminar una impresora física incorrecta. En ese caso se debe identificar la
que imprime y repetir con su nombre exacto, por ejemplo:

```powershell
.\scripts\printer_health.ps1 -Repair -KeepPrinterName "POS-80 (Copy 2)"
```

Si la única cola estaba en `PendingDeletion` y Windows la elimina sin volver a
crearla, conectar la impresora a su puerto USB definitivo, esperar la
instalación Plug and Play y repetir. El script no elimina paquetes de drivers,
no purga trabajos de otras impresoras y no puede certificar salida física en
papel; al finalizar se debe imprimir una página de prueba.

Las pruebas aisladas de instaladores usan gestores y HTTP falsos. La instalación
nativa Linux/Windows/macOS y ejecución PowerShell siguen requiriendo validación
en entornos dedicados antes de distribución comercial. El CI incorpora parser
PowerShell y compilación Inno Setup; esa compilación no se ejecutó en el macOS
de desarrollo y debe aprobar antes de distribuir el instalador gráfico.

---

### 3.5 Habilitación de OpenSSH Server en Windows para Soporte y Diagnóstico Remoto

En estaciones de caja de tienda donde los ingenieros de soporte o administradores de sistemas necesitan diagnosticar periféricos, inspeccionar logs (`agent.log`), revisar el Spooler o ejecutar scripts de mantenimiento (`printer_health.ps1`, `diagnose_scale.ps1`, `diagnose_service.ps1`) sin interrumpir la interfaz gráfica del cajero ni depender de herramientas de acceso visual de terceros, Windows 10 y Windows 11 incorporan nativamente la capacidad **OpenSSH Server (`sshd`)**.

#### 1. Activación Automatizada en Windows (PowerShell como Administrador)

Para instalar la capacidad, configurar el servicio en inicio automático, abrir la regla en Windows Defender Firewall y autorizar una llave pública de soporte SSH en una sola instrucción, ejecutar en la máquina Windows:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service sshd -StartupType Automatic; New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
```

#### 2. Configuración de Autenticación por Llave Pública (Recomendado sin Contraseña)

Para permitir acceso desatendido seguro mediante par de claves criptográficas (`Ed25519` o `RSA 4096`), registrar la clave pública del operador/servidor de soporte en la estación de caja:

```powershell
# Para usuarios estándar:
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
Set-Content -Path "$HOME\.ssh\authorized_keys" -Value "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... operador@soporte" -Force

# Para usuarios pertenecientes al grupo Administradores (requisito estricto de OpenSSH en Windows):
New-Item -ItemType Directory -Force -Path "C:\ProgramData\ssh" | Out-Null
Set-Content -Path "C:\ProgramData\ssh\administrators_authorized_keys" -Value "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... operador@soporte" -Force
icacls.exe "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
```

> [!IMPORTANT]
> En Windows, las cuentas con privilegios de Administrador leen exclusivamente el archivo `C:\ProgramData\ssh\administrators_authorized_keys`. Dicho archivo **debe** tener las listas de control de acceso (ACL) restringidas a `Administrators` y `SYSTEM` mediante `icacls`, o el servidor SSH rechazará la conexión por razones de seguridad.

#### 3. Verificación del Servicio en la Estación

```powershell
# Comprobar estado del servicio
Get-Service sshd

# Comprobar puerto de escucha
netstat -ano | findstr :22
```

#### 4. Operación Remota desde la Estación de Soporte (Linux / macOS)

Una vez habilitado, el técnico puede interactuar con la caja remota directamente:

```bash
# Sesión interactiva en PowerShell remoto:
ssh usuario@192.168.1.XXX

# Diagnóstico de salud de impresora POS-80 remoto:
ssh usuario@192.168.1.XXX "powershell -ExecutionPolicy Bypass -File C:\PosAgent\scripts\printer_health.ps1"

# Reparación y unificación automática de POS-80 remota:
ssh usuario@192.168.1.XXX "powershell -ExecutionPolicy Bypass -File C:\PosAgent\scripts\printer_health.ps1 -Repair -Confirm:\$false"

# Comprobación de liveness del servicio OmniBridge:
ssh usuario@192.168.1.XXX "powershell -ExecutionPolicy Bypass -File C:\PosAgent\scripts\diagnose_service.ps1 -Port 8989"
```

#### 5. Consideraciones de Seguridad en Redes de Tienda
- Restringir la regla de firewall `OpenSSH-Server-In-TCP` a la subred de gestión local o interfaz VPN interna, evitando exposición a subredes públicas o de clientes.
- Desactivar autenticación por contraseña si se utiliza exclusivamente autenticación por llave pública editando `C:\ProgramData\ssh\sshd_config` (`PasswordAuthentication no`).

---

## 4. Banco de Pruebas de Verificación (Smoke Test)

Una vez iniciado el servicio, prueba los endpoints desde la terminal o Postman:

### 1. Diagnóstico de Salud
```bash
curl http://127.0.0.1:8989/health
```
*Respuesta esperada:*
```json
{
  "status": "ok",
  "service": "pos-peripherals-agent",
  "version": "1.0.0",
  "scale_status": "connected",
  "printer_status": "ready",
  "scale_port": "COM3",
  "default_printer": "POS-80",
  "simulation_mode": false
}
```

### 2. Catálogo de Impresoras Detectadas
```bash
curl http://127.0.0.1:8989/printers
```

### 3. Lectura de Peso (Báscula)
```bash
# Probar ruta estándar v1
curl http://127.0.0.1:8989/api/v1/scale/weight

# Probar alias directo
curl http://127.0.0.1:8989/peso
```
*Respuesta esperada:*
```json
{
  "peso": 1.450,
  "weight": 1.450,
  "peso_leido": "ST,GS,+   1.450kg",
  "puerto": "COM3",
  "is_simulated": false,
  "unit": "kg",
  "is_stable": true
}
```
  "peso": 1.455,
  "peso_leido": "01.455"
}
```

### 4. Prueba de Apertura de Gaveta de Dinero (Cash Drawer)
```bash
# Envío de pulso estándar ESC/POS al conector RJ11/RJ12 de la impresora de tickets
curl -X POST http://127.0.0.1:8989/drawer
# O mediante su alias en español
curl -X POST http://127.0.0.1:8989/gaveta
```

### 5. Prueba de Impresión Térmica de Tickets (Unificado)
```bash
# Formato 1: JSON directo con texto o secuencias ESC/POS
curl -X POST "http://127.0.0.1:8989/ticket" \
  -H "Content-Type: application/json" \
  -d '{"content": "SUPERMERCADO LA GRANJA\nTicket de Prueba\nTotal: $10.00\n"}'

# Formato 2: Descarga e impresión automática desde URL
curl -X POST "http://127.0.0.1:8989/ticket" \
  -H "Content-Type: application/json" \
  -d '{"url": "http://127.0.0.1:8989/demo-ticket.pdf"}'

# Formato 3: Enviar PDF multipart al puerto principal
curl -X POST "http://127.0.0.1:8989/print" \
  -F "file=@/ruta/a/mi_ticket.pdf" \
  -F "printer=POS-80"
```

### 6. Prueba de Impresión de Etiquetas TSPL
```bash
curl -X POST "http://127.0.0.1:8989/print-label" \
  -H "Content-Type: application/json" \
  -d '{"commands": "SIZE 60 mm,45 mm\r\nCLS\r\nTEXT 30,30,\"3\",0,1,1,\"DEMO TSPL\"\r\nPRINT 1,1\r\n"}'
```

### 7. Prueba de Forma Continua (Matriz de Punto ESC/P)
```bash
curl -X POST "http://127.0.0.1:8989/print-matrix" \
  -H "Content-Type: application/json" \
  -d '{"content": "PRUEBA FACTURA MATRIZ DE PUNTO\n", "form_feed": true}'
```

### 8. Prueba de Documentos Láser / Oficina (A4 / Carta)
```bash
curl -X POST "http://127.0.0.1:8989/api/v1/print/document" \
  -H "Content-Type: application/json" \
  -d '{"text_content": "REPORTE GERENCIAL EN HOJA COMPLETA A4\n"}'
```

### 9. Prueba de Saneamiento del Spooler de Windows
```bash
curl -X POST "http://127.0.0.1:8989/printers/cleanup"
```

---

## 5. Matriz de Solución de Problemas (Troubleshooting)

| Síntoma | Causa Frecuente | Solución |
| :--- | :--- | :--- |
| `macOS: "Apple could not verify pos-peripherals-agent is free of malware"` | Descarga web con atributo de cuarentena Gatekeeper (`com.apple.quarantine`). | Verificar procedencia, checksum y firma; detenerse y revisar autorización con el administrador en *Ajustes del Sistema > Privacidad y Seguridad*. No borrar atributos recursivamente. |
| `macOS/Linux: zsh: permission denied: ./run_macos_linux.sh` | El archivo descargado carece de permisos de ejecución `+x`. | Ejecutar `chmod +x pos-peripherals-agent scripts/run_macos_linux.sh`. |
| `cp: config.example.toml: No such file or directory` | Se ejecutó un script antiguo desde la subcarpeta `scripts/`. | El script actual detecta la raíz automáticamente. Actualizar o ejecutar desde la raíz del paquete. |
| `Error de puerto serial: Access is denied` (Windows) | El puerto COM está abierto por otra aplicación (ej. un emulador o terminal serial abierta). | Cerrar cualquier software o terminal que tenga tomado el puerto COM. |
| `Error de puerto serial: No such file or directory` | El adaptador USB se desconectó o cambió de número de puerto (ej. pasó de COM3 a COM4). | Revisar el Administrador de Dispositivos y actualizar `config.toml` (o usar `port = "auto"`). |
| `SumatraPDF no encontrado` | La ruta en `config.toml` no coincide con la ubicación del ejecutable. | Asegurar que `SumatraPDF.exe` esté presente en la subcarpeta `tools\` junto al binario. |
| El navegador da error de CORS desde el ERP Cloud | El origen no está en la allowlist explícita. | Agregar el origen HTTPS exacto del ERP a `cors_origins`; no usar `*`. |
| El puerto 8989 ya está en uso | Quedó corriendo una instancia previa del servicio o el proceso está colgado. | En Windows: `netstat -ano \| findstr :8989` y terminar el PID con `taskkill /PID <pid> /F`. En Linux/macOS: `lsof -i :8989` y `kill -9 <PID>`. |
| Peticiones devuelven 401 Unauthorized | Se configuró `api_key` en `config.toml` pero el cliente no envía la cabecera adecuada. | Enviar `Authorization: Bearer <clave>` o `x-api-key: <clave>` en cada petición HTTP. |

---

## 6. Seguridad de Red y Configuración de Firewall

Para proteger las operaciones de hardware y evitar accesos no autorizados a la gaveta de dinero o impresoras de la tienda:

| Modo | `host` | `api_key` | Firewall | Uso |
| :--- | :--- | :--- | :--- | :--- |
| **A — Estándar de instalación** | `127.0.0.1` | vacía | Sin reglas entrantes | Una caja: ERP/navegador y periféricos en el mismo PC |
| **B — Avanzado (excepción)** | `0.0.0.0` o IP LAN | obligatoria (`openssl rand -hex 32`) | Regla restringida a la subred | Una caja comparte periféricos con otros equipos, en red cableada confiable |

### 6.1 Modo A: Loopback Exclusivo (Estándar de Instalación)
El instalador, los paquetes y `config.example.toml` dejan el agente enlazado en `127.0.0.1:8989`, sin `api_key` y sin abrir puertos en el Firewall. Únicamente aplicaciones corriendo en la misma caja pueden comunicarse con los periféricos. Un ERP web abierto en esa caja llama a `http://127.0.0.1:8989` y su origen HTTPS exacto debe figurar en `cors_origins`. Al iniciar, el log muestra `Modo de red: A - Loopback (estándar)`.

### 6.2 Modo B: Autenticación por API Key (Red Local)
Solo cuando se aprueba compartir el agente en la LAN. En `config.toml`:
```toml
[server]
host = "0.0.0.0"
api_key = "REEMPLAZAR_POR_UN_SECRETO_ALEATORIO_LARGO"
```
Si el host no es loopback y falta `api_key`, las rutas protegidas responden `401` (falla cerrado) y el log emite una advertencia de seguridad.

**Administración independiente:** panel, configuración, licencias, purga/página
de prueba y enrolamiento solo funcionan con bind loopback y `server.admin_key`
aleatoria de 32–256 bytes, distinta de `api_key`. Sin ella quedan bloqueados.
Configure la clave manualmente en `[server]`, reinicie y acceda a
`http://127.0.0.1:8989/admin/login`. La cookie HttpOnly/SameSite=Strict dura
30 minutos; cierre de sesión y reinicio la revocan. Login JSON limitado a 1 KiB;
5 intentos/minuto y hasta 16 sesiones globales por proceso. Las escrituras con
cookie exigen Origin local del puerto principal. Los clientes administrativos
nativos pueden enviar `Authorization: Bearer <admin_key>` sin Origin.
El POS externo y su clave operativa no obtienen permisos administrativos.

No poner claves en URLs, ejemplos publicados ni bundles JavaScript. Restringir
permisos del archivo y sus respaldos/temporales al usuario del servicio
(0600 Unix / ACL Windows). Rotar manualmente y reiniciar. Restringir también
el directorio en Windows: los reemplazos heredan su ACL.
El guardado usa temporales privados, sincronización y reemplazo atómico; los
fallos de respaldo se devuelven como errores, sin sobrescribir la configuración.
El panel cubre los 35 campos no secretos de servidor, bascula, impresion y
biometria. El formulario lee la configuracion guardada; las tarjetas conservan
la activa hasta reiniciar. La API diferencia `config` activa / `saved_config`
en GET y `config` guardada / `active_config` en POST, con `restart_required`.
Las escrituras se serializan dentro del proceso y usan el destino elegido al
iniciar (una plantilla genera config.toml en su mismo directorio). No escribir
con varios agentes o editores simultaneamente. No existe control de revisiones.
Un archivo ilegible, invalido o con campos desconocidos bloquea lectura/guardado,
sin fallback que borre datos; el respaldo anterior debe revisarse para recuperar
manualmente y reiniciar. Un destino inexistente parte de la configuracion activa.
Guardar no conserva comentarios TOML ni activa cambios en caliente.
Cambiar host/puertos puede mover o bloquear la consola; un bind de red requiere
api_key manual y firewall antes de reiniciar. El panel confirma cambios de red,
simulacion, biometria y habilitacion de descargas privadas.
Los overrides DTR/RTS y VID/PID se eliminan con null; la IP del reloj ausente se
persiste como cadena vacia. `sumatra_args` es legacy persistida, no una plantilla
ejecutable: el motor mantiene sus argumentos internos seguros. Consultar OpenAPI
para campos y limites; configuracion no implica homologacion de hardware.
No publicar loopback mediante túneles o proxies: el control depende del bind, no de identidad del peer.
Esta consola HTTP local no utiliza cookie Secure ni implementa cuentas por
persona/RBAC granular. Ver README para límites de confianza frente a procesos locales.
Los clientes nativos autorizados deberán incluir la cabecera:
```http
Authorization: Bearer <secreto_configurado>
```
o alternativamente:
```http
x-api-key: <secreto_configurado>
```
No incruste una API key compartida en el bundle JavaScript del POS: cualquier usuario puede extraerla. Para integración desde navegador, mantenga el agente en loopback y configure el origen HTTPS exacto en `cors_origins`. Para acceso desde otros equipos, use un cliente o proxy nativo confiable que mantenga el secreto fuera del navegador. El tráfico es HTTP sin cifrar: use Modo B solo en red cableada y confiable.

### 6.3 Reglas de Firewall (solo Modo B)
Si una caja comparte una impresora o báscula con otros terminales de la tienda:

- **Windows Defender Firewall (PowerShell como Administrador):**
  ```powershell
  # Permitir puerto 8989 únicamente desde la subred interna autorizada (ej. 192.168.1.0/24)
  netsh advfirewall firewall add rule name="OmniBridge POS Local Port 8989" dir=in action=allow protocol=TCP localport=8989 remoteip=192.168.1.0/24
  ```

- **Linux (UFW):**
  ```bash
  # Permitir únicamente desde la subred local de ventas
  sudo ufw allow from 192.168.1.0/24 to any port 8989 proto tcp comment 'OmniBridge POS'
  ```

- **macOS (`pf`):**
  Agregar al archivo `/etc/pf.conf`:
  ```text
  pass in proto tcp from 192.168.1.0/24 to any port 8989
  ```

---

### 6.4 Generación y Configuración de `admin_key` en los 3 Sistemas Operativos

El acceso administrativo local (`/`, `/admin`, configuración de hardware, purga de colas, licencias y enrolamiento biométrico) requiere que `server.admin_key` en `config.toml` contenga una clave secreta aleatoria de **32 a 256 bytes**, distinta de la `api_key` operativa. Sin esta clave configurada, la interfaz de administración web permanece bloqueada para impedir manipulaciones no autorizadas o accidentales en la estación de caja.

A continuación se detallan las instrucciones y comandos nativos para generar e inyectar esta clave en los tres sistemas operativos soportados:

#### 1. Windows (PowerShell como Administrador)

En la estación de caja Windows, ejecutar en PowerShell:

```powershell
# 1. Generar clave criptográficamente segura de 32 caracteres
$adminKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# 2. Inyectar automáticamente en config.toml
$configPath = "C:\PosAgent\config.toml"
if (Test-Path $configPath) {
    (Get-Content $configPath) -replace 'admin_key = ""', "admin_key = `"$adminKey`"" | Set-Content $configPath
    Restart-Service OmniBridgePos
    Write-Host ">>> admin_key configurada con éxito: $adminKey" -ForegroundColor Green
    Write-Host ">>> Inicie sesión en http://127.0.0.1:8989/ con esa clave." -ForegroundColor Cyan
} else {
    Write-Warning "No se encontró $configPath. Ajuste la ruta según su instalación."
}
```

#### 2. Linux (Ubuntu, Debian, CentOS, RHEL)

En servidores o terminales Linux POS:

```bash
# 1. Localizar archivo de configuración
CONFIG_FILE="/etc/omnibridge/config.toml"
[ ! -f "$CONFIG_FILE" ] && [ -f "./config.toml" ] && CONFIG_FILE="./config.toml"

# 2. Generar clave segura de 32 caracteres con OpenSSL e inyectar
ADMIN_KEY=$(openssl rand -hex 16)
sudo sed -i "s/admin_key = \"\"/admin_key = \"$ADMIN_KEY\"/" "$CONFIG_FILE"

# 3. Reiniciar el servicio
if systemctl is-active --quiet omnibridge 2>/dev/null; then
    sudo systemctl restart omnibridge
fi

echo ">>> admin_key configurada con éxito: $ADMIN_KEY"
echo ">>> Inicie sesión en http://127.0.0.1:8989/ con esa clave."
```

#### 3. macOS (Apple Silicon y Mac Intel)

En terminales de prueba o puntos de venta en macOS:

```zsh
# 1. Localizar archivo de configuración según modo de ejecución
if [ -f "/Library/Application Support/OmniBridgePOS/config.toml" ]; then
    CONFIG_FILE="/Library/Application Support/OmniBridgePOS/config.toml"
else
    CONFIG_FILE="./config.toml"
fi

# 2. Generar clave de 32 caracteres con OpenSSL e inyectar
ADMIN_KEY=$(openssl rand -hex 16)
sed -i '' "s/admin_key = \"\"/admin_key = \"$ADMIN_KEY\"/" "$CONFIG_FILE"

# 3. Reiniciar servicio launchd si está instalado
if sudo launchctl list 2>/dev/null | grep -q "com.omnibridge.pos"; then
    sudo launchctl kickstart -k system/com.omnibridge.pos
fi

echo ">>> admin_key configurada con éxito: $ADMIN_KEY"
echo ">>> Inicie sesión en http://127.0.0.1:8989/ con esa clave."
```

> [!TIP]
> Una vez iniciada sesión en `http://127.0.0.1:8989/`, la cookie de sesión (`HttpOnly`, `SameSite=Strict`) durará **30 minutos**. Al presionar "Cerrar sesión" o reiniciar el agente, la sesión se revoca inmediatamente. Los clientes administrativos nativos pueden enviar alternativamente la cabecera HTTP `Authorization: Bearer <admin_key>`.
