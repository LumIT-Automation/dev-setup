#!/usr/bin/env bash
set -euo pipefail

### CONFIGURAZIONE ###
CONJUR_URL="https://apisecops"
CONJUR_ACCOUNT="dgs-lab"
ADMIN_LOGIN="admin"
ADMIN_API_KEY='CyberArk@123!'

# Policy branch dove applicare i file YAML
POLICY_BRANCH="root"

# File policy
HOSTS_POLICY="hosts.yml"
SECRETS_POLICY="secrets.yml"

# Secret fittizio non esistente per test
MISSING_VAR="not-defined"

########################

# 1. Login admin
echo "🟢 Login come admin..."
conjur init --url $CONJUR_URL --account $CONJUR_ACCOUNT -s

conjur login -i "$ADMIN_LOGIN" -p "$ADMIN_API_KEY"

# 2. Caricamento policy hosts e secret (load o update ripetibile)
echo "🟢 Caricamento/aggiornamento hosts da $HOSTS_POLICY..."
conjur policy load --file "$HOSTS_POLICY" --branch "$POLICY_BRANCH"

echo "🟢 Caricamento/aggiornamento secret da $SECRETS_POLICY..."
conjur policy load --file "$SECRETS_POLICY" --branch "$POLICY_BRANCH"

# 3. Ruotazione/API key
echo "   🔑 Ruotazione API key..."
API_KEY=$(conjur host rotate-api-key -i my-new-host)
echo "   • API key ottenuta" $API_KEY

#4 valorizzazione variabili
echo "Valorizzazione variabili"
echo "passwordtest impostata"
conjur variable set -i passwordtest -v PwdTest
echo "PwdAPIKEY impostata"
conjur variable set -i api-keytest -v PwdAPIKEY
# 3c. Login come host
conjur login -i host/my-new-host -p $API_KEY

# 3d. Lettura secret esistenti
echo "   ▶️ Lettura secret definiti:"
for VAR in $(grep '^[[:space:]]*id:' secrets.yml | sed -E 's/^[[:space:]]*id:[[:space:]]*//'); do
if conjur variable get --id $VAR; then
    echo "     ✅ $VAR"
else
    echo "     ❌ $VAR (FAILED)"
fi
done

# 3e. Lettura secret non esistente
echo "   ▶️ Lettura secret NON esistente ($MISSING_VAR):"
if conjur variable get --id $MISSING_VAR; then
echo "     ⚠️ Lettura imprevista riuscita!"
else
echo "     ✅ Lettura negata come previsto"
fi

# 4. Pulizia finale: cancellazione secret e host
echo
echo "🗑️  Avvio cancellazione secret definiti..."
echo "🟢 Login come admin..."
conjur login -i "$ADMIN_LOGIN" -p "$ADMIN_API_KEY"
conjur policy update -f delete.yml -b root
echo
echo "🏁 Tutte le operazioni (create, test, delete) sono completate. Lo script è idempotente."
