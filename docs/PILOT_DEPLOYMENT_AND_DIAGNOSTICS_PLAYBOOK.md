# Playbook de Despliegue en Pilotos y Diagnóstico en Sitio
## OmniBridge POS™ — Guía Operativa para Técnicos de Soporte y Campo

- **Objetivo:** Guiar instalación y diagnóstico en estación, registrando versión, plataforma, periféricos y resultados. El tiempo de resolución y compatibilidad dependen del entorno; esta guía no los garantiza.
- **Audiencia:** Técnicos de soporte en sitio, integradores de sistemas POS y administradores de tienda.

---

## Verificación del sprint sin periféricos físicos

En desarrollo sobre macOS, ejecutar desde la raíz del agente:

```sh
cargo test --offline --locked --lib routes::weight::tests
cargo test --offline --locked --test unix_raw_print_test
cargo test --offline --locked --test resilience_concurrency_test
cargo test --offline --locked --lib routes::print::resilience_tests
cargo test --offline --locked --test consumer_api_contract_test
ruby tests/openapi_contract_test.rb
node --test tests/service_installation_test.cjs
node --test ../omnibridge-pos-demo/scripts/consumer_contract.test.mjs
```

El comando Node requiere la demo hermana junto al agente; sus pruebas también
pueden ejecutarse desde la raíz de la demo con
`node --test scripts/consumer_contract.test.mjs`.

El gate OpenAPI usa Ruby/Psych/Minitest y comprueba referencias JSON Pointer,
claves YAML duplicadas y paridad de las rutas/métodos definidos en el router.
Las pruebas del consumidor verifican rechazo de JSON inválido antes de admisión,
alias de contenido y formatos válidos sin sustituir una prueba física.

El gate de instaladores usa directorios temporales y comandos de gestor/HTTP
falsos: prueba preservación de datos, parada antes de reemplazo, recuperación,
precondiciones, límite de diez consultas y diagnóstico sin operaciones físicas.
No instala servicios en el equipo ni certifica instalación nativa en ningún SO.
PowerShell e Inno Setup requieren validación en Windows; el CI incorpora parser
PowerShell y compilación Inno Setup, no la ejecución del instalador ni servicios.

Antes de actualizar, extraer el paquete fuera del destino, verificar integridad
y seguir la [guía de actualización y recuperación](DEPLOYMENT_GUIDE.md#34-actualización-controlada-y-diagnóstico-sin-periféricos).
El diagnóstico `scripts/diagnose_service.sh 8989` o
`scripts/diagnose_service.ps1 -Port 8989` solo consulta gestor y liveness pública.
No usar una respuesta HTTP exitosa como evidencia de impresión o pesada.

| Capa | Evidencia automatizada | Lo que no demuestra |
| :--- | :--- | :--- |
| Báscula | HTTP real en loopback → autenticación Bearer/CORS → rutas `/peso`, `/weight`, `/api/v1/scale/weight` → apertura con `serialport` → petición `W\r\n` → tramas fragmentadas y lecturas sucesivas, incluido cero. Pruebas existentes cubren timeout, bloqueo y trama incompleta. | Compatibilidad eléctrica, baud rate físico, 7E1, DTR/RTS, driver USB o modelo; en PTY macOS se usa baud rate 0. |
| Impresión RAW y gaveta | Handler → backend de procesos del SO → clientes CUPS de prueba aislados. Se verifican destino, argumentos RAW, bytes exactos, Form Feed explícito/por defecto/desactivado, pulsos de gaveta y ticket por HTTP real. Se comprueban aceptación, rechazo, permisos, ausencia y timeout sin falso éxito. | Spooler CUPS real, impresión en papel, impresión PDF, apertura física o Winspool. Los ejecutables de prueba no sustituyen estas validaciones. |
| Consumidor demo | Se ejecuta el ejemplo publicado de JavaScript con respuestas controladas: rutas, métodos, cuerpo, Bearer opcional, peso cero y detención ante error o simulación. | Un navegador real con PNA/políticas de contenido mixto o un POS externo. |

`is_simulated: false` en un ensayo PTY identifica el camino de producción utilizado,
no convierte el puerto virtual en evidencia de hardware físico. Las pruebas no
leen configuración privada ni envían trabajos a impresoras reales.

Antes de aceptar comercialmente la estación actualizada, repetir los pasos HIL de
esta guía desde el POS/navegador real con simulación desactivada y registrar:
commit/binario, SO, drivers, modelos, configuración no secreta, código HTTP,
payload, latencia y resultado físico. Verificar ticket PDF y RAW, etiqueta,
matriz y documento según los servicios que use el cliente; comprobar pesada con
cero y masa conocida, desconexión/reconexión y rechazo sin lecturas inventadas.
Una aceptación del spooler no garantiza salida en papel. No reenviar
automáticamente impresiones fallidas o ambiguas: pueden duplicar documentos.

La aceptación física y multiplataforma sigue pendiente cuando no hay equipos
disponibles. Si aparece una regresión, corregirla y repetir el caso exitoso y el
fallido antes de avanzar; no revertir mejoras por precaución sin evidencia.

### Saturación y recuperación del despacho

El límite compartido es de 4 workers por instancia, no una cola persistente ni un
bloqueo por impresora. Incluye impresión, gaveta, páginas de prueba, limpieza y
simulaciones; no consume el bloqueo serial de pesada. HTTP 503 por capacidad
agotada indica que **ese despacho** no se envió ni se encoló; mostrar el error al
operador. HTTP 504 es distinto: la aceptación puede ser ambigua. No reenviar
automáticamente. Un worker conserva su cupo y PDF/TXT temporal aunque expire o
se cancele la petición HTTP. El cupo se libera al terminar, fallar o entrar en
pánico; los tests verifican rechazo sin ejecución y recuperación posterior.
La preparación de archivos/descargas y controles DEMO ocurren antes de la
admisión. Este mecanismo no limita la cola del spooler ni certifica salida física.

En pesada, una lectura que agota el tiempo esperando el puerto ocupado no
inicia una operación serial tardía. Una prueba verifica ese rechazo y que la
siguiente lectura funciona al liberar el puerto; no demuestra reconexión física.

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
1. Ejecutar como Administrador el instalador de la versión y arquitectura verificadas.
2. Antes de ejecutar el instalador, verificar su firma y checksum con el canal de publicación aprobado. Si SmartScreen muestra una advertencia o el artefacto no está firmado/verificado, detenerse y escalarlo; no omitir el control por defecto.
3. Aceptar el acuerdo de licencia comercial EULA.
4. Mantener la ruta de instalación predeterminada (`C:\Program Files\OmniBridgePOS` o `C:\Archivos de programa\OmniBridgePOS`).
5. El instalador automáticamente:
   - Registra el servicio permanente de Windows mediante NSSM (`OmniBridgePos`).
   - Configura el servicio para arranque automático (`SERVICE_AUTO_START`).
   - Instala en **Modo A** (estándar): `host = "127.0.0.1"`, sin `api_key` y **sin reglas de Firewall entrantes**. Al desinstalar elimina reglas `OmniBridge POS 8989/8002/8003` que hubieran creado instaladores anteriores.
   - No exponer el agente a la LAN (Modo B) sin configurar API key, revisar CORS/orígenes y crear una regla de Firewall restringida a la subred; una regla de Firewall no reemplaza esos controles.
   - Verifica gestor + HTTP antes de anunciar instalación correcta. No sustituye las pruebas físicas. Ante error, seguir los límites de recuperación de la guía.

### 2.2. Instalación Desatendida (Masiva por Script / Terminal)
Para instalar en múltiples cajas de forma silenciosa sin intervención visual:
```cmd
OmniBridgePOS_Setup_v1.2.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /AGENTPORT=8989
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
1. **Verificar cable USB físico:** Confirmar que el cable USB o adaptador RS-232 esté firmemente conectado (preferir puertos USB traseros soldados a la placa base).
2. **Revisar el Administrador de Dispositivos de Windows:**
   - Abrir `devmgmt.msc` ➔ Sección *"Puertos (COM y LPT)"*.
   - Si aparece un dispositivo con triángulo amarillo (falta de driver CH340 o Prolific), instalar el driver del fabricante del adaptador.
   - **Alerta de Driver CH340 (WCH v3.9.2024.9):** Si el puerto arroja *"Uno de los dispositivos conectados al sistema no funciona"* (`ERROR_GEN_FAILURE`), revertir el controlador a la versión 3.5 (2019) o 3.4 (2014) en las propiedades del dispositivo en `devmgmt.msc`.
3. **Modo de Transmisión Continua de la Báscula:**
   - Si el puerto abre pero no lee peso, la báscula está en silencio (modo manual o impresora `PRN`). Configurar el cabezal en modo Continuo (`PC-POS`, `CONT` o `STREAM`) a 9600 8N1. Colocar peso sobre el plato (al menos 1 kg) para forzar la emisión de tramas continuas (`ST,GS,+   X.XXkg`).
4. **Auto-detección (`port = "auto"`):**
   - OmniBridge POS escanea los puertos COM automáticamente. Si el puerto cambió de `COM3` a `COM4`, el agente se enlaza solo en el siguiente ciclo.
5. **Prueba simulada de software:**
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
