#!/bin/sh
set -e

# Tailscale Setup Script for Alpine Linux VMs
# Usage: curl -sSL https://raw.githubusercontent.com/[user]/[repo]/main/src/os/alpine/tailscale-setup.sh | sh
# Or with auth key: TAILSCALE_AUTH_KEY=tskey-xxx curl -sSL ... | sh

echo "🔧 Tailscale Setup for Alpine Linux VM"
echo "======================================"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root. Use: sudo $0"
    exit 1
fi

# Function to setup HTTP repositories for corporate networks
setup_http_repos() {
    echo "📦 Setting up HTTP repositories for corporate networks..."
    
    # Backup current repositories
    if [ -f /etc/apk/repositories ]; then
        cp /etc/apk/repositories /etc/apk/repositories.backup.$(date +%s)
    fi
    
    # Configure HTTP repositories
    cat > /etc/apk/repositories << EOF
http://dl-cdn.alpinelinux.org/alpine/v3.21/main
http://dl-cdn.alpinelinux.org/alpine/v3.21/community
EOF
    
    echo "✅ Configured HTTP repositories"
}

# Function to restore HTTPS repositories
restore_https_repos() {
    echo "🔒 Restoring HTTPS repositories..."
    cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
EOF
    echo "✅ Restored HTTPS repositories"
}

# Try HTTPS first, fallback to HTTP for corporate networks
echo "📡 Updating package index..."
if ! apk update 2>/dev/null; then
    echo "⚠️  HTTPS repositories failed, switching to HTTP for corporate networks..."
    setup_http_repos
    apk update
fi

# Install Tailscale
echo "📦 Installing Tailscale..."
apk add tailscale

# Enable and start Tailscale service
echo "🚀 Enabling Tailscale service..."
rc-update add tailscale
rc-service tailscale start

# Wait for service to be ready
echo "⏳ Waiting for Tailscale service to start..."
sleep 3

# Connect to Tailscale network if auth key provided
if [ -n "${TAILSCALE_AUTH_KEY}" ]; then
    echo "🔗 Connecting to Tailscale network with provided auth key..."
    
    # Connect with auth key
    tailscale up --auth-key="${TAILSCALE_AUTH_KEY}" --accept-routes
    
    # Wait for connection and verify
    echo "⏳ Waiting for Tailscale connection..."
    for i in $(seq 1 30); do
        if tailscale status >/dev/null 2>&1; then
            echo "✅ Tailscale connected successfully!"
            tailscale status
            
            # If VPN is working, restore HTTPS repositories
            echo "🔄 Testing VPN connectivity..."
            if apk update >/dev/null 2>&1; then
                restore_https_repos
                apk update
                echo "🎉 VPN working! Switched back to HTTPS repositories"
            else
                echo "⚠️  VPN connected but HTTPS still failing, keeping HTTP repositories"
            fi
            break
        fi
        echo "⏳ Waiting for connection... ($i/30)"
        sleep 2
    done
    
    # Verify connection succeeded
    if ! tailscale status >/dev/null 2>&1; then
        echo "❌ Failed to connect to Tailscale after 60 seconds"
        echo "Please check your auth key and network connectivity"
        exit 1
    fi
else
    echo "⚠️  No TAILSCALE_AUTH_KEY provided. Tailscale installed but not connected."
    echo ""
    echo "📋 To connect manually:"
    echo "  1. Generate an auth key at https://login.tailscale.com/admin/settings/keys"
    echo "  2. Run: sudo tailscale up --auth-key=<your-key>"
    echo ""
    echo "📋 Or run this script with auth key:"
    echo "  TAILSCALE_AUTH_KEY=tskey-xxx curl -sSL <script-url> | sh"
fi

echo ""
echo "🎉 Tailscale setup completed!"
echo "   - Service status: $(rc-service tailscale status 2>/dev/null || echo 'installed')"
echo "   - Connection status: $(tailscale status --self 2>/dev/null | head -1 || echo 'not connected')"