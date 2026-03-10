# ═══════════════════════════════════════════════════
# DataCoiff Pro — Alertes email stock bas
# Tourne chaque soir à 22h (tous les salons)
# ═══════════════════════════════════════════════════

library(DBI)
library(RPostgres)
library(dplyr)
library(blastula)

# ── CONFIG EMAIL ─────────────────────────────────────
EMAIL_EXPEDITEUR <- Sys.getenv("EMAIL_EXPEDITEUR")   # ← défini dans GitHub Secrets
EMAIL_MOT_PASSE  <- Sys.getenv("EMAIL_MOT_PASSE")    # ← défini dans GitHub Secrets

# ── CONNEXION SUPABASE ───────────────────────────────
get_con <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host     = "aws-1-eu-west-3.pooler.supabase.com",
    dbname   = "postgres",
    user     = "postgres.pimcseyoccjlmzwfpvgz",
    password = Sys.getenv("SUPABASE_PASSWORD"),
    port     = 5432,
    sslmode  = "require"
  )
}

# ── FONCTION ENVOI EMAIL ─────────────────────────────
envoyer_alerte <- function(email_destinataire, nom_salon, produits_alertes) {

  # Construction du tableau produits
  lignes_produits <- paste0(
    sapply(1:nrow(produits_alertes), function(i) {
      p <- produits_alertes[i, ]
      emoji <- if (p$stock_actuel == 0) "🔴" else "🟠"
      paste0(emoji, " <strong>", p$produit, "</strong> — ",
             "Stock actuel : <strong>", p$stock_actuel, "</strong> ",
             "(minimum : ", p$stock_minimum, ")")
    }),
    collapse = "<br>"
  )

  # Corps de l'email HTML
  corps_email <- paste0("
    <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>

      <div style='background: linear-gradient(135deg, #7c3aed, #a855f7);
                  padding: 30px; border-radius: 12px 12px 0 0; text-align: center;'>
        <h1 style='color: white; margin: 0; font-size: 1.5rem;'>✂️ DataCoiff Pro</h1>
        <p style='color: rgba(255,255,255,0.85); margin: 8px 0 0;'>Alerte stock</p>
      </div>

      <div style='background: #f8f9fa; padding: 30px; border-radius: 0 0 12px 12px;'>
        <h2 style='color: #1a1a2e; font-size: 1.1rem;'>
          Bonjour ", nom_salon, " 👋
        </h2>
        <p style='color: #555;'>
          Les produits suivants nécessitent votre attention :
        </p>

        <div style='background: white; border-left: 4px solid #7c3aed;
                    border-radius: 8px; padding: 20px; margin: 20px 0;
                    line-height: 2;'>
          ", lignes_produits, "
        </div>

        <p style='color: #555;'>
          Pensez à commander ces produits rapidement pour éviter les ruptures de stock.
        </p>

        <div style='text-align: center; margin-top: 30px;'>
          <p style='color: #999; font-size: 0.8rem;'>
            — DataCoiff Pro, un produit Flavio Consulting<br>
            Ce message est envoyé automatiquement chaque soir.
          </p>
        </div>
      </div>

    </div>
  ")

  # Création et envoi email
  email <- compose_email(body = md(corps_email))

  smtp_send(
    email,
    to      = email_destinataire,
    from    = EMAIL_EXPEDITEUR,
    subject = paste0("⚠️ Alerte stock — ", nom_salon),
    credentials = creds_anonymous(
      host = "smtp.gmail.com",
      port = 587,
      use_ssl = FALSE
    )
  )

  cat("✅ Email envoyé à", email_destinataire, "pour", nom_salon, "\n")
}

# ── SCRIPT PRINCIPAL ─────────────────────────────────
cat("═══════════════════════════════════\n")
cat("DataCoiff Pro — Vérification stock\n")
cat(format(Sys.time(), "%d/%m/%Y %H:%M"), "\n")
cat("═══════════════════════════════════\n\n")

con <- get_con()
on.exit(dbDisconnect(con))

# Récupère tous les salons actifs
salons <- dbGetQuery(con, "SELECT id, nom, email FROM salons WHERE actif = true")

cat("Salons actifs trouvés :", nrow(salons), "\n\n")

# Pour chaque salon
for (i in 1:nrow(salons)) {

  salon <- salons[i, ]
  cat("Vérification :", salon$nom, "...\n")

  # Produits sous le seuil minimum
  produits_alertes <- dbGetQuery(con, sprintf(
    "SELECT produit, stock_actuel, stock_minimum
     FROM stock
     WHERE salon_id = %d AND stock_actuel <= stock_minimum
     ORDER BY stock_actuel ASC",
    salon$id
  ))

  if (nrow(produits_alertes) == 0) {
    cat("  ✅ Stock OK — aucune alerte\n")
  } else {
    cat("  ⚠️", nrow(produits_alertes), "produit(s) en alerte\n")

    tryCatch({
      envoyer_alerte(
        email_destinataire = salon$email,
        nom_salon          = salon$nom,
        produits_alertes   = produits_alertes
      )
    }, error = function(e) {
      cat("  ❌ Erreur envoi email :", conditionMessage(e), "\n")
    })
  }
  cat("\n")
}

cat("═══════════════════════════════════\n")
cat("Vérification terminée.\n")
cat("═══════════════════════════════════\n")
