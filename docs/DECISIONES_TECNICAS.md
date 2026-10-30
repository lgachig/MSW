# Decisiones técnicas: MusicSundayWorship (MSW)

**Fecha:** 2026-10-28
**Estado:** aprobadas por Luis al cierre de la Fase 0.

| Tema | Decisión | Motivo |
|---|---|---|
| Framework | Flutter (Dart), versión 3.47.8, canal stable | Una sola base de código para iOS, Android y tablets. Se fija la versión para no romper el proyecto al actualizar. |
| Manejo de estado | Riverpod | Estándar actual, fácil de probar y encaja con módulos por funcionalidad. |
| Navegación | go_router | Navegación declarativa y soporte de enlaces profundos. |
| Base de datos | Drift sobre SQLite | Offline-first, consultas tipadas y migraciones. |
| Motor musical | Dart puro en `lib/music_engine/`, sin depender de Flutter | Se prueba con pruebas unitarias sin abrir el teléfono. |
| Pruebas | Cobertura mínima de 70% en lógica de dominio (motor y estructura). Prueba obligatoria para cada regla de transposición. | Un error de transposición se nota en pleno servicio. |
| Calidad de código | `flutter_lints` activado. `flutter analyze` sin errores antes de pasar de `develop` a `qa`. | Mantener el código consistente. |
| Ramas | `develop` (trabajo diario), `qa` (pruebas), `feature/nombre` (ramas cortas). Sin `main` por ahora. | Flujo simple para un proyecto individual. |
| Commits | Mensajes cortos y claros, por ejemplo "Agrega transposición por semitonos". | Historial legible. |

## Pendiente de decidir más adelante

- Paquete de audio para el metrónomo de baja latencia (Fase 4).
- Servicio de OCR en el dispositivo: ML Kit o Vision (Fase 3).
- Proveedor del modelo multimodal y backend ligero para los agentes (Fase 3).
- Flavors de Flutter para tener QA y producción instaladas a la vez (Fase 6).
