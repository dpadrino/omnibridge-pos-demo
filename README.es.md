# OmniBridge POS™ — Pasarela Universal de Hardware (Rust)
### DEMO de Evaluación y Documentación de Integración

**Español** | [English](README.md)

[![Lenguaje](https://img.shields.io/badge/Lenguaje-Rust_2021-orange.svg)](https://www.rust-lang.org/)
[![Plataformas](https://img.shields.io/badge/Plataformas-Windows_%7C_Linux_%7C_macOS-blue.svg)]()
[![Versión](https://img.shields.io/badge/Versi%C3%B3n-v1.1.8_Evaluaci%C3%B3n_DEMO-brightgreen.svg)](https://github.com/dpadrino/omnibridge-pos-demo/releases)
[![Simulador Online](https://img.shields.io/badge/Simulador_Web-Abrir_en_Vivo-blueviolet.svg)](https://dpadrino.github.io/omnibridge-pos-demo/)
[![Video Demo](https://img.shields.io/badge/Video_Demo-Ver_en_la_Web-red.svg)](https://dpadrino.github.io/omnibridge-pos-demo/#video-section)
[![Licencia](https://img.shields.io/badge/Licencia-Comercial_%2F_Propietaria-red.svg)](LICENSE.txt)

[![OmniBridge POS — Clic para abrir el Simulador y Video en Vivo](docs/upwork_portfolio_thumbnail.png)](https://dpadrino.github.io/omnibridge-pos-demo/)

> ### 🌐 [PROBAR DEMO INTERACTIVA & VER VIDEO EN VIVO (CLIC AQUÍ)](https://dpadrino.github.io/omnibridge-pos-demo/)
> 💡 **Nota importante de navegación:** Al explorar los archivos dentro de GitHub, los archivos `.html` se muestran por defecto como código fuente por restricciones de seguridad de la plataforma. Para probar el **Simulador de Impresión Silenciosa**, la **Balanza Digital** y reproducir el **Video Comercial con Audio**, ingresa directamente a:  
> 👉 **[https://dpadrino.github.io/omnibridge-pos-demo/](https://dpadrino.github.io/omnibridge-pos-demo/)**
> 
> 📄 **[Descargar Folleto Comercial Oficial (PDF)](docs/OmniBridge_POS_Brochure_Comercial.es.pdf)**

---

## 1. ¿Qué es OmniBridge POS™?

Los navegadores web modernos imponen estrictas políticas de sandbox que bloquean el acceso directo a periféricos de caja física. Como resultado:
* Al imprimir un ticket térmico se abre la ventana emergente del navegador (`Ctrl+P`), ralentizando el cobro.
* Las aplicaciones web no pueden comunicarse directamente con balanzas electrónicas por puerto serial COM (RS232/USB).
* La gaveta de dinero no se puede disparar de forma automática sin fricciones de drivers.

**OmniBridge POS™** es un servicio en segundo plano escrito en **Rust** de alto rendimiento y bajo consumo (<15MB RAM) que conecta cualquier sistema POS o ERP web/cloud (React, Angular, Vue, PHP/Laravel, Odoo, WooCommerce) con el hardware de caja mediante simples peticiones HTTP REST locales.

---

## 2. 🎬 Video Demostrativo y Guía Visual Interactiva

Para conocer el producto en acción y experimentar el flujo de hardware antes de instalarlo en tu estación:

| Recurso Multimedia | Descripción | Acceso Directo |
| :--- | :--- | :--- |
| 🌐 **Guía Visual & Simulador Web** | Demostración interactiva en HTML5: prueba la impresión térmica en vivo, simula lecturas de balanza digital y apertura de gaveta en tu navegador sin instalar nada. | 🚀 [**Abrir Simulador Online (GitHub Pages)**](https://dpadrino.github.io/omnibridge-pos-demo/) |
| 🎬 **Video Comercial con Locución** | Video Full HD de 1 minuto explicando el problema de la ventana emergente de Chrome y cómo OmniBridge POS lo resuelve al instante con voz profesional y música de fondo. | ▶️ [**Reproducir Video en la Web**](https://dpadrino.github.io/omnibridge-pos-demo/#video-section) <br> 📥 [Descargar MP4 Directo (1.8 MB)](https://github.com/dpadrino/omnibridge-pos-demo/releases/download/v1.1.8/OmniBridge_POS_Promo_Video.mp4) |
| 📄 **Folleto Comercial Oficial (PDF)** | Documento formal de 2 páginas con ficha técnica, arquitectura REST, tabla de endpoints y comparativa. | 📥 [**Descargar Folleto PDF**](docs/OmniBridge_POS_Brochure_Comercial.es.pdf) |

---

## 3. ⚡ Descarga Rápida de la Versión DEMO

Puedes descargar el instalador y paquete de evaluación directamente desde la sección de Releases:

👉 **[Descargar Paquete DEMO Oficial (v1.1.8)](https://github.com/dpadrino/omnibridge-pos-demo/releases)**

### El Modo de Evaluación Gratuito incluye:
* **Acceso completo a todos los endpoints** en el puerto unificado `8989`.
* **Panel web visual interactivo y Asistente de Configuración** en `http://127.0.0.1:8989/`:
  - Detección automática en vivo de puertos seriales y lista de impresoras instaladas en el SO.
  - Asignación gráfica de variables y periféricos sin editar archivos de texto manualmente.
  - **Módulo de Licencia en Vivo:** Indicador de vigencia de uso y cargador de licencias en 1-clic (archivo `.key` o pegado de texto) con validación criptográfica Ed25519.
* **Lectura serial de balanzas:** Conexión a hardware físico o modo simulación para desarrollo.
* **Impresión térmica de tickets y etiquetas:** Evaluación con **marca de agua** (`*** MODO DEMO - OMNIBRIDGE POS ***`) y límite de cortesía de hasta 25 impresiones al día.
* **Auto-recuperación y saneamiento:** Purga de colas atascadas en el Spooler de Windows.

---

## 4. Integración en 3 Líneas de Código (JavaScript)

```javascript
// 1. Leer el peso en tiempo real de la balanza:
const { peso } = await (await fetch('http://localhost:8989/peso')).json();

// 2. Disparar apertura eléctrica de la gaveta de dinero:
await fetch('http://localhost:8989/drawer', { method: 'POST' });

// 3. Imprimir ticket térmico silencioso en milisegundos:
await fetch('http://localhost:8989/ticket', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ content: "TICKET #101\nTotal: $25.00\nGRACIAS POR SU COMPRA\n" })
});
```

---

## 5. Endpoints Principales de la API (Puerto Unificado 8989)

| Método | Endpoint | Alias | Descripción | Formato |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/` | - | Panel visual web interactivo y Asistente Gráfico de Configuración | HTML Dashboard |
| `GET` | `/peso` | `/weight` | Lectura en tiempo real de la balanza serial (RS232 / USB) | JSON `{"peso": 1.25, "unit": "kg"}` |
| `POST`| `/ticket` | `/impresora/ticket` | Impresión inteligente de tickets (térmicas ESC/POS) | JSON, Multipart PDF o RAW |
| `POST`| `/drawer` | `/gaveta` | Disparo de pulso eléctrico para gaveta (RJ11 Pin 2 y 5) | POST vacío |
| `POST`| `/print-label`| `/impresora/etiqueta` | Despacho RAW de etiquetas de códigos de barra (TSPL/ZPL) | JSON `{"commands": "..."}` |
| `POST`| `/print-matrix`| `/impresora/matriz` | Impresión en papel continuo / matricial (ESC/P) | JSON `{"text": "...", "form_feed": true}` |
| `POST`| `/print/document`| `/impresora/documento`| Impresión en hojas de oficina Láser/A4 con escala `fit` | Multipart PDF o JSON URL |
| `GET` | `/printers` | `/impresoras` | Catálogo de impresoras con clasificación heurística cuádruple | JSON Printers Catalog |
| `POST`| `/printers/cleanup` | `/impresoras/limpiar`| Auto-purga de trabajos atascados en el Spooler | POST vacío |
| `GET/POST`| `/api/v1/config` | `/config` | Consulta y guardado gráfico de variables del host en vivo | JSON Config Payload |
| `GET/POST`| `/api/v1/license`| `/license` | Consulta de vigencia y activación en caliente de licencia | JSON License Status |
| `GET` | `/health` | `/status` | Diagnóstico de salud: puertos, spooler y licencias | JSON Health Status |

---

## 6. Planes Comerciales y Precios

Para desbloquear operaciones ilimitadas y eliminar marcas de agua de evaluación mediante licencias criptográficas **Ed25519** (activación offline sin internet):

| Plan | Cliente Objetivo | Precio Oficial | Enlace Directo WhatsApp | Lo que incluye |
| :--- | :--- | :--- | :--- | :--- |
| **Estación Anual** | Retail, minimarkets, farmacias | **$35 USD** / año por caja | [🛒 Comprar ($35)](https://wa.me/584126165227?text=Hola%20Darwin,%20quiero%20comprar%20la%20Licencia%20Estacion%20Anual%20($35%20USD)) | Instalador 1-clic como Servicio Windows, lecturas de báscula e impresiones ilimitadas, cero marcas de agua, asistente gráfico local y soporte. |
| **Estación Indefinida** | Comercios con caja fija única | **$90 USD** (Pago único) | [🛒 Comprar ($90)](https://wa.me/584126165227?text=Hola%20Darwin,%20quiero%20comprar%20la%20Licencia%20Estacion%20Indefinida%20($90%20USD)) | Licencia vitalicia perpetua, firma digital Ed25519 offline, auto-purga de colas de impresión y actualizaciones de mantenimiento. |
| **OEM / Marca Blanca** | Casas de software y creadores ERP/POS | **$390 USD** (Pago único) | [🛒 Comprar OEM ($390)](https://wa.me/584126165227?text=Hola%20Darwin,%20quiero%20comprar%20la%20Licencia%20OEM%20Marca%20Blanca%20($390%20USD)) | Distribución ilimitada bajo tu propia marca y logotipo, cero regalías por caja, colección Postman, especificación OpenAPI 3.0 y keygen. |
| **Consultoría & Adaptaciones** | Proyectos corporativos y cadenas | **A convenir** | [💬 Cotizar Proyecto](https://wa.me/584126165227?text=Hola%20Darwin,%20deseo%20cotizar%20un%20proyecto%20a%20medida%20con%20OmniBridge%20POS) | Homologación de balanzas industriales específicas, integración asistida con Odoo, WooCommerce, PHP o React, y soporte prioritario. |

---

## 7. Folletos Comerciales Oficiales (PDF)

* 🇪🇸 [**Descargar Folleto Comercial (Español PDF)**](docs/OmniBridge_POS_Brochure_Comercial.es.pdf)
* 🇺🇸 [**Descargar Folleto Comercial (English PDF)**](docs/OmniBridge_POS_Brochure_Comercial.en.pdf)

---

## 8. Contacto Comercial y Soporte

Para consultas comerciales, compra de licencias o integración técnica:

* **Autor y Desarrollador:** Darwin Padrino
* **WhatsApp / Teléfono:** [+58 412-6165227](https://wa.me/584126165227)
* **Correo Electrónico:** [drinowar@gmail.com](mailto:drinowar@gmail.com)
* **Disponibilidad:** Servicios y soporte remoto para toda Latinoamérica, Estados Unidos y España.
