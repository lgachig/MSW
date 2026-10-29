# MusicSundayWorship (MSW)

App móvil para músicos de iglesia: digitaliza canciones con acordes desde una foto, las transpone, arma playlists y medleys, y guía el ensayo con metrónomo y estructura automática.

**Estado:** Fase 0 (descubrimiento y documentación). Borrador v0.1.
**Autor:** Luis

## Qué hace

- Foto de una canción a canción editable (letra, acordes, estructura).
- Editor de acordes sobre la letra: tocar para colocar, arrastrar para mover.
- Transposición por semitonos, notación americana y latina.
- Estructura con repeticiones e interludios (por ejemplo, coro x3).
- Playlists por servicio y medleys con puentes.
- Modo ensayo: pantalla completa, metrónomo y avance automático de secciones.

## Decisiones clave

- **Plataforma:** Flutter (Dart). Beta primero en iPhone, luego Android y tablets.
- **Datos:** offline-first. SQLite local (Drift) y fotos como archivos.
- **IA:** el análisis de la foto se hace con internet; el resultado se guarda en el teléfono.
- **Contenido:** el usuario carga sus propias canciones. Cada canción lleva autor y fuente. La app no descarga contenido de sitios externos.
- **Alcance MVP:** acordes sobre letra. Pentagramas con notas quedan fuera por ahora.

## Estructura del repositorio

```
MSW/
  docs/                      Documentación del proyecto (PDF de requerimientos)
  musicsundayworship/        App Flutter
    lib/
      core/                  Tema, utilidades, constantes
      data/                  Base de datos (Drift) y repositorios
      music_engine/          Motor musical en Dart puro (sin Flutter)
      features/
        library/             Biblioteca de canciones
        capture/             Cámara, recorte y OCR
        chord_editor/        Editor de acordes sobre la letra
        structure/           Editor de estructura y repeticiones
        playlists/           Playlists por servicio
        medleys/             Medleys y puentes
        rehearsal/           Modo ensayo y metrónomo
    test/
      music_engine/          Pruebas unitarias del motor musical
```

## Ramas

- `develop`: trabajo diario.
- `qa`: versión en pruebas (iPhone y equipo).
- `feature/nombre`: ramas cortas por funcionalidad.

Flujo: feature, luego develop, luego qa.

## Cómo correr la app

```
cd musicsundayworship
flutter pub get
flutter devices
flutter run -d <id del dispositivo>
```

Con el ID gratuito de Apple, la app instalada en el iPhone caduca a los 7 días; basta con volver a correr `flutter run`.

## Plan por fases

| Fase | Contenido | Duración |
|---|---|---|
| 0 | Descubrimiento y documentación | 1 semana |
| 1 | Motor musical y transposición | 2 semanas |
| 2 | Biblioteca y editor manual | 2 semanas |
| 3 | Captura y digitalización | 3 semanas |
| 4 | Estructura y modo ensayo | 2 semanas |
| 5 | Playlists y medleys | 3 semanas |
| 6 | Gobernanza, pulido y beta | 2 semanas |
| 7 | Portafolio | 1 semana |

Detalle completo en `docs/MusicSundayWorship_Documento_Proyecto.pdf`.
