#!/bin/bash

# Script to block incoming TCP and UDP scans using firewalld and iptables
# Author: Balazs Ujvari
# Description: Blocks TCP and UDP port scans by rate-limiting connections.

echo "Starting TCP and UDP scan detection and blocking..."

# Check if firewalld is active
if ! systemctl is-active --quiet firewalld; then
    echo "Firewalld is not running. Starting firewalld..."
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
fi

# ================================================
# Block TCP Scans
# ================================================
echo "Adding rate-limiting rules to block TCP scans..."

# Firewalld rule to limit new TCP connections to 10 per minute
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' \
  protocol value='tcp' \
  limit value='10/m' \
  reject"

# Add iptables rules to block excessive TCP SYN packets
sudo iptables -A INPUT -p tcp --syn -m recent --name PORTSCAN --set
sudo iptables -A INPUT -p tcp --syn -m recent --name PORTSCAN --update --seconds 60 --hitcount 10 -j DROP

# Log and drop TCP port scans
sudo iptables -A INPUT -m recent --name PORTSCAN --rcheck --seconds 60 --hitcount 10 -j LOG --log-prefix "TCP Port Scan Detected: "
sudo iptables -A INPUT -m recent --name PORTSCAN --rcheck --seconds 60 --hitcount 10 -j DROP

# ================================================
# Block UDP Scans
# ================================================
echo "Adding rules to block UDP scans..."

# Firewalld rule to rate-limit incoming UDP packets (e.g., 10 per minute)
sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' \
  protocol value='udp' \
  limit value='10/m' \
  reject"

# Add iptables rules to block excessive UDP packets to closed ports
sudo iptables -A INPUT -p udp -m recent --name UDPSCAN --set
sudo iptables -A INPUT -p udp -m recent --name UDPSCAN --update --seconds 60 --hitcount 10 -j DROP

# Log and drop UDP port scans
sudo iptables -A INPUT -m recent --name UDPSCAN --rcheck --seconds 60 --hitcount 10 -j LOG --log-prefix "UDP Port Scan Detected: "
sudo iptables -A INPUT -m recent --name UDPSCAN --rcheck --seconds 60 --hitcount 10 -j DROP

# ================================================
# Final Steps
# ================================================
# Reload firewalld to apply changes
echo "Reloading firewalld..."
sudo firewall-cmd --reload

# Save iptables rules to persist on reboot (requires iptables-persistent)
echo "Saving iptables rules..."
sudo dnf install iptables -y
sudo bash -c "iptables-save > /etc/iptables/rules.v4"

echo "TCP and UDP scan blocking rules have been applied successfully!"
