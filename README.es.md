# OmniBridge POS — Demo de evaluación e integración

**Español** | [English](README.md)

[![Preview](https://img.shields.io/badge/Base-1.2.0_preview-orange.svg)](https://github.com/dpadrino/omnibridge-pos-demo/releases/tag/preview)

Agente nativo de periféricos POS con API HTTP local para básculas seriales,
impresión de tickets/etiquetas/matriz/documentos y gavetas. Este repositorio
público contiene documentación, ejemplos y scripts de distribución, **no
el código Rust privado**.

## Descarga e identidad de compilación

[Descargar el preview actual de evaluación](https://github.com/dpadrino/omnibridge-pos-demo/releases/tag/preview).
La versión base se mantiene en **1.2.0** durante este sprint de prototipo.
No se sobrescriben tags estables ni releases históricos; `preview` es un
prerelease, no `latest`.

GitHub Actions del agente compila los paquetes de:

| Plataforma | Target | Paquete |
|---|---|---|
| Windows x86_64 | `x86_64-pc-windows-msvc` | `.zip`, incluye instalador Inno Setup |
| Linux x86_64 | `x86_64-unknown-linux-gnu` | `.tar.gz` |
| macOS Apple Silicon | `aarch64-apple-darwin` | `.tar.gz` |

La matriz no incluye macOS Intel. Los nombres incorporan versión, **SHA completo
del código del agente** y target. Cada paquete tiene checksum SHA-256 externo,
manifiesto de compilación y `SHA256SUMS.txt` interno. Las notas identifican
SHA/run del agente y SHA documental de esta demo. Ambos repositorios distribuyen
**los mismos paquetes verificados**, no compilaciones independientes de código público.

Un mantenedor autenticado copia el conjunto completo a la demo una vez aprobados
los tres builds. El workflow público valida ejemplos/scripts, no compila Rust ni
homologa hardware. La publicación exige verificar descargas, hashes e identidad
de las tres plataformas. No se distribuyen claves de firma, licencias de clientes
ni configuración local.

## Instalación y actualización segura

Verificar checksum y firma cuando exista. Extraer fuera del directorio instalado:
**no descomprimir sobre una instalación en ejecución**.

```powershell
# Administrador, desde el paquete Windows extraído por separado
.\scripts\install_windows_service.ps1 -InstallDir 'C:\PosAgent' -Port 8989
.\scripts\diagnose_service.ps1 -Port 8989
```

```sh
# Elegir solo el instalador de la plataforma correspondiente
sudo bash scripts/install_linux_service.sh 8989
sudo bash scripts/install_macos_service.sh 8989
sudo bash scripts/diagnose_service.sh 8989
```

Los instaladores preservan configuración/licencia/clave maestra, detienen antes
del reemplazo, retienen respaldos y comprueban gestor + HTTP antes de anunciar
éxito. Un fallo sigue siendo error aunque funcione la recuperación. El puerto
indicado solo selecciona la comprobación; no modifica la configuración guardada.
No se elimina automáticamente la cuarentena de Gatekeeper.

[Guía de despliegue y recuperación](docs/DEPLOYMENT_GUIDE.md) |
[Aceptación y diagnóstico en pilotos](docs/PILOT_DEPLOYMENT_AND_DIAGNOSTICS_PLAYBOOK.md)

## Configuración, seguridad e integración

El panel local restringido cubre los ajustes no secretos de los servicios y
exige credencial administrativa independiente, sesión y validación Origin/CSRF.
Guardar no significa activar en caliente: comparar configuración activa/guardada
y reiniciar cuando corresponda. La autenticación operativa y CORS son controles
separados; loopback no sustituye autorización administrativa.

Usar el [ejemplo JavaScript validado](https://dpadrino.github.io/omnibridge-pos-demo/#pos-integration-example)
y el [contrato OpenAPI](docs/openapi.yaml), no peticiones de tres líneas sin
comprobar respuestas. Verificar HTTP y errores no JSON antes de consumir datos.
No reenviar automáticamente impresiones después de 503/504 o fallos ambiguos.
Hay cuatro workers simultáneos de despacho; la pesada usa un bloqueo independiente.

```sh
node --test scripts/consumer_contract.test.mjs
```

## Alcance y límites de aceptación

- Detección serial/parser no significa soporte para todas las básculas.
- Éxito de impresión confirma despacho al backend, no salida en papel o apertura física.
- La simulación y el [showcase online](https://dpadrino.github.io/omnibridge-pos-demo/)
  no homologan equipos.
- Las rutas biométricas cubren asistencia ZKTeco acotada y push ADMS/JSON.
  Captura USB y enrolamiento no están implementados: devuelven 501.
  La asistencia es volátil; no presentarlo como producto biométrico certificado.
- Instalación/actualización nativa y aceptación física requieren estaciones
  dedicadas Windows/Linux/macOS y pruebas por modelo.

[Video demostrativo](docs/OmniBridge_POS_Promo_Video.mp4) |
[Folleto comercial histórico](docs/OmniBridge_POS_Brochure_Comercial.es.pdf)

Videos, folletos y matrices anteriores son material histórico ilustrativo, no
evidencia de aceptación actual. Este README, los contratos y notas del preview
definen el alcance vigente.

## Licenciamiento

Sin licencia comercial válida se aplican restricciones de evaluación; no se
promete acceso ilimitado ni soporte implementado para cada endpoint.
Consultar [licencia propietaria](LICENSE.txt) y
[licencias de terceros](docs/THIRD_PARTY_LICENSES.md).
