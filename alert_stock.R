# DataCoiff Pro — Verification stock (ecrit alertes dans alertes.csv)
library(DBI)
library(RPostgres)

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

cat("DataCoiff Pro - Verification stock\n")
cat(format(Sys.time(), "%d/%m/%Y %H:%M"), "\n\n")

con <- get_con()
on.exit(dbDisconnect(con))

salons <- dbGetQuery(con, "SELECT id, nom, email FROM salons WHERE actif = true")
cat("Salons actifs:", nrow(salons), "\n\n")

resultats <- data.frame(
  salon_nom   = character(),
  salon_email = character(),
  produit     = character(),
  stock_actuel = integer(),
  stock_minimum = integer(),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(salons)) {
  salon <- salons[i, ]
  cat("Verification:", salon$nom, "...\n")

  alertes <- dbGetQuery(con, sprintf(
    "SELECT produit, stock_actuel, stock_minimum
     FROM stock
     WHERE salon_id = %d AND stock_actuel <= stock_minimum
     ORDER BY stock_actuel ASC",
    salon$id
  ))

  if (nrow(alertes) == 0) {
    cat("  Stock OK\n")
  } else {
    cat(" ", nrow(alertes), "produit(s) en alerte\n")
    alertes$salon_nom   <- salon$nom
    alertes$salon_email <- salon$email
    resultats <- rbind(resultats, alertes[, c("salon_nom","salon_email","produit","stock_actuel","stock_minimum")])
  }
}

write.csv(resultats, "alertes.csv", row.names = FALSE)
cat("\nFichier alertes.csv genere avec", nrow(resultats), "alerte(s).\n")
