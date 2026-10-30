# MusicSundayWorship (MSW)

App móvil en Flutter para músicos de iglesia. Digitaliza canciones con acordes desde una foto, las transpone, arma playlists y medleys y guía el ensayo con metrónomo. Documentación en `docs/`.

## Cómo se trabaja aquí

El trabajo se organiza en tickets que viven en `backlog/backlog.csv`. No hay Jira: los agentes leen y actualizan ese archivo con la herramienta `tool/ticket.py`. Nunca edites el CSV a mano.

Cuando Luis diga "vamos a hacer MSW-15" (o use `/ticket MSW-15`), se sigue el flujo del comando `/ticket`.

## Reglas

- Responde a Luis en español, con lenguaje simple.
- Lee el ticket completo con `python3 tool/ticket.py show MSW-n` antes de hacer nada.
- Cada ticket se trabaja en una rama `feature/MSW-n` creada desde `develop`. Los commits empiezan con la clave: `MSW-15: agrega transposición entre tonos`.
- No hagas `git push` ni cambies de rama de `qa` o `develop` sin pedirlo. Solo commits locales.
- Ningún agente pasa un ticket a `Hecho`. Solo Luis lo hace, con `--luis`.
- Si falta información o hay una dependencia sin cerrar, pasa el ticket a `Bloqueado`, explica qué falta y detente.
- No inventes resultados: si una prueba no se pudo ejecutar, dilo.
- No subas fotos ni archivos personales al repositorio.

## Código

- Flutter 3.47.8, Riverpod, go_router, Drift. Decisiones en `docs/DECISIONES_TECNICAS.md`.
- El motor musical (`lib/music_engine/`) es Dart puro, sin importar Flutter.
- Antes de dar algo por terminado: `flutter analyze` y `flutter test` sin errores.
- Todo cambio sugerido por IA dentro de la app requiere confirmación del usuario.
- El contenido de las canciones lo carga el usuario; cada canción lleva autor y fuente. La app no descarga contenido de sitios externos.

## Estados de un ticket

Por hacer, En curso, En pruebas, En verificación, Listo para prueba de Luis, Hecho, Bloqueado.
