# ═══════════════════════════════════════════════════
# DataCoiff Pro — Alertes email stock bas
# Tourne chaque soir a 22h (tous les salons)
# ═══════════════════════════════════════════════════

library(DBI)
library(RPostgres)
library(dplyr)
library(emayili)

# CONFIG EMAIL
EMAIL_EXPEDITEUR <- Sys.getenv("EMAIL_EXPEDITEUR")
EMAIL_MOT_PASSE  <- Sys.getenv("EMAIL_MOT_PASSE")

# CONNEXION SUPABASE
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

# FONCTION ENVOI EMAIL
envoyer_alerte <- function(email_destinataire, nom_salon, produits_alertes) {

  lignes_produits <- paste0(
    sapply(1:nrow(produits_alertes), function(i) {
      p <- produits_alertes[i, ]
      statut <- if (p$stock_actuel == 0) "RUPTURE" else "BAS"
      couleur <- if (p$stock_actuel == 0) "#ef4444" else "#f97316"
      paste0(
        "<tr>",
        "<td style='padding:10px;border-bottom:1px solid #eee;'>", p$produit, "</td>",
        "<td style='padding:10px;border-bottom:1px solid #eee;text-align:center;color:", couleur, ";font-weight:bold;'>", statut, "</td>",
        "<td style='padding:10px;border-bottom:1px solid #eee;text-align:center;'>", p$stock_actuel, "</td>",
        "<td style='padding:10px;border-bottom:1px solid #eee;text-align:center;'>", p$stock_minimum, "</td>",
        "</tr>"
      )
    }),
    collapse = ""
  )

  corps_html <- paste0(
    "<!DOCTYPE html><html><body style='margin:0;padding:0;background:#f4f4f4;font-family:Arial,sans-serif;'>",
    "<div style='max-width:600px;margin:30px auto;background:white;border-radius:12px;overflow:hidden;'>",
    "<div style='background:linear-gradient(135deg,#7c3aed,#a855f7);padding:30px;text-align:center;'>",
    "<h1 style='color:white;margin:0;'>DataCoiff Pro</h1>",
    "<p style='color:rgba(255,255,255,0.85);margin:8px 0 0;'>Alerte stock automatique</p>",
    "</div>",
    "<div style='padding:30px;'>",
    "<h2 style='color:#1a1a2e;'>Bonjour ", nom_salon, ",</h2>",
    "<p style='color:#555;'>Les produits suivants necessitent votre attention :</p>",
    "<table style='width:100%;border-collapse:collapse;margin:20px 0;'>",
    "<thead><tr style='background:#7c3aed;color:white;'>",
    "<th style='padding:10px;text-align:left;'>Produit</th>",
    "<th style='padding:10px;'>Statut</th>",
    "<th style='padding:10px;'>Stock actuel</th>",
    "<th style='padding:10px;'>Minimum</th>",
    "</tr></thead>",
    "<tbody>", lignes_produits, "</tbody></table>",
    "<p style='color:#555;'>Pensez a commander ces produits rapidement.</p>",
    "</div>",
    "<div style='background:#f8f9fa;padding:15px;text-align:center;'>",
    "<p style='color:#999;font-size:0.8rem;margin:0;'>DataCoiff Pro - Un produit Flavio Consulting</p>",
    "</div></div></body></html>"
  )

  smtp <- server(
    host     = "smtp.gmail.com",
    port     = 587,
    username = EMAIL_EXPEDITEUR,
    password = EMAIL_MOT_PASSE
  )

  email <- envelope() |>
    from(EMAIL_EXPEDITEUR) |>
    to(email_destinataire) |>
    subject(paste0("Alerte stock - ", nom_salon)) |>
    html(corps_html)

  smtp(email, verbose = FALSE)
  cat("Email envoye a", email_destinataire, "pour", nom_salon, "\n")
}

# SCRIPT PRINCIPAL
cat("===================================\n")
cat("DataCoiff Pro - Verification stock\n")
cat(format(Sys.time(), "%d/%m/%Y %H:%M"), "\n")
cat("===================================\n\n")

con <- get_con()
on.exit(dbDisconnect(con))

salons <- dbGetQuery(con, "SELECT id, nom, email FROM salons WHERE actif = true")
cat("Salons actifs trouves :", nrow(salons), "\n\n")

for (i in 1:nrow(salons)) {
  salon <- salons[i, ]
  cat("Verification :", salon$nom, "...\n")

  produits_alertes <- dbGetQuery(con, sprintf(
    "SELECT produit, stock_actuel, stock_minimum
     FROM stock
     WHERE salon_id = %d AND stock_actuel <= stock_minimum
     ORDER BY stock_actuel ASC",
    salon$id
  ))

  if (nrow(produits_alertes) == 0) {
    cat("  Stock OK - aucune alerte\n")
  } else {
    cat(" ", nrow(produits_alertes), "produit(s) en alerte\n")
    tryCatch({
      envoyer_alerte(
        email_destinataire = salon$email,
        nom_salon          = salon$nom,
        produits_alertes   = produits_alertes
      )
    }, error = function(e) {
      cat("  Erreur envoi email :", conditionMessage(e), "\n")
    })
  }
  cat("\n")
}

cat("===================================\n")
cat("Verification terminee.\n")
cat("===================================\n")
