# Historial de MSW-31

- 2026-11-05 12:18: Estado: Por hacer -> En curso
- 2026-11-05 12:18: Start on updated develop. Plan: trace digitized chord flow into the editor, validate every chord with the music engine, expose invalid chords for review, and add validity percentage with focused tests.
- 2026-11-05 12:24: Implemented chord validation with the music engine, highlighted invalid chords in the AI review, and added validity percentage. flutter analyze clean; flutter test 107/107 passed.
- 2026-11-05 12:25: Estado: En curso -> En pruebas
- 2026-11-05 12:28: Pruebas independientes: flutter analyze sin issues; flutter test: 107/107 aprobadas. Los casos validan Hx como acorde inválido, el cálculo 1/2 = 50%, el 0% sin acordes y el resaltado de revisión en UI.
- 2026-11-05 12:28: Estado: En pruebas -> En verificación
- 2026-11-05 12:42: Independent verification: APROBADO. Chord.parse validates every AI chord; Hx renders with warning styling and review label. Percentage is computed from valid/total chord counts, including the zero-chord case. flutter analyze clean; flutter test 107/107 passed.

## Resumen

Se valida cada acorde recibido durante la digitalización con el motor musical. Los acordes inválidos se resaltan para revisión y se informa la proporción de acordes válidos.

## Rama y commits

- Rama: `feature/MSW-31`
- `3cfb62b MSW-31: validate digitized song chords`
- `bd8d0ea MSW-31: record verification and Luis test steps`

## Cambios principales

- `DigitizedChord` usa `Chord.parse` para identificar acordes aceptados por el motor.
- La vista de revisión marca acordes inválidos, como `Hx`, con una alerta y la indicación «revisar».
- Se muestra el total de acordes válidos y su porcentaje; sin acordes detectados, el porcentaje es 0%.

## Resultado de pruebas

- `flutter analyze`: sin problemas.
- `flutter test`: 107/107 aprobadas.
- Cobertura específica: acorde inválido `Hx`, cálculo de 1/2 = 50%, caso sin acordes y aviso visual.

## Verificación

APROBADO. La verificación independiente confirmó que los acordes pasan por `Chord.parse`, que los inválidos quedan marcados en la revisión y que el porcentaje coincide con el conteo.

## Decisiones tomadas

- Se reutiliza `Chord.parse` como fuente de verdad para la validez, sin duplicar las reglas de acordes.
- Los acordes detectados se muestran para revisión antes de continuar al editor.

## Pendientes y riesgos

- Luis debe completar la comprobación visual manual en la app con una foto de prueba.

## Cómo probar (Luis)

1. Abre la captura/digitalización de una canción y analiza una foto de prueba con IA.
2. En la pantalla de revisión, verifica que los acordes dudosos estén resaltados; por ejemplo, un acorde inválido como `Hx` debe indicar «revisar».
3. Comprueba el resumen de acordes válidos y su porcentaje.
- 2026-11-05 12:43: Estado: En verificación -> Listo para prueba de Luis
- 2026-11-05 13:57: Corregido envío móvil: el cliente declara el MIME real (JPEG, PNG, WebP, HEIC/HEIF) en multipart y el backend identifica application/octet-stream por firma. Pruebas: backend 18/18, flutter analyze limpio y flutter test 108/108.
- 2026-11-05 13:57: Estado: Listo para prueba de Luis -> En pruebas
- 2026-11-05 14:10: Estado: En pruebas -> En verificación
- 2026-11-05 14:10: Independent verification: APPROVED. Validated mobile upload MIME detection and HEIC support. All 18 backend tests passed, flutter analyze clean, 108/108 flutter tests passed.
- 2026-11-05 14:10: Estado: En verificación -> Listo para prueba de Luis
- 2026-11-05 14:10: Ticket completed and verified. Ready for Luis approval.
- 2026-11-05 14:10: Estado: Listo para prueba de Luis -> Hecho
- 2026-11-05 14:10: Completed and closed by Luis.
