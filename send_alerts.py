# DataCoiff Pro — Envoi emails alertes stock
import csv
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from collections import defaultdict

EMAIL_EXPEDITEUR = os.environ["EMAIL_EXPEDITEUR"]
EMAIL_MOT_PASSE  = os.environ["EMAIL_MOT_PASSE"]

# Lecture du CSV
alertes_par_salon = defaultdict(list)
try:
    with open("alertes.csv", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row["salon_nom"]:
                alertes_par_salon[(row["salon_nom"], row["salon_email"])].append(row)
except Exception as e:
    print(f"Erreur lecture CSV: {e}")
    exit(0)

if not alertes_par_salon:
    print("Aucune alerte a envoyer.")
    exit(0)

# Connexion SMTP
try:
    smtp = smtplib.SMTP("smtp.gmail.com", 587)
    smtp.starttls()
    smtp.login(EMAIL_EXPEDITEUR, EMAIL_MOT_PASSE)
except Exception as e:
    print(f"Erreur connexion Gmail: {e}")
    exit(1)

# Envoi email par salon
for (nom_salon, email_salon), produits in alertes_par_salon.items():
    print(f"Envoi email a {email_salon} pour {nom_salon}...")

    lignes = ""
    for p in produits:
        statut = "RUPTURE" if int(p["stock_actuel"]) == 0 else "BAS"
        couleur = "#ef4444" if int(p["stock_actuel"]) == 0 else "#f97316"
        lignes += f"""
        <tr>
          <td style='padding:10px;border-bottom:1px solid #eee;'>{p['produit']}</td>
          <td style='padding:10px;border-bottom:1px solid #eee;text-align:center;color:{couleur};font-weight:bold;'>{statut}</td>
          <td style='padding:10px;border-bottom:1px solid #eee;text-align:center;'>{p['stock_actuel']}</td>
          <td style='padding:10px;border-bottom:1px solid #eee;text-align:center;'>{p['stock_minimum']}</td>
        </tr>"""

    corps_html = f"""
<!DOCTYPE html><html><body style='margin:0;padding:0;background:#f4f4f4;font-family:Arial,sans-serif;'>
<div style='max-width:600px;margin:30px auto;background:white;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.1);'>
  <div style='background:linear-gradient(135deg,#7c3aed,#a855f7);padding:30px;text-align:center;'>
    <h1 style='color:white;margin:0;'>DataCoiff Pro</h1>
    <p style='color:rgba(255,255,255,0.85);margin:8px 0 0;'>Alerte stock automatique</p>
  </div>
  <div style='padding:30px;'>
    <h2 style='color:#1a1a2e;'>Bonjour {nom_salon},</h2>
    <p style='color:#555;'>Les produits suivants necessitent votre attention :</p>
    <table style='width:100%;border-collapse:collapse;margin:20px 0;'>
      <thead><tr style='background:#7c3aed;color:white;'>
        <th style='padding:10px;text-align:left;'>Produit</th>
        <th style='padding:10px;'>Statut</th>
        <th style='padding:10px;'>Stock actuel</th>
        <th style='padding:10px;'>Minimum</th>
      </tr></thead>
      <tbody>{lignes}</tbody>
    </table>
    <p style='color:#555;'>Pensez a commander ces produits rapidement.</p>
  </div>
  <div style='background:#f8f9fa;padding:15px;text-align:center;'>
    <p style='color:#999;font-size:0.8rem;margin:0;'>DataCoiff Pro - Un produit Flavio Consulting</p>
  </div>
</div></body></html>"""

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"Alerte stock - {nom_salon}"
    msg["From"]    = EMAIL_EXPEDITEUR
    msg["To"]      = email_salon
    msg.attach(MIMEText(corps_html, "html"))

    try:
        smtp.sendmail(EMAIL_EXPEDITEUR, email_salon, msg.as_string())
        print(f"  Email envoye !")
    except Exception as e:
        print(f"  Erreur: {e}")

smtp.quit()
print("\nTermine.")
