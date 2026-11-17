#!/usr/bin/env python3
"""Agent IA d'assistance informatique pour PME (Python, aucune dependance a installer).

L'agent comprend une demande en langage naturel, CHOISIT lui-meme l'outil adapte,
l'execute, puis repond. Les actions qui ECRIVENT (creer un ticket) demandent votre confirmation.

Outils : verifier_site | diagnostic_machine | lire_echeances | creer_ticket

Usage :
  export GEMINI_API_KEY="votre_cle"        # cle gratuite : aistudio.google.com
  python3 agent-it.py                      # discussion avec l'agent
  python3 agent-it.py --mock               # SANS cle ni internet : test de la mecanique des outils
Option : GEMINI_MODEL (defaut gemini-2.5-flash ; verifiez le nom actuel dans Google AI Studio)
"""
import csv, json, os, shutil, sys, time, urllib.error, urllib.request
from datetime import date, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
API_KEY = os.getenv("GEMINI_API_KEY", "")
MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
TICKETS = os.path.join(HERE, "tickets-agent.csv")
ECHEANCES = os.getenv("ECHEANCES_CSV", os.path.join(HERE, "echeances-demo.csv"))
MOCK = "--mock" in sys.argv
AUTO_YES = "--yes" in sys.argv
MAX_STEPS = 6

SYSTEM = (
    "Tu es un assistant informatique pour une PME a Madagascar. Reponds dans la langue de l'utilisateur "
    "(francais par defaut), de facon courte et concrete. Utilise les outils quand c'est utile, n'invente jamais "
    "de resultat : si un outil echoue, dis-le. Pour un probleme que tu ne peux pas resoudre toi-meme, propose de creer "
    "un ticket. Ne demande jamais de mot de passe."
)

# ---------------------------- OUTILS ----------------------------
def verifier_site(url):
    if not str(url).startswith(("http://", "https://")):
        return {"erreur": "URL invalide : doit commencer par http:// ou https://"}
    t0 = time.time()
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "agent-it"}), timeout=8) as r:
            return {"url": url, "en_ligne": True, "code_http": r.status, "temps_ms": int((time.time() - t0) * 1000)}
    except urllib.error.HTTPError as e:
        return {"url": url, "en_ligne": e.code < 500, "code_http": e.code}
    except Exception as e:
        return {"url": url, "en_ligne": False, "erreur": str(e)[:150]}

def diagnostic_machine():
    du = shutil.disk_usage("/")
    out = {"disque_utilise_pct": round(100 * du.used / du.total), "disque_libre_go": round(du.free / 1e9, 1)}
    try:
        m = {l.split(":")[0]: int(l.split()[1]) for l in open("/proc/meminfo")}
        out["memoire_utilisee_pct"] = round(100 * (m["MemTotal"] - m["MemAvailable"]) / m["MemTotal"])
    except Exception:
        out["memoire_utilisee_pct"] = "non disponible"
    try:
        out["charge_cpu_1min"] = os.getloadavg()[0]
    except Exception:
        pass
    return out

def lire_echeances(jours=30):
    today, res = date.today(), []
    try:
        with open(ECHEANCES, newline="", encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r["Statut"].strip().lower().startswith("fait"):
                    continue
                d = (datetime.strptime(r["DateEcheance"].strip(), "%Y-%m-%d").date() - today).days
                if d <= int(jours):
                    res.append({"element": r["Element"], "responsable": r["Responsable"], "montant_ar": r["Montant"],
                                "jours_restants": d, "etat": "EN RETARD" if d < 0 else "a venir"})
    except FileNotFoundError:
        return {"erreur": "fichier d'echeances introuvable"}
    return {"echeances": sorted(res, key=lambda x: x["jours_restants"])}

def creer_ticket(demandeur, probleme, priorite):
    if priorite not in ("Basse", "Moyenne", "Haute", "Critique"):
        priorite = "Moyenne"
    new = not os.path.exists(TICKETS)
    num = "TK-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    with open(TICKETS, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["Numero", "Date", "Demandeur", "Probleme", "Priorite", "Statut"])
        w.writerow([num, date.today().isoformat(), demandeur, probleme, priorite, "Ouvert"])
    return {"ticket": num, "statut": "Ouvert"}

TOOLS = {"verifier_site": verifier_site, "diagnostic_machine": diagnostic_machine,
         "lire_echeances": lire_echeances, "creer_ticket": creer_ticket}
WRITE_TOOLS = {"creer_ticket"}   # actions qui modifient quelque chose : confirmation humaine obligatoire

DECLS = [
    {"name": "verifier_site", "description": "Verifie si un site web ou service HTTP est en ligne (code HTTP, temps de reponse).",
     "parameters": {"type": "OBJECT", "properties": {"url": {"type": "STRING", "description": "URL complete, ex: https://example.com"}}, "required": ["url"]}},
    {"name": "diagnostic_machine", "description": "Donne l'etat de la machine locale : disque, memoire, charge CPU.",
     "parameters": {"type": "OBJECT", "properties": {}}},
    {"name": "lire_echeances", "description": "Liste les echeances administratives (factures, contrats, renouvellements) en retard ou proches.",
     "parameters": {"type": "OBJECT", "properties": {"jours": {"type": "INTEGER", "description": "Horizon en jours (defaut 30)"}}}},
    {"name": "creer_ticket", "description": "Cree un ticket de support. Demande confirmation a l'utilisateur.",
     "parameters": {"type": "OBJECT", "properties": {
         "demandeur": {"type": "STRING"}, "probleme": {"type": "STRING"},
         "priorite": {"type": "STRING", "description": "Basse, Moyenne, Haute ou Critique"}}, "required": ["demandeur", "probleme", "priorite"]}},
]

# ---------------------------- LLM ----------------------------
def call_gemini(contents):
    body = {"systemInstruction": {"parts": [{"text": SYSTEM}]}, "contents": contents,
            "tools": [{"functionDeclarations": DECLS}], "generationConfig": {"temperature": 0.2}}
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": API_KEY})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)["candidates"][0]["content"]
    except urllib.error.HTTPError as e:
        sys.exit(f"Erreur API {e.code} : {e.read().decode()[:400]}")

def call_mock(contents):
    """Faux LLM pour tester la mecanique sans cle : decide selon des mots-cles."""
    last = contents[-1]
    if last["role"] == "user" and "text" in last["parts"][0]:
        t = last["parts"][0]["text"].lower()
        if "echeance" in t:
            return {"role": "model", "parts": [{"functionCall": {"name": "lire_echeances", "args": {"jours": 30}}}]}
        if "site" in t or "http" in t:
            return {"role": "model", "parts": [{"functionCall": {"name": "verifier_site", "args": {"url": "http://127.0.0.1:9"}}}]}
        if "lent" in t or "ordinateur" in t:
            return {"role": "model", "parts": [{"functionCall": {"name": "diagnostic_machine", "args": {}}}]}
        if "ticket" in t:
            return {"role": "model", "parts": [{"functionCall": {"name": "creer_ticket",
                    "args": {"demandeur": "Utilisateur demo", "probleme": "Probleme decrit a l'agent (mock)", "priorite": "Haute"}}}]}
        return {"role": "model", "parts": [{"text": "[MOCK] Je n'ai pas compris. Essayez : echeances, site, ordinateur lent, ticket."}]}
    res = json.dumps([p["functionResponse"]["response"] for p in last["parts"]], ensure_ascii=False)[:500]
    return {"role": "model", "parts": [{"text": "[MOCK] Resultat de l'outil : " + res}]}

# ---------------------------- BOUCLE AGENT ----------------------------
def run_agent(contents):
    for _ in range(MAX_STEPS):
        msg = call_mock(contents) if MOCK else call_gemini(contents)
        contents.append(msg)           # on conserve le message du modele tel quel
        calls = [p["functionCall"] for p in msg.get("parts", []) if "functionCall" in p]
        if not calls:
            return "".join(p.get("text", "") for p in msg.get("parts", [])).strip() or "(pas de reponse)"
        results = []
        for c in calls:
            name, args = c["name"], c.get("args", {}) or {}
            print(f"  -> outil : {name}({json.dumps(args, ensure_ascii=False)})")
            if name not in TOOLS:
                out = {"erreur": "outil inconnu"}
            elif name in WRITE_TOOLS and not AUTO_YES and input("  ? Confirmer cette action (o/n) : ").strip().lower() not in ("o", "oui", "y"):
                out = {"erreur": "action refusee par l'utilisateur"}
            else:
                try:
                    out = TOOLS[name](**args)
                except Exception as e:
                    out = {"erreur": f"{type(e).__name__}: {e}"}
            results.append({"functionResponse": {"name": name, "response": out}})
        contents.append({"role": "user", "parts": results})
    return "Je n'ai pas pu terminer (trop d'etapes)."

def main():
    if not MOCK and not API_KEY:
        sys.exit("GEMINI_API_KEY manquante. Obtenez une cle gratuite sur aistudio.google.com, ou testez avec --mock")
    print("Agent IT" + (" [MODE MOCK]" if MOCK else f" [{MODEL}]") + " - tapez 'q' pour quitter.")
    contents = []
    while True:
        try:
            q = input("\nVous : ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if q.lower() in ("q", "quit", "exit"):
            break
        if not q:
            continue
        contents.append({"role": "user", "parts": [{"text": q}]})
        print("Agent :", run_agent(contents))

if __name__ == "__main__":
    main()
