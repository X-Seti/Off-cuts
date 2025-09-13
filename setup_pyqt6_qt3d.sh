#!/usr/bin/env bash
# X-Seti - PyQt6 + Qt3D setup for Orange Pi 5 Plus (Armbian Noble)

set -e

#Swap install methods for Arch, Manjaro, Garuda or Garajaro, comment out the apt install secton below

#Debian / Ubuntu / Mint

echo "Step 1: Install required system packages..."
sudo apt update
sudo apt install -y python3-venv python3-pip python3-dev build-essential qt6-base-dev qt6-base-dev-tools qt6-tools-dev-tools qt6-3d-dev libgl1-mesa-dev

#Arch

#sudo pacman -Syu
#sudo pacman -S base-devel python-pip python-pyqt6 python-pyqt6-qt6 python-sip gmake
#sudo pacman -S base-devel ninja m4 qt6-base qt6-tools qt6-3d mesa

#Fedora

#sudo dnf install -y @development-tools python3-pip python3-devel qt6-qtbase-devel qt6-qtbase-private-devel qt6-qt3d-devel
#sudo dnf install -y @development-tools ninja-build m4 qt6-qtbase-devel qt6-qttools-devel qt6-qt3d-devel mesa-libGL-devel

echo "Step 2: Create Python virtual environment..."
python3 -m venv ~/pyqt-env

echo "Step 3: Activate virtual environment..."
# Detect shell type for correct activation
if [ -n "$FISH_VERSION" ]; then
    source ~/pyqt-env/bin/activate.fish
else
    source ~/pyqt-env/bin/activate
fi

echo "Step 4: Upgrade pip and install SIP..."
pip install --upgrade pip
pip install sip

echo "Step 5: Remove any old PyQt6 installations..."
pip uninstall -y PyQt6 PyQt6-Qt6 || true

echo "Step 6: Build and install PyQt6 from source using Qt6..."
# Adjust path to qmake6 if not in PATH
QMAKE_PATH=$(which qmake6 || echo "/usr/lib/qt6/bin/qmake6")
pip install --no-binary :all: PyQt6 --config-settings "qmake=$QMAKE_PATH"

echo "Step 7: Test Qt3DCore..."
python3 - <<EOF
try:
    from PyQt6 import Qt3DCore
    print("✅ Qt3DCore available!")
except Exception as e:
    print("❌ Qt3DCore failed:", e)
EOF

echo "Setup complete! Remember to activate the venv before running your script:"
echo "  source ~/pyqt-env/bin/activate.fish  # for fish shell"
echo "  source ~/pyqt-env/bin/activate       # for bash/zsh"
