# Matriz Preliminar de Candidatos de Hardware POS

## OmniBridge POS™ — Microservicio Universal en Rust para Punto de Venta

- **Versión del Software:** 1.0.0
- **Fecha de Emisión:** Octubre 2026
- **Autor:** Darwin Padrino `<drinowar@gmail.com>`

---

## 1. Visión General de la Arquitectura de Hardware

OmniBridge POS™ interactúa directamente con los periféricos de punto de venta a nivel de kernel y sistema operativo, combinando comunicación serial de baja latencia con el spooler nativo de impresión (Windows Spooler / CUPS / LP).

**Estado de validación: no hay modelos homologados con pruebas físicas registradas en este repositorio.** Existe evidencia funcional preliminar reportada por el usuario el 2026-10-04: una báscula física fue probada en Windows en varios puertos COM y después de desconectar/conectar; la petición web la reconoció independientemente del COM activo. No se informó el modelo/revisión, versión de Windows, protocolo/baud rate, respuesta HTTP/payload ni latencia, por lo que esta observación no homologa un modelo ni acredita otros sistemas operativos. Esta matriz sigue siendo una lista preliminar de candidatos para evaluación; no certifica compatibilidad, protocolo, baud rate, rendimiento ni funcionamiento por sistema operativo. Los nombres y parámetros específicos requieren manual del fabricante y una prueba HIL reproducible antes de anunciar soporte.

El código disponible no contiene perfiles por modelo. La báscula escanea puertos seriales, usa el baud rate configurado, extrae el primer valor decimal de una trama y reporta `is_stable=false`; no identifica protocolos de marca ni decodifica estabilidad física. Las impresoras se enumeran y clasifican principalmente por heurísticas de nombre y reciben trabajos según la ruta implementada; la clasificación no valida lenguaje, resolución, interfaz ni resultado de impresión.

---

## 2. Balanzas Comerciales y Básculas de Mostrador

El módulo de pesaje usa el baud rate de configuración (9600 por defecto), intenta leer una trama y extrae el primer número decimal mediante `r"(\d+\.\d+)"`, redondeándolo a tres decimales. La lectura física se informa en `kg` y `is_stable=false` porque no se ha validado un indicador de estabilidad por modelo. Esto no demuestra compatibilidad con los protocolos candidatos siguientes.

| Fabricante | Familias / modelos candidatos (no verificados) | Protocolo, baud rate e interfaz por verificar con documentación del modelo |
| :--- | :--- | :--- |
| **Torrey** | L-EQ, PCR, MFQ, L-PC | No verificado; revisar manual por revisión/modelo |
| **CAS** | PD-II, ER-Plus, SW-1, DB-II | No verificado; revisar manual por revisión/modelo |
| **Systel** | Croma, Climax, Cuora | No verificado; revisar manual por revisión/modelo |
| **Toledo / Mettler** | PS60, Viva, 8217 | No verificado; revisar manual por revisión/modelo |
| **Dibal** | Serie G-310, Serie 500 | No verificado; revisar manual por revisión/modelo |
| **Cardinal Detecto** | Enterprise, 750, 850 | No verificado; revisar manual por revisión/modelo |
| **OEM genéricos** | Modelos por identificar | No verificado; no asumir trama ni baud rate común |

### Chipsets USB-Serial candidatos (sin validación HIL)

El código no identifica el chipset USB-Serial ni certifica drivers por SO. FTDI FT232R/FT232H, WCH CH340/CH341, Silicon Labs CP2102/CP2104 y Prolific PL2303 son candidatos que deben verificarse en cada combinación de adaptador, driver, sistema operativo y báscula.

---

## 3. Impresoras Térmicas de Tickets POS (80mm y 58mm)

El servicio ofrece rutas de impresión RAW y de documentos PDF mediante el spooler/las herramientas configuradas. No negocia automáticamente el lenguaje de cada modelo. El corte, el ancho, la interfaz y la impresión silenciosa deben verificarse en equipo real.

| Fabricante | Modelos candidatos (no verificados) | Ancho, lenguaje e interfaz por verificar |
| :--- | :--- | :--- |
| **Epson** | TM-T20II/III, TM-T88IV/V/VI, TM-m30 | Pendiente de prueba |
| **Xprinter** | XP-80C, XP-N160M, XP-58, XP-Q800 | Pendiente de prueba |
| **3nStar** | RPT006, RPT008, RPT010 | Pendiente de prueba |
| **Bixolon** | SRP-330II, SRP-350III, SRP-Q300 | Pendiente de prueba |
| **Star Micronics** | TSP100, TSP143, TSP650 | Pendiente de prueba |
| **Genéricas POS-80** | POS-80C, Thermal 80, Generic Text | Pendiente de prueba |

---

## 4. Impresoras Térmicas de Etiquetas de Código de Barras

La ruta RAW acepta comandos del cliente, pero no valida ni transforma el dialecto TSPL/ZPL. La salida depende del lenguaje y la configuración reales de la impresora; no hay compatibilidad por modelo demostrada.

| Fabricante | Modelos candidatos (no verificados) | Lenguaje, resolución e interfaz por verificar |
| :--- | :--- | :--- |
| **3nStar** | 4B-2054L, 4B-2054N, 4B-2044 | Pendiente de prueba |
| **4BARCODE** | 4B-2054L, 3B-2054L | Pendiente de prueba |
| **TSC** | TE200, TTP-244 Pro, DA210 | Pendiente de prueba |
| **Zebra** | GK420t, GX420d, ZD220, ZD420 | Pendiente de prueba |
| **Xprinter** | XP-365B, XP-370B, XP-420B | Pendiente de prueba |
| **Argox** | OS-214 Plus, CP-2140 | Pendiente de prueba |

---

## 5. Impresoras de Matriz de Punto / Impacto (Forma Continua)

La ruta matricial envía contenido RAW al spooler; no se ha verificado la interpretación ESC/P, alimentación ni registro de formularios por modelo.

| Fabricante | Modelos candidatos (no verificados) | Columnas, alimentación e interfaz por verificar |
| :--- | :--- | :--- |
| **Epson** | LX-350, LX-300+II, FX-890, LQ-590 | Pendiente de prueba |
| **OKI** | Microline 320 Turbo, ML420 | Pendiente de prueba |
| **Panasonic** | KX-P1150 | Pendiente de prueba |
| **Genéricas** | Generic / Text Only (Solo Texto) | Pendiente de prueba |

---

## 6. Impresoras Láser, Inyección de Tinta y Multifuncionales (A4 y Carta)

La impresión PDF depende del spooler y del motor configurado. No se ha medido impresión silenciosa ni escala/paginación por modelo en esta matriz.

| Fabricante | Familias candidatas (no verificadas) | Formatos y motor por verificar |
| :--- | :--- | :--- | :--- |
| **HP** | LaserJet Pro (M428, M404, 1000w), OfficeJet Pro | Pendiente de prueba |
| **Epson** | EcoTank L3250, L3150, WorkForce Pro | Pendiente de prueba |
| **Canon** | PIXMA G3110, imageCLASS | Pendiente de prueba |
| **Brother** | HL-L2360D, DCP-L2540DW, MFC-T920DW | Pendiente de prueba |
| **Xerox** | Phaser 3020, WorkCentre | Pendiente de prueba |

---

## 7. Gavetas de Dinero (Cash Drawers)

- **Conexión:** Conector telefónico RJ11 / RJ12 conectado directamente al puerto DK (Drawer Kick) de la impresora de tickets.
- **Voltaje:** No detectado ni validado por el agente; depende del conjunto impresora/gaveta.
- **Mecanismo:** La ruta solicita un pulso a través de la impresora. El comando, pines, voltaje y temporización deben verificarse en el manual de cada impresora/gaveta y mediante HIL.
