# Inventario y Declaración de Licencias de Terceros
## OmniBridge POS™ — Microservicio Local de Periféricos en Rust

- **Producto:** OmniBridge POS™
- **Licencia Principal del Software:** Propietaria Comercial ([`LICENSE.txt`](../LICENSE.txt))
- **Autor y Titular de Derechos:** Darwin Padrino `<drinowar@gmail.com>`
- **Fecha de Auditoría:** 3 de Octubre de 2026

---

## 1. Alcance y Estado de la Revisión

OmniBridge POS™ es un producto de software comercial y propietario. El binario compilado y el código fuente propietario están amparados bajo los términos del Acuerdo de Licencia de Usuario Final (EULA).

Este documento es un inventario técnico de dependencias y componentes redistribuidos; **no constituye un dictamen jurídico ni certifica compatibilidad legal para todos los mercados**. La publicación comercial queda sujeta a verificar los avisos, licencias y fuentes correspondientes a cada versión efectivamente empaquetada.

Las versiones de crates de la tabla corresponden al `Cargo.lock` existente al auditar este documento. El lockfile también contiene dependencias transitivas y específicas de plataformas que no necesariamente se compilan en cada artefacto.

## 2. Dependencias Directas de Rust

Versiones y expresiones SPDX obtenidas de los metadatos del grafo bloqueado. La tabla cubre las dependencias directas del manifiesto, no sustituye el análisis de transitivas.

| Crate | Versión bloqueada | Expresión de licencia declarada | Propósito |
| :--- | :--- | :--- | :--- |
| **`anyhow`** | `1.0.104` | `MIT OR Apache-2.0` | Contexto de errores |
| **`axum`** | `0.7.9` | `MIT` | Framework HTTP |
| **`base64`** | `0.22.1` | `MIT OR Apache-2.0` | Codificación/decodificación Base64 de licencias |
| **`chrono`** | `0.4.45` | `MIT OR Apache-2.0` | Manejo de fechas y estampas de tiempo biométricas |
| **`ed25519-dalek`** | `2.2.0` | `BSD-3-Clause` | Criptografía asimétrica Ed25519 para verificación de firmas |
| **`getrandom`** | `0.2.17` | `MIT OR Apache-2.0` | Entropía del sistema operativo para sesiones administrativas |
| **`http-body-util`** | `0.1.5` | `MIT` | Utilidades HTTP para pruebas |
| **`libc`** | `0.2.189` | `MIT OR Apache-2.0` | PTY en pruebas Unix; dependencia solo de desarrollo en Unix |
| **`regex`** | `1.13.1` | `MIT OR Apache-2.0` | Extracción de tramas de peso |
| **`reqwest`** | `0.12.28` | `MIT OR Apache-2.0` | Cliente HTTP |
| **`serde`** | `1.0.229` | `MIT OR Apache-2.0` | Serialización |
| **`serde_json`** | `1.0.151` | `MIT OR Apache-2.0` | Serialización JSON |
| **`serialport`** | `4.10.1` | `MPL-2.0` | Comunicación serial |
| **`subtle`** | `2.6.1` | `BSD-3-Clause` | Comparación de credenciales en tiempo constante |
| **`tempfile`** | `3.27.0` | `MIT OR Apache-2.0` | Archivos temporales |
| **`thiserror`** | `1.0.69` | `MIT OR Apache-2.0` | Tipos de error |
| **`tokio`** | `1.53.1` | `MIT` | Runtime asíncrono |
| **`toml`** | `0.8.23` | `MIT OR Apache-2.0` | Configuración TOML |
| **`tower`** | `0.4.13` | `MIT` | Abstracciones de servicios |
| **`tower-http`** | `0.5.2` | `MIT` | Middleware HTTP |
| **`tracing`** | `0.1.44` | `MIT` | Trazas y logs |
| **`tracing-subscriber`** | `0.3.23` | `MIT` | Suscripción de logs |

## 3. Dependencias Transitivas y Plataformas

El grafo completo contiene licencias BSD-2-Clause, BSD-3-Clause, ISC, Unicode-3.0, Unlicense y otras expresiones además de MIT, Apache-2.0 y MPL-2.0. Por tanto, no es correcto describir todas las dependencias como pertenecientes únicamente a MIT/Apache/MPL.

| Crate | Presencia en targets revisados | Expresión declarada |
| :--- | :--- | :--- |
| `unescaper` (transitivo de `serialport`) | Linux x86_64; no aparece en los árboles macOS/Windows revisados | `MIT OR GPL-3.0-only` |
| `r-efi` | Incluido en `Cargo.lock` para otros targets; no aparece en los tres targets de distribución revisados | `MIT OR LGPL-2.1-or-later` |
| `serialport` | Dependencia directa | `MPL-2.0` |

Las expresiones `OR` publicadas por los crates enumeran alternativas de licencia; este inventario no registra una elección jurídica del producto. `Cargo.lock` fija versiones, pero no selecciona ni reemplaza las condiciones de licencia de cada componente.

> **Nota de MPL-2.0:** `serialport` declara MPL-2.0. Revisar la licencia y los avisos de la versión exacta distribuida y cualquier modificación local antes de publicar. Esta nota no determina por sí sola el efecto legal sobre una distribución concreta.

## 4. Binarios y Utilidades Redistribuidos

### 4.1. SumatraPDF (`SumatraPDF.exe`)
- **Versión:** 3.6.1, fijada en `scripts/download_tools.sh` y `scripts/download_tools.bat`; la versión 3.5.2 anteriormente indicada era incorrecta.
- **Alcance upstream:** El README oficial identifica SumatraPDF bajo (A)GPLv3 con partes BSD; el árbol contiene avisos específicos adicionales, como AGPL-3.0 de MuPDF, LGPL-3.0 de unarr y GPL-2.0-or-later de libdjvu.
- **Sitio Oficial:** https://www.sumatrapdfreader.org/
- El instalador y el empaquetador Windows copian el ejecutable. La invocación como proceso separado es un hecho técnico, no una conclusión jurídica sobre la distribución.
- Los paquetes no incluyen los ZIP de licencia/fuente. `docs/THIRD_PARTY_SOURCES.md` identifica la fuente oficial fijada, sus avisos y SHA-256; esto no demuestra por sí solo que se hayan satisfecho las obligaciones de la distribución concreta. **No distribuir este artefacto como legalmente aprobado** sin revisión competente.

### 4.2. NSSM — Non-Sucking Service Manager (`nssm.exe`)
- **Versión:** 2.24
- **Licencia:** Dominio Público (Public Domain)
- **Sitio Oficial:** https://nssm.cc/
- **Propósito:** Registro e inicialización de OmniBridge POS como servicio desatendido de Windows con supervisión y reinicio automático.
- La página oficial de NSSM confirma dominio público y que el ZIP 2.24 incluye código fuente. Los paquetes no incluyen ese ZIP; la referencia y hash verificados están en `docs/THIRD_PARTY_SOURCES.md`. La revisión de obligaciones por jurisdicción sigue pendiente.

## 5. Avisos y Evidencia de Distribución

Los empaquetadores copian `LICENSE.txt`, este resumen y `THIRD_PARTY_SOURCES.md`. Estos documentos identifican fuentes y hashes, pero no contienen todos los textos de licencia ni los ZIP fuente. Antes de publicar, generar y revisar los avisos requeridos y acordar la entrega de fuentes para cada componente.

Los extractos siguientes son informativos y no constituyen un conjunto completo de avisos para el artefacto distribuido.

### Licencia MIT
```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Licencia Apache 2.0
Consultar el texto íntegro de la licencia Apache-2.0 y los avisos de los crates distribuidos; este resumen no los sustituye.

## 6. Estado de la Auditoría

La tabla de dependencias directas se valida contra `cargo metadata --locked`; las transitivas y los binarios redistribuidos requieren revisión adicional. La licencia comercial del producto no elimina las obligaciones aplicables a los componentes de terceros. No se emite aquí una certificación de compatibilidad ni una aprobación para venta/distribución. La revisión jurídica y la preparación de avisos/fuentes del paquete siguen pendientes.
