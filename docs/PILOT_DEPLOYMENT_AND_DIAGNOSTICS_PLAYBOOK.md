# Playbook de Despliegue en Pilotos y Diagnóstico en Sitio
## OmniBridge POS™ — Guía Operativa para Técnicos de Soporte y Campo

- **Objetivo:** Guiar instalación y diagnóstico en estación, registrando versión, plataforma, periféricos y resultados. El tiempo de resolución y compatibilidad dependen del entorno; esta guía no los garantiza.
- **Audiencia:** Técnicos de soporte en sitio, integradores de sistemas POS y administradores de tienda.

---

## 1. Preparación Previa al Despliegue en Tienda

Antes de acudir a la sucursal o conectarse remotamente a la caja:
1. Obtener el artefacto publicado para la versión, sistema operativo y arquitectura requeridos. Verificar `SHA256SUMS.txt`; no asumir nombres de artefactos de una release distinta.
2. Registrar los equipos exactos: fabricante/modelo/revisión/firmware de báscula, impresora y gaveta; conexión; driver; baud rate/protocolo indicados por manual.
3. Anotar la configuración del agente: host, puerto, estado de listeners legacy, CORS y simulación. No incluir API keys en capturas o reportes.
4. Confirmar si la estación requiere una prueba simulada, una prueba HIL con hardware real o ambas; no usar una para sustituir la otra.

---

## 2. Instalación en Windows (Estaciones de Caja POS)

### 2.1. Instalación Mediante el Asistente Gráfico
1. Ejecutar como Administrador `OmniBridgePOS_Setup_v1.0.0.exe`.
2. Antes de ejecutar el instalador, verificar su firma y checksum con el canal de publicación aprobado. Si SmartScreen muestra una advertencia o el artefacto no está firmado/verificado, detenerse y escalarlo; no omitir el control por defecto.
3. Aceptar el acuerdo de licencia comercial EULA.
4. Mantener la ruta de instalación predeterminada (`C:\Program Files\OmniBridgePOS` o `C:\Archivos de programa\OmniBridgePOS`).
5. El instalador automáticamente:
   - Registra el servicio permanente de Windows mediante NSSM (`OmniBridgePos`).
   - Configura el servicio para arranque automático (`SERVICE_AUTO_START`).
   - Instala en **Modo A** (estándar): `host = "127.0.0.1"`, sin `api_key` y **sin reglas de Firewall entrantes**. Al desinstalar elimina reglas `OmniBridge POS 8989/8002/8003` que hubieran creado instaladores anteriores.
   - No exponer el agente a la LAN (Modo B) sin configurar API key, revisar CORS/orígenes y crear una regla de Firewall restringida a la subred; una regla de Firewall no reemplaza esos controles.
   - Inicia el servicio inmediatamente y abre el Panel de Control en el navegador (`http://localhost:8989/`).

### 2.2. Instalación Desatendida (Masiva por Script / Terminal)
Para instalar en múltiples cajas de forma silenciosa sin intervención visual:
```cmd
OmniBridgePOS_Setup_v1.0.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

---

## 3. Verificación de Servicio y Periféricos

Realizar primero comprobaciones de servicio. Registrar por separado cualquier prueba física y su resultado.

### Paso 1: Abrir el Dashboard Local en el Navegador
Acceder a: `http://localhost:8989/`
- Debe responder el dashboard de la instancia instalada. Su disponibilidad no demuestra que haya periféricos conectados ni homologados.

### Paso 2: Verificar Estado del Microservicio (`/health`)
Ejecutar en PowerShell o navegador:
```powershell
curl.exe -s http://127.0.0.1:8989/health
```
- `"status": "ok"` indica que el endpoint respondió; no certifica funcionamiento del hardware.
- `scale_status` puede indicar `connected`, `disconnected` o `simulated`; confirmar el payload completo y la configuración.
- `printer_status` es un dato de diagnóstico/catálogo; no demuestra que un trabajo se haya impreso correctamente.

### Paso 3: Prueba HIL de báscula
Solo con la báscula física identificada y su protocolo/baud rate documentados, ejecutar una lectura sin parámetros de simulación:
```powershell
curl.exe -s http://127.0.0.1:8989/peso
```
- Registrar respuesta, `is_simulated`, unidad, puerto y latencia observada. No afirmar exactitud metrológica sin una masa de referencia calibrada; `is_stable` permanece `false` mientras no exista protocolo de estabilidad validado.

**Evidencia funcional reportada (2026-10-04):** En Windows, el usuario probó una báscula física en varios puertos COM y al desconectarla/conectarla. La petición web reconoció la báscula independientemente del COM activo. No se proporcionaron modelo/revisión, versión de Windows, protocolo/baud rate, código HTTP/payload ni latencia; registrar esos datos en una repetición para completar la evidencia. Este resultado es preliminar y no constituye homologación por modelo ni validación multiplataforma.

### Paso 4: Probar Apertura de Gaveta de Dinero
```powershell
curl.exe -s -X POST http://127.0.0.1:8989/drawer
```
- Confirmar físicamente el resultado y registrar modelo de impresora/gaveta y configuración. La respuesta HTTP por sí sola no confirma apertura.

### Prueba simulada de API (no es HIL)
Para probar el flujo de software sin afirmar compatibilidad física, activar `simulation_mode = true` únicamente en un entorno de prueba. La báscula acepta `?simulate=true`; la gaveta puede simularse con `POST /drawer?simulate=true`. Verificar `is_simulated: true` y volver a deshabilitar la simulación antes de producción.

---

## 4. Árbol de Decisión y Contingencia ante Incidencias Comunes

### Incidencia A: "La báscula no lee el peso o retorna HTTP 503"
1. **Verificar cable USB físico:** Confirmar que el cable USB o adaptador RS-232 esté firmemente conectado.
2. **Revisar el Administrador de Dispositivos de Windows:**
   - Abrir `devmgmt.msc` ➔ Sección *"Puertos (COM y LPT)"*.
   - Si aparece un dispositivo con triángulo amarillo (falta de driver CH340 o Prolific), instalar el driver del fabricante del adaptador.
3. **Auto-detección (`port = "auto"`):**
   - OmniBridge POS escanea los puertos COM automáticamente. Si el puerto cambió de `COM3` a `COM4`, el agente se enlaza solo en el siguiente ciclo.
4. **Prueba simulada de software:**
   - Solo con `simulation_mode = true`, probar `http://localhost:8989/peso?simulate=true`. Esta respuesta no valida báscula, driver, protocolo ni latencia física. En modo producción, parámetros de simulación/override se rechazan con HTTP 403.

---

### Incidencia B: "La impresora térmica no imprime o los tickets se encolan"
1. **Verificar papel y luz de estado:** Confirmar que la tapa esté cerrada, haya papel térmico y el LED no esté en rojo (error de papel).
2. **Purgar la cola de impresión bloqueada:**
   - Si un documento atascó el spooler de Windows, ejecutar la purga automática del microservicio:
     ```powershell
     curl.exe -s -X POST http://127.0.0.1:8989/printers/cleanup
     ```
3. **Validar nombre de impresora en `config.toml`:**
   - Abrir `http://localhost:8989/printers` para ver la lista exacta de nombres reconocidos por Windows.
   - Si la impresora se llama `"Xprinter XP-80"` y en `config.toml` dice `"POS-80"`, actualizar `default_printer` en `config.toml`.

---

### Incidencia C: "El ERP Web (Cloud o Local) no puede conectar con el agente"
1. **Verificar puerto de enlace:** Asegurarse de que el ERP apunte a `http://localhost:8989` o `http://127.0.0.1:8989`.
2. **Verificar cabecera CORS:**
   - Si el ERP está en un dominio seguro, confirmar que `config.toml` incluya su origen HTTPS exacto en `cors_origins`; no usar `*`.
3. **Chrome Private Network Access (PNA):**
   - La cabecera PNA no garantiza por sí sola acceso del navegador. Configurar el origen exacto en `cors_origins` y revisar políticas PNA/autorización del navegador y del agente.

---

## 5. Recolección de Logs para Soporte Remoto

Si se requiere escalar un caso al equipo de desarrollo, los logs del agente se encuentran en:
- **Windows (Servicio):** Registrar eventos mediante `nssm` o revisar la salida de consola en modo directo ejecutando `scripts\run_windows.bat`.
- **macOS:** `/Library/Logs/OmniBridgePOS/agent.log`.
- **Linux:** `journalctl -u omnibridge -f --no-tail`.
