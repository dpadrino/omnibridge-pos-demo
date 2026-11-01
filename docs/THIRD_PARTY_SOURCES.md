# Referencias de Fuentes de Terceros

Este manifiesto identifica las versiones fuente asociadas a utilidades redistribuidas. Los ZIP fuente no se incluyen en el instalador ni en los paquetes; se publican URLs y SHA-256 para localizar y verificar las referencias. Este documento no es asesoría ni certificación legal.

## SumatraPDF

- Versión redistribuida: `3.6.1` (ZIP portable oficial).
- Referencia de fuente: tag `3.6.1rel`, commit `16c59fde8b824ab54c56f23aef910a6fdd874ad0`.
- Archivo fuente: https://codeload.github.com/sumatrapdfreader/sumatrapdf/zip/refs/tags/3.6.1rel
- SHA-256 del ZIP fuente: `67bcd66f9d25fa5338ef7c4d882ce7597dc94083b5d7fe4d44da392640c8dec1`
- Avisos upstream: `COPYING`, `COPYING.BSD`, `AUTHORS` y licencias por componente dentro del archivo fuente.
- Alcance declarado upstream: (A)GPLv3 con componentes BSD; el árbol fuente también contiene avisos específicos, incluidos AGPL-3.0 para MuPDF, LGPL-3.0 para unarr y GPL-2.0-or-later para libdjvu.
- El ZIP fuente mide aproximadamente 80 MB y no se incluye en los paquetes por decisión de distribución. El URL y hash no sustituyen una revisión legal de las obligaciones aplicables al binario exacto.

## NSSM

- Versión redistribuida: `2.24` (Windows x64).
- Archivo oficial que incluye fuentes: https://nssm.cc/release/nssm-2.24.zip
- SHA-256 del ZIP: `727d1e42275c605e0f04aba98095c38a8e1e46def453cdffce42869428aa6743`
- La página oficial de descarga declara NSSM como dominio público y confirma que el ZIP incluye el código fuente. Conservar el ZIP original o la referencia/hash junto con el binario.

## Estado

Los paquetes incluyen este manifiesto y `THIRD_PARTY_LICENSES.md`, pero no los ZIP fuente. La aprobación de distribución comercial sigue pendiente de verificar los requisitos aplicables y decidir un mecanismo de entrega de fuentes/avisos para cada componente y jurisdicción.