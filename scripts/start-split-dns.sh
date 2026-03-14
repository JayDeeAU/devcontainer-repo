#!/usr/bin/env bash
# scripts/start-split-dns.sh
# Starts dnsmasq for split-DNS resolution in devcontainer
# Routes Tailscale domains (*.ts.net) to 100.100.100.100,
# everything else to the LAN/default DNS from Docker's --dns flags
#
# Runs via postStartCommand (every container start)

set -e

DNSMASQ_RUNTIME_CONF="/etc/dnsmasq.d/runtime-servers.conf"
TAILSCALE_DNS="100.100.100.100"

# Skip if dnsmasq not installed
if ! command -v dnsmasq >/dev/null 2>&1; then
    echo "⚠️ dnsmasq not installed, skipping split-DNS"
    exit 0
fi

# Skip if already running
if pgrep -x dnsmasq >/dev/null 2>&1; then
    echo "✅ Split-DNS already running"
    exit 0
fi

echo "🔀 Configuring split-DNS..."

# Read Docker's resolv.conf before we overwrite it
# Extract nameservers and search domains set by --dns and --dns-search
NAMESERVERS=$(grep '^nameserver' /etc/resolv.conf | awk '{print $2}')
SEARCH_DOMAINS=$(grep '^search' /etc/resolv.conf | sed 's/^search //')

# Build runtime dnsmasq config from Docker's --dns entries
{
    echo "# Runtime DNS servers — generated from Docker --dns flags"
    echo "# $(date -Iseconds)"
    echo ""

    # Route Tailscale domains to Tailscale DNS
    echo "# Tailscale split-DNS"
    echo "server=/ts.net/${TAILSCALE_DNS}"

    # All other nameservers become default upstream (excluding Tailscale DNS
    # since it can't resolve general internet queries)
    echo ""
    echo "# Default upstream DNS (from Docker --dns)"
    for ns in $NAMESERVERS; do
        if [ "$ns" != "$TAILSCALE_DNS" ]; then
            echo "server=${ns}"
        fi
    done
} | sudo tee "$DNSMASQ_RUNTIME_CONF" > /dev/null

# Start dnsmasq (explicit --conf-dir since default dnsmasq.conf has it commented out)
echo "Starting dnsmasq..."
sudo dnsmasq --conf-dir=/etc/dnsmasq.d --test 2>&1 && sudo dnsmasq --conf-dir=/etc/dnsmasq.d || {
    echo "❌ dnsmasq failed to start"
    exit 1
}

# Rewrite resolv.conf to use local dnsmasq
{
    echo "# Managed by start-split-dns.sh — do not edit"
    echo "# ts.net → Tailscale DNS, default → LAN DNS via dnsmasq"
    echo "nameserver 127.0.0.1"
    if [ -n "$SEARCH_DOMAINS" ]; then
        echo "search ${SEARCH_DOMAINS}"
    fi
} | sudo tee /etc/resolv.conf > /dev/null

echo "✅ Split-DNS active (ts.net → ${TAILSCALE_DNS}, default → LAN)"
