# Historial de MSW-37

- 2026-11-05 17:20: Estado: Por hacer -> En curso
- 2026-11-05 17:34: Estado: En curso -> Listo para prueba de Luis
- 2026-11-05 17:34: Implementado LyricsStructureSuggester para análisis de estrofas y repeticiones textuales (detectando Versos, Coros, Pre-coros, Puentes y Finales con o sin encabezados explícitos). Integrado modal interactivo de sugerencia en SongStructureEditorPage (con botones Descartar y Aplicar estructura, garantizando que nada se guarde sin confirmación del usuario). Suite de pruebas con 3 letras de ejemplo completadas y 170/170 pruebas pasando.
- 2026-11-05 18:54: Añadido soporte para equivalencias de acordes abreviados (A4->Asus4, E7(4/9)->E7sus4(9), 6/9), encuadre visual con tarjetas de colores para cada sección de la canción, y normalización automática de encabezados tipo 'primera parte' a 'Verso 1'. 175 pruebas pasando.
