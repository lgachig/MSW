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
| Commits | Mensajes cortos en inglés y con la clave del ticket, por ejemplo `MSW-15: add transposition between keys`. | Historial legible y asociado al ticket. |
| OCR en dispositivo | Google ML Kit (`google_mlkit_text_recognition`) en alfabeto latino | Funciona 100% offline en el dispositivo, es multiplataforma para iOS y Android (manteniendo una sola base de código) y provee coordenadas exactas (boundingBox) por bloque, línea y palabra para clasificar acordes y letra. |
| Digitalización con IA | FastAPI en servidor + Google Gemini (`gemini-3.5-flash`) por defecto, con OpenAI Responses API opcional; salida JSON estructurada | Las claves del proveedor permanecen en variables de entorno del servidor; Gemini admite rotación de claves ante errores de autenticación o cuota. La app solo conoce la URL del servicio. El límite diario se controla por IP y se configura en servidor. |

## Pendiente de decidir más adelante

- Paquete de audio para el metrónomo de baja latencia (Fase 4).
- Flavors de Flutter para tener QA y producción instaladas a la vez (Fase 6).
