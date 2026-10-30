---
description: Ejecuta un ticket del backlog con los agentes (desarrollo, pruebas, verificación e historial). Uso: /ticket MSW-15
argument-hint: MSW-15
---

Vas a ejecutar el ticket **$ARGUMENTS** como orquestador. Si no se indicó ticket, ejecuta `python3 tool/ticket.py next`, propón el resultado a Luis y espera su confirmación.

## Flujo

1. **Leer.** Ejecuta `python3 tool/ticket.py show $ARGUMENTS` y lee todo. Comprueba que las dependencias (campo "Depende de") estén en Hecho, En pruebas o Listo para prueba de Luis, y que el repositorio esté limpio (`git status`). Si falta algo, ejecuta `python3 tool/ticket.py status $ARGUMENTS Bloqueado`, registra el motivo con `log` y detente.
2. **Preparar.** Crea la rama `feature/$ARGUMENTS` desde `develop`. Ejecuta `python3 tool/ticket.py status $ARGUMENTS "En curso"` y registra el plan en una línea con `log`.
3. **Desarrollar.** Lanza el agente `desarrollador` con el ticket completo. Al terminar, exige un resumen de qué hizo.
4. **Probar.** Ejecuta `status $ARGUMENTS "En pruebas"` y lanza el agente `pruebas`. Si falla, devuelve el error exacto al `desarrollador` y repite (máximo 3 vueltas; si no se resuelve, pasa a Bloqueado y explica).
5. **Verificar.** Ejecuta `status $ARGUMENTS "En verificación"` y lanza el agente `verificador`, que no debe haber participado en el desarrollo. Si algún criterio no se cumple, vuelve al paso 3.
6. **Cerrar.** Lanza el agente `historiador`, que escribe el historial y deja el ticket en "Listo para prueba de Luis".
7. **Entregar a Luis.** Muéstrale en pocas líneas: qué se hizo, el resultado de las pruebas, y los pasos exactos para probarlo él. Recuérdale que solo él pasa el ticket a Hecho.

## Reglas

- Cada agente registra su avance con `python3 tool/ticket.py log $ARGUMENTS "..."`.
- Nunca uses `--luis` ni marques Hecho.
- Un agente no revisa su propio trabajo: desarrollador, pruebas y verificador son agentes distintos.
