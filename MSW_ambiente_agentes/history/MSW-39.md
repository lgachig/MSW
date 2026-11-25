# Historial de MSW-39

- 2026-11-24 21:34: Estado: Por hacer -> En curso
- 2026-11-24 21:34: Iniciando MSW-39: Modo ensayo con avance automático. Plan: 1) Motor de cálculo de compases y avance rítmico (RehearsalFlowController). 2) Pantalla completa de ensayo con sección actual, siguiente y resaltado de compás/acordes. 3) Controles de pausa/reanudación sin pérdida de tiempo, salto entre secciones y ajuste de BPM. 4) Modo pantalla encendida.
- 2026-11-24 21:41: Implementación completada: 1) RehearsalSongPlan calcula compases y expande repeticiones. 2) RehearsalFlowController gestiona avance al compás, pausa/reanudación sin perder tiempo, saltos y cambio de BPM. 3) RehearsalPage proporciona modo ensayo a pantalla completa con sección actual, aviso de siguiente sección, resaltado de acorde activo, roadmap interactivo y toggle de pantalla encendida. 4) Integrado en SongDetailPage con botón en AppBar y FAB. 5) Pruebas rítmicas con reloj simulado y pruebas de widgets implementadas.
