#!/usr/bin/env python3
"""Herramienta local para leer y actualizar el backlog de MSW (sin Jira).

Uso:
  python3 tool/ticket.py list [--sprint S1] [--status "Por hacer"]
  python3 tool/ticket.py next
  python3 tool/ticket.py show MSW-15
  python3 tool/ticket.py status MSW-15 "En curso"
  python3 tool/ticket.py log MSW-15 "Texto del avance"

Los estados válidos están en STATES. El estado "Hecho" solo lo puede poner Luis,
con la opción --luis.
"""
import csv
import datetime
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "backlog", "backlog.csv")
HISTORY_DIR = os.path.join(ROOT, "history")

STATES = [
    "Por hacer",
    "En curso",
    "En pruebas",
    "En verificación",
    "Listo para prueba de Luis",
    "Hecho",
    "Bloqueado",
]


def load():
    with open(CSV_PATH, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    return rows[0], rows[1:]


def save(header, rows):
    tmp = CSV_PATH + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        w.writerows(rows)
    os.replace(tmp, CSV_PATH)


def col(header, name):
    return header.index(name)


def find(header, rows, key):
    i = col(header, "Issue Id")
    for r in rows:
        if r[i] == key:
            return r
    sys.exit(f"No existe el ticket {key}.")


def deps_of(header, row):
    desc = row[col(header, "Description")]
    m = re.search(r"\*Depende de\*\n(.+)", desc)
    return [d.strip() for d in m.group(1).split(",")] if m else []


def cmd_list(args):
    header, rows = load()
    sprint = args[args.index("--sprint") + 1] if "--sprint" in args else None
    status = args[args.index("--status") + 1] if "--status" in args else None
    ci, ct, cs, cp, cst = (col(header, n) for n in ("Issue Id", "Issue Type", "Summary", "Sprint", "Status"))
    for r in rows:
        if sprint and r[cp] != sprint:
            continue
        if status and r[cst] != status:
            continue
        print(f"{r[ci]:8} {r[ct]:6} {r[cp]:3} {r[cst]:26} {r[cs]}")


def cmd_next(_args):
    header, rows = load()
    ci, ct, cst, cp, cs = (col(header, n) for n in ("Issue Id", "Issue Type", "Status", "Sprint", "Summary"))
    state = {r[ci]: r[cst] for r in rows}
    for r in rows:
        if r[ct] == "Epic" or r[cst] != "Por hacer":
            continue
        if all(state.get(d) == "Hecho" for d in deps_of(header, r)):
            print(f"{r[ci]}  ({r[cp]})  {r[cs]}")
            return
    print("No hay tickets disponibles: revisa los que están en pruebas o esperando a Luis.")


def cmd_show(args):
    header, rows = load()
    r = find(header, rows, args[0])
    get = lambda n: r[col(header, n)]
    print(f"{get('Issue Id')} | {get('Issue Type')} | {get('Priority')} | Sprint {get('Sprint')} | "
          f"Puntos {get('Story Points')} | Estado: {get('Status')}")
    print(f"Épica: {get('Parent Id')}")
    print(f"Resumen: {get('Summary')}")
    print()
    print(get("Description"))
    hist = os.path.join(HISTORY_DIR, f"{args[0]}.md")
    if os.path.exists(hist):
        print("\n--- Historial hasta ahora ---")
        print(open(hist, encoding="utf-8").read())


def append_log(key, text):
    os.makedirs(HISTORY_DIR, exist_ok=True)
    path = os.path.join(HISTORY_DIR, f"{key}.md")
    new = not os.path.exists(path)
    with open(path, "a", encoding="utf-8") as f:
        if new:
            f.write(f"# Historial de {key}\n\n")
        stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        f.write(f"- {stamp}: {text}\n")


def cmd_status(args):
    luis = "--luis" in args
    args = [a for a in args if a != "--luis"]
    key, new = args[0], args[1]
    if new not in STATES:
        sys.exit(f"Estado inválido. Usa uno de: {', '.join(STATES)}")
    if new == "Hecho" and not luis:
        sys.exit("Solo Luis puede pasar un ticket a Hecho.")
    header, rows = load()
    r = find(header, rows, key)
    cst = col(header, "Status")
    old = r[cst]
    r[cst] = new
    save(header, rows)
    append_log(key, f"Estado: {old} -> {new}")
    print(f"{key}: {old} -> {new}")


def cmd_log(args):
    key, text = args[0], " ".join(args[1:])
    header, rows = load()
    find(header, rows, key)
    append_log(key, text)
    print(f"Registrado en history/{key}.md")


COMMANDS = {"list": cmd_list, "next": cmd_next, "show": cmd_show, "status": cmd_status, "log": cmd_log}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[sys.argv[1]](sys.argv[2:])
