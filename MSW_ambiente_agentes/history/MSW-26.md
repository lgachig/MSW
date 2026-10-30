# Historial de MSW-26

- 2026-10-30 00:25: Estado: Por hacer -> En curso
- 2026-10-30 00:25: Plan: persistir arreglos separados de la canción original, permitir copiarlos y editarlos, y seleccionar la versión desde el detalle.
- 2026-10-30 00:35: Agregada tabla `Arrangements` con migración Drift y serialización de secciones, líneas y posiciones de acordes.
- 2026-10-30 00:35: Agregados métodos de repositorio para crear, listar y actualizar arreglos sin modificar la canción original.
- 2026-10-30 00:35: El detalle permite crear un arreglo como copia, elegir entre arreglos y versión original, y editar el arreglo seleccionado.
- 2026-10-30 00:35: Añadida prueba de repositorio que edita un arreglo y confirma que el original conserva sus acordes.
- 2026-10-30 00:26: Estado: Por hacer -> Listo para prueba de Luis
- 2026-10-30 00:26: Arreglos separados persistidos con Drift; se pueden crear como copia, seleccionar, editar y volver a la versión original. flutter analyze y flutter test: 91 pruebas OK.
