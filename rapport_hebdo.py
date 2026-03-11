# rapport_hebdo.py — Rapport hebdomadaire automatique
# Mettre dans GitHub Actions : tous les lundis à 8h

import os
import psycopg2
from datetime import date, timedelta
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

DB_PASSWORD = os.environ["SUPABASE_PASSWORD"]
EMAIL_FROM  = os.environ["EMAIL_EXPEDITEUR"]
EMAIL_PASS  = os.environ["EMAIL_MOT_PASSE"]

conn = psycopg2.connect(
    host="aws-1-eu-west-3.pooler.supabase.com",
    dbname="postgres",
    user="postgres.pimcseyoccjlmzwfpvgz",
    password=DB_PASSWORD,
    port=5432,
    sslmode="require"
)
cur = conn.cursor()

# Semaine dernière
fin   = date.today() - timedelta(days=1)
debut = fin - timedelta(days=6)

cur.execute("""
    SELECT s.nom, s.email,
           COALESCE(SUM(v.prix),0) as ca,
           COUNT(v.id) as nb
    FROM salons s
    LEFT JOIN ventes v ON v.salon_id = s.id
        AND v.date BETWEEN %s AND %s
    WHERE s.actif = true
    GROUP BY s.id, s.nom, s.email
""", (debut, fin))

salons = cur.fetchall()

for nom_salon, email_salon, ca, nb in salons:
    if not email_salon:
        continue

    panier = round(ca / nb, 2) if nb > 0 else 0

    html = f"""
    <html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;">
    <div style="background:#12122a;padding:30px;border-radius:16px;text-align:center;margin-bottom:20px;">
      <h1 style="color:#ffffff;font-size:1.5rem;margin:0;">✂️ DataCoiff Pro</h1>
      <p style="color:#8888aa;margin:8px 0 0;">Rapport de la semaine</p>
    </div>
    <h2 style="color:#333;">Bonjour {nom_salon} 👋</h2>
    <p style="color:#666;">Voici votre résumé pour la semaine du <b>{debut.strftime('%d/%m/%Y')}</b> au <b>{fin.strftime('%d/%m/%Y')}</b> :</p>

    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin:24px 0;">
      <div style="background:#f8f4ff;border:2px solid #7850ff;border-radius:12px;padding:20px;text-align:center;">
        <div style="font-size:1.8rem;font-weight:700;color:#7850ff;">{round(ca, 0)} €</div>
        <div style="color:#666;font-size:0.85rem;margin-top:4px;">Chiffre d'affaires</div>
      </div>
      <div style="background:#f0fdf9;border:2px solid #00c896;border-radius:12px;padding:20px;text-align:center;">
        <div style="font-size:1.8rem;font-weight:700;color:#00c896;">{nb}</div>
        <div style="color:#666;font-size:0.85rem;margin-top:4px;">Prestations</div>
      </div>
      <div style="background:#eff6ff;border:2px solid #3b82f6;border-radius:12px;padding:20px;text-align:center;">
        <div style="font-size:1.8rem;font-weight:700;color:#3b82f6;">{panier} €</div>
        <div style="color:#666;font-size:0.85rem;margin-top:4px;">Panier moyen</div>
      </div>
    </div>

    <div style="text-align:center;margin-top:30px;">
      <a href="https://flavioconsulting.shinyapps.io/datacoiff-pro/"
         style="background:linear-gradient(135deg,#7850ff,#5b21b6);color:#fff;padding:14px 30px;border-radius:8px;text-decoration:none;font-weight:600;">
        Voir mon tableau de bord →
      </a>
    </div>
    <p style="color:#999;font-size:0.8rem;text-align:center;margin-top:30px;">
      DataCoiff Pro · <a href="mailto:contact@flavioconsulting.fr" style="color:#999;">contact@flavioconsulting.fr</a>
    </p>
    </body></html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"📊 Votre semaine chez {nom_salon} — {debut.strftime('%d/%m')} au {fin.strftime('%d/%m/%Y')}"
    msg["From"]    = EMAIL_FROM
    msg["To"]      = email_salon
    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
        smtp.login(EMAIL_FROM, EMAIL_PASS)
        smtp.sendmail(EMAIL_FROM, email_salon, msg.as_string())
    print(f"✅ Rapport envoyé à {nom_salon} ({email_salon})")

cur.close()
conn.close()
