#!/bin/bash
# Add a new subdomain to wittycomp.com — all 3 CF steps automated.
# Does NOT add the Caddyfile block (that requires a git commit).
#
# Usage: ./cf-add-subdomain.sh <subdomain> <backend-ip> <backend-port>
# Example: ./cf-add-subdomain.sh gitea 10.10.30.72 3000
#
# Prerequisites:
#   - CF_TOKEN env var set, or will attempt to read from Vaultwarden
#   - bw CLI logged in (cat ~/.bw_session non-empty)
#   - Technitium reachable at 10.10.10.10:53443

set -euo pipefail

SUBDOMAIN="${1:?Usage: $0 <subdomain> <backend-ip> <backend-port>}"
BACKEND_IP="${2:?}"
BACKEND_PORT="${3:?}"

CF_ZONE_ID="f2d562fd622786dbb39a7319e8e21d26"
CF_TUNNEL_ID="3e0a5181-c09b-49a6-bf3a-3a33af664e87"
CADDY_IP="172.18.0.100"

# Load CF token
if [ -z "${CF_TOKEN:-}" ]; then
    BW_SESSION=$(cat ~/.bw_session 2>/dev/null || "")
    if [ -z "$BW_SESSION" ]; then
        echo "ERROR: CF_TOKEN not set and no bw_session found."
        exit 1
    fi
    CF_TOKEN=$(bw get item "Cloudflare - API Token" --session "$BW_SESSION" 2>/dev/null \
        | python3 -c "import sys,json; item=json.load(sys.stdin); print(item['login']['password'])" 2>/dev/null || "")
fi

if [ -z "$CF_TOKEN" ]; then
    echo "ERROR: Could not load CF_TOKEN from Vaultwarden."
    exit 1
fi

echo "=== Step 1: Technitium DNS A record ==="
TECH_TOKEN=$(curl -s "http://10.10.10.10:53443/api/user/login?user=admin&pass=7403B3ars!" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

TECH_RESULT=$(curl -s "http://10.10.10.10:53443/api/zones/records/add?\
token=${TECH_TOKEN}&zone=wittycomp.com&domain=${SUBDOMAIN}.wittycomp.com\
&type=A&ipAddress=10.10.30.5&ttl=3600")
echo "Technitium: $TECH_RESULT" | python3 -c "import sys,json; r=json.load(sys.stdin); print('OK' if r.get('status')=='ok' else 'FAIL: '+str(r))"

echo ""
echo "=== Step 2: Cloudflare DNS CNAME ==="
CF_DNS=$(curl -s -X POST \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"type\": \"CNAME\",
        \"name\": \"${SUBDOMAIN}\",
        \"content\": \"${CF_TUNNEL_ID}.cfargotunnel.com\",
        \"proxied\": true
    }")
echo "$CF_DNS" | python3 -c "import sys,json; r=json.load(sys.stdin); \
    print('OK - record ID:', r['result']['id'] if r.get('success') else 'FAIL (may already exist - check): ' + str(r.get('errors','')))"

echo ""
echo "=== Step 3: CF Tunnel ingress rule ==="
# Get current config
CURRENT=$(curl -s \
    "https://api.cloudflare.com/client/v4/accounts/$(curl -s https://api.cloudflare.com/client/v4/accounts \
        -H "Authorization: Bearer $CF_TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")/cfd_tunnel/${CF_TUNNEL_ID}/configurations" \
    -H "Authorization: Bearer $CF_TOKEN")

# Insert new rule before catch-all, then PUT
python3 - <<PYEOF
import json, sys, urllib.request, urllib.error

current_json = $CURRENT
ingress = current_json['result']['config']['ingress']

new_rule = {
    "hostname": "${SUBDOMAIN}.wittycomp.com",
    "service": "https://${CADDY_IP}:443",
    "originRequest": {
        "noTLSVerify": True,
        "originServerName": "${SUBDOMAIN}.wittycomp.com"
    }
}

# Insert before the last entry (catch-all)
ingress.insert(-1, new_rule)

account_id = current_json['result']['account_tag']
tunnel_id = "${CF_TUNNEL_ID}"
url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations"

payload = json.dumps({"config": {"ingress": ingress}}).encode()
req = urllib.request.Request(url, data=payload, method="PUT")
req.add_header("Authorization", "Bearer ${CF_TOKEN}")
req.add_header("Content-Type", "application/json")

try:
    with urllib.request.urlopen(req) as resp:
        result = json.load(resp)
        if result.get("success"):
            print(f"OK - tunnel ingress rule added for ${SUBDOMAIN}.wittycomp.com")
        else:
            print(f"FAIL: {result}")
except Exception as e:
    print(f"ERROR: {e}")
PYEOF

echo ""
echo "=== Verification ==="
echo "LAN path:"
curl -sk --resolve "${SUBDOMAIN}.wittycomp.com:443:10.10.30.5" \
    -o /dev/null -w "  %{http_code}\n" "https://${SUBDOMAIN}.wittycomp.com/" || true

echo "CF tunnel path (wait ~30s for edge reconvergence if just added):"
curl -sk --resolve "${SUBDOMAIN}.wittycomp.com:443:172.67.205.110" \
    -o /dev/null -w "  %{http_code}\n" "https://${SUBDOMAIN}.wittycomp.com/" || true

echo ""
echo "=== Manual step required ==="
echo "Add Caddyfile block to wittycomp-lab repo:"
echo ""
echo "${SUBDOMAIN}.wittycomp.com {"
echo "    import cloudflare_tls"
echo "    reverse_proxy ${BACKEND_IP}:${BACKEND_PORT}"
echo "}"
echo ""
echo "Then sync + reload:"
echo "  docker exec -i wn-caddy-01 tee /etc/caddy/Caddyfile < /home/bearboss/wittycomp-lab/apps/caddy/Caddyfile > /dev/null"
echo "  docker exec wn-caddy-01 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile --address localhost:2019"
