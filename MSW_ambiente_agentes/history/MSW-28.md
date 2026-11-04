# Historial de MSW-28

- 2026-10-30 00:44: Estado: Por hacer -> En curso
- 2026-10-30 00:44: Iniciado desde develop actualizado a origin/develop (98c4fc2), con la dependencia MSW-21 disponible.
- 2026-10-30 00:51: Estado: En curso -> Listo para prueba de Luis
- 2026-10-30 00:51: Implementada captura desde cámara o galería con ImagePicker, recorte guiado con ImageCropper, mensajes de permiso/alternativa, guardado persistente en documentos de la app y vínculo photoPath en SongRepository con migración Drift 3->4. Validado con flutter analyze, flutter test (91), dart build_runner y flutter build macos --debug; hot restart exitoso.
- 2026-11-04 14:36: Ajustado flujo de captura para procesar fotos de forma temporal sin persistir rutas absolutas en BD ni mostrar 'Foto guardada'; la foto recortada queda lista como entrada para OCR (MSW-29). Validado con flutter clean, flutter analyze y 91 tests aprobados.
- 2026-11-04 17:46: Estado: Listo para prueba de Luis -> Hecho
