# OmniBridge POS™ — Pasarela Universal de Hardware (Rust)
### DEMO de Evaluación y Documentación de Integración

**Español** | [English](README.md)

[![Lenguaje](https://img.shields.io/badge/Lenguaje-Rust_2021-orange.svg)](https://www.rust-lang.org/)
[![Plataformas](https://img.shields.io/badge/Plataformas-Windows_%7C_Linux_%7C_macOS-blue.svg)]()
[![Versión](https://img.shields.io/badge/Versi%C3%B3n-v1.0.0_Evaluaci%C3%B3n_DEMO-brightgreen.svg)](https://github.com/dpadrino/omnibridge-pos-demo/releases)
[![Licencia](https://img.shields.io/badge/Licencia-Comercial_%2F_Propietaria-red.svg)](LICENSE.txt)

![OmniBridge POS](docs/upwork_portfolio_thumbnail.png)

---

## 1. ¿Qué es OmniBridge POS™?

Los navegadores web modernos imponen estrictas políticas de sandbox que bloquean el acceso directo a periféricos de caja física. Como resultado:
* Al imprimir un ticket térmico se abre la ventana emergente de Chrome (`Ctrl+P`), ralentizando el cobro.
* Las aplicaciones web no pueden comunicarse directamente con balanzas electrónicas por puerto serial COM (RS232/USB).
* La gaveta de dinero no se puede disparar de forma automática sin fricciones de drivers.

**OmniBridge POS™** es un servicio en segundo plano escrito en **Rust** de alto rendimiento y bajo consumo (<15MB RAM) que conecta cualquier sistema POS o ERP web/cloud (React, Angular, Vue, PHP/Laravel, Odoo, WooCommerce) con el hardware de caja mediante simples peticiones HTTP REST locales.

---

## 2. ⚡ Descarga Rápida de la Versión DEMO

Puedes descargar el instalador y paquete de evaluación directamente desde la sección de Releases:

👉 **[Descargar Paquete DEMO Oficial (v1.0.0)](https://github.com/dpadrino/omnibridge-pos-demo/releases)**

### El Modo de Evaluación Gratuito incluye:
* Acceso completo a todos los endpoints en el puerto unificado `8989`.
* Panel web visual interactivo en `http://127.0.0.1:8989/`.
* Lectura serial de balanzas (con hardware físico o en modo simulación).
* Impresión térmica de tickets (hasta 25 impresiones al día con marca de agua).
* Auto-recuperación y saneamiento de colas atascadas en el Spooler de Windows.

---

## 3. Integración en 3 Líneas de Código (JavaScript)

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

## 4. Endpoints Principales de la API (Puerto Unificado 8989)

| Método | Endpoint | Alias | Descripción | Formato |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/` | - | Panel visual web interactivo de diagnóstico (suite 1-clic) | HTML Dashboard |
| `GET` | `/peso` | `/weight` | Lectura en tiempo real de la balanza serial (RS232 / USB) | JSON `{"peso": 1.25, "unit": "kg"}` |
| `POST`| `/ticket` | `/impresora/ticket` | Impresión inteligente de tickets (térmicas ESC/POS) | JSON, Multipart PDF o RAW |
| `POST`| `/drawer` | `/gaveta` | Disparo de pulso eléctrico para gaveta (RJ11 Pin 2 y 5) | POST vacío |
| `POST`| `/print-label`| `/impresora/etiqueta` | Despacho RAW de etiquetas de códigos de barra (TSPL/ZPL) | JSON `{"commands": "..."}` |
| `POST`| `/printers/cleanup` | `/impresoras/limpiar` | Auto-purga de trabajos atascados en el Spooler | POST vacío |
| `GET` | `/health` | `/status` | Diagnóstico de salud: puertos, spooler y licencias | JSON Health Status |

---

## 5. Planes Comerciales y Precios

Para desbloquear operaciones ilimitadas y eliminar marcas de agua de evaluación mediante licencias criptográficas **Ed25519** (activación offline sin internet):

| Plan | Cliente Objetivo | Precio Sugerido | Lo que incluye |
| :--- | :--- | :--- | :--- |
| **Plan Estación / Caja** | Supermercados, panaderías, tiendas | **$35 – $50 USD** / año por caja (o $90 perpetuo) | Instalador 1-clic como Servicio Windows, lecturas de báscula e impresiones ilimitadas, cero marcas de agua y panel local. |
| **Plan OEM / Marca Blanca** | Casas de software y creadores de ERPs | **$1,200 – $2,500 USD** (Pago único) | Distribución ilimitada bajo tu propia marca y logotipo, sin regalías por caja, colección Postman, especificación OpenAPI 3.0 y generador de licencias. |
| **Consultoría & Adaptaciones** | Proyectos corporativos y cadenas | **Cotización según proyecto** | Homologación de balanzas industriales específicas, integración asistida con Odoo, WooCommerce, PHP o React, y soporte prioritario. |

---

## 6. Folletos Comerciales Oficiales (PDF)

* 🇪🇸 [**Descargar Folleto Comercial (Español PDF)**](docs/OmniBridge_POS_Brochure_Comercial.es.pdf)
* 🇺🇸 [**Descargar Folleto Comercial (English PDF)**](docs/OmniBridge_POS_Brochure_Comercial.en.pdf)

---

## 7. Contacto Comercial y Soporte

Para consultas comerciales, compra de licencias o integración técnica:

* **Autor y Desarrollador:** Darwin Padrino
* **WhatsApp / Teléfono:** [+58 412-6165227](https://wa.me/584126165227)
* **Correo Electrónico:** [drinowar@gmail.com](mailto:drinowar@gmail.com)
* **Disponibilidad:** Servicios y soporte remoto para toda Latinoamérica, Estados Unidos y España.
