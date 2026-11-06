# Historial de MSW-37

- 2026-11-05 17:20: Estado: Por hacer -> En curso
- 2026-11-05 17:34: Estado: En curso -> Listo para prueba de Luis
- 2026-11-05 17:34: Implementado LyricsStructureSuggester para análisis de estrofas y repeticiones textuales (detectando Versos, Coros, Pre-coros, Puentes y Finales con o sin encabezados explícitos). Integrado modal interactivo de sugerencia en SongStructureEditorPage (con botones Descartar y Aplicar estructura, garantizando que nada se guarde sin confirmación del usuario). Suite de pruebas con 3 letras de ejemplo completadas y 170/170 pruebas pasando.
- 2026-11-05 18:54: Añadido soporte para equivalencias de acordes abreviados (A4->Asus4, E7(4/9)->E7sus4(9), 6/9), encuadre visual con tarjetas de colores para cada sección de la canción, y normalización automática de encabezados tipo 'primera parte' a 'Verso 1'. 175 pruebas pasando.
- 2026-11-05 19:03: Añadida opción de eliminar canción deslizando hacia un lado (Dismissible) en la lista de Biblioteca y botón de eliminar en el detalle de la canción, ambos con diálogo de confirmación.
- 2026-11-05 19:19: Añadidas equivalencias estándar para acordes poco convencionales: E7(-)->Em7 (Mim7), D7M->Dmaj7 (Remaj7), F5-->F(b5) (Fa(b5)), C#5+->C#aug (Do#aug) y D4+->Dsus4 (Resus4). Soporte completo en el detector de líneas de acordes.
- 2026-11-05 19:47: Estructura: ensamblado inteligente del flujo completo (roadmap explícito, menciones de sección sin acordes ni letra redundante, y expansión natural de coro tras versos y puente sin duplicar secciones vacías).
