# Historial de MSW-25

- 2026-10-29 23:50: Estado: Por hacer -> En curso
- 2026-10-29 23:50: Plan: crear pantalla de detalle para leer canciones, transponer acordes y cambiar entre notación americana y latina.
- 2026-10-29 23:55: Implementada `SongDetailPage` con tono original/actual, controles de semitonos, selección de tono destino y selector de notación.
- 2026-10-29 23:55: La biblioteca ahora abre el detalle al tocar una canción.
- 2026-10-29 23:55: Pruebas añadidas para posiciones de acordes, transposición, restauración del tono original y notación latina.
- 2026-10-30 00:14: Corrección: el tono actual ahora se calcula directamente desde el tono original y los semitonos activos; se normalizan también los pasos descendentes.
- 2026-10-30 00:14: Prueba añadida para verificar que dos pulsaciones de subir semitono actualizan el tono actual a D desde C.
- 2026-10-29 23:52: Estado: Por hacer -> Listo para prueba de Luis
- 2026-10-29 23:52: Pantalla de detalle implementada con transposición por semitonos, tono destino, notación latina/americana y apertura desde Biblioteca. flutter analyze y flutter test: 88 pruebas OK.
