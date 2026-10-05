# Guía de Implementación e Instalación: pos-peripherals-agent

Esta guía detalla los pasos para instalar, compilar y ejecutar **`pos-peripherals-agent`** tanto en entornos de **Desarrollo** como de **Producción**, desglosada por sistema operativo (**Windows**, **Linux** y **macOS**).

---

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
   xattr -cr .
   ```
   > **Nota sobre macOS Gatekeeper:** Si macOS bloquea el binario indicando *"Apple could not verify pos-peripherals-agent is free of malware"*, ejecutar `xattr -cr .` (o `xattr -d com.apple.quarantine pos-peripherals-agent`) dentro de la carpeta desbloquea la ejecución nativa al instante. También es posible autorizarlo en *Ajustes del Sistema > Privacidad y Seguridad > Abrir de todos modos*.
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
   Verás el panel con tu licencia comercial PRO activa, la báscula y las impresoras listas.

---

#### Comandos Útiles de Mantenimiento en Windows

| Acción | Comando en PowerShell (como Administrador) |
| :--- | :--- |
| **Instalar servicio automáticamente** | `powershell -ExecutionPolicy Bypass -File .\scripts\install_windows_service.ps1` |
| **Desinstalar servicio automáticamente** | `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_windows_service.ps1` |
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

*El script crea `/opt/omnibridge`, copia el binario, instala la configuración, otorga permisos para puertos seriales (`dialout`), registra `/etc/systemd/system/omnibridge.service` y arranca el servicio.*

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

*El script instala el binario en `/usr/local/bin/pos-peripherals-agent`, desactiva atributos de cuarentena Gatekeeper (`xattr -cr`), configura `/Library/Application Support/OmniBridgePOS` y carga el demonio `/Library/LaunchDaemons/com.omnibridge.pos.plist`.*

#### Comandos de Mantenimiento en macOS:
| Acción | Comando |
| :--- | :--- |
| **Reiniciar servicio** | `sudo launchctl unload -w /Library/LaunchDaemons/com.omnibridge.pos.plist && sudo launchctl load -w /Library/LaunchDaemons/com.omnibridge.pos.plist` |
| **Ver registros de salida** | `tail -f /Library/Logs/OmniBridgePOS/agent.log` |
| **Desinstalar servicio** | `sudo bash scripts/uninstall_macos_service.sh` |

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
| `macOS: "Apple could not verify pos-peripherals-agent is free of malware"` | Descarga web con atributo de cuarentena Gatekeeper (`com.apple.quarantine`). | Ejecutar `xattr -cr .` o `xattr -d com.apple.quarantine pos-peripherals-agent` en la carpeta, o autorizar en *Ajustes del Sistema > Privacidad y Seguridad*. |
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


