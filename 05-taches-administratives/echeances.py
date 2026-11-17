#!/usr/bin/env python3
"""Rappel d'echeances a partir d'un fichier CSV (version hors-ligne de la demo 5).
Usage : python3 echeances.py echeances-demo.csv
Pour envoyer sur Telegram : TG_TOKEN=... TG_CHAT_ID=... python3 echeances.py echeances-demo.csv
"""
import csv, os, sys, urllib.parse, urllib.request
from datetime import date, datetime

path = sys.argv[1] if len(sys.argv) > 1 else "echeances-demo.csv"
today = date.today()
late, urgent, soon = [], [], []
with open(path, newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        if r["Statut"].strip().lower().startswith("fait"):
            continue
        d = datetime.strptime(r["DateEcheance"].strip(), "%Y-%m-%d").date()
        days = (d - today).days
        line = f"• {r['Element']} - {r['Responsable']} - {int(float(r['Montant'] or 0)):,} Ar".replace(",", " ")
        if days < 0: late.append(f"{line} (retard {-days} j)")
        elif days <= 7: urgent.append(f"{line} (dans {days} j)")
        elif days <= 30: soon.append(f"{line} (dans {days} j)")

parts = []
if late: parts.append("🔴 EN RETARD\n" + "\n".join(late))
if urgent: parts.append("🟠 URGENT (7 jours)\n" + "\n".join(urgent))
if soon: parts.append("🟡 A PREVOIR (30 jours)\n" + "\n".join(soon))
msg = "📋 Echeances du " + today.strftime("%d/%m/%Y") + "\n\n" + "\n\n".join(parts) if parts else "Aucune echeance proche."
print(msg)

tok, chat = os.getenv("TG_TOKEN"), os.getenv("TG_CHAT_ID")
if tok and chat:
    data = urllib.parse.urlencode({"chat_id": chat, "text": msg}).encode()
    urllib.request.urlopen(f"https://api.telegram.org/bot{tok}/sendMessage", data, timeout=10)
    print("\n[Envoye sur Telegram]")
