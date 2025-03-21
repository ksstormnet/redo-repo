#!/bin/bash
# Ollama RTX 3090 Optimizer
# Save this script to ~/ollama-optimizer.sh and chmod +x ~/ollama-optimizer.sh

# Exit on error
set -e

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "🚀 Optimizing system for Ollama on RTX 3090..."

# Set up NVIDIA driver optimizations
echo "📊 Configuring NVIDIA driver settings..."
nvidia-smi -pm 1
nvidia-smi --gpu-reset-applications-clocks
nvidia-smi -ac 1395,1695

# Optional: Increase power limit if thermals allow
# nvidia-smi -pl 400

# Set CPU governor to performance
echo "⚙️ Setting CPU governor to performance mode..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance > "${cpu}"
done

# Optimize kernel parameters
echo "🔧 Optimizing kernel parameters..."
cat > /etc/sysctl.d/99-ollama-optimization.conf << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.max_map_count=1048576
kernel.numa_balancing=0
EOF

sysctl -p /etc/sysctl.d/99-ollama-optimization.conf

# Clear cache to free up memory
echo "🧹 Clearing memory caches..."
sync
echo 3 > /proc/sys/vm/drop_caches

# Stop and restart Ollama service
echo "🔄 Restarting Ollama service..."
systemctl restart ollama

# Check Ollama status
echo "✅ Checking Ollama service status..."
systemctl status ollama

echo
echo "🎮 RTX 3090 Status:"
nvidia-smi

echo
echo "✨ Optimization complete! Ollama is now optimized for your RTX 3090."
echo "   Run your models with: ollama run llama3"
