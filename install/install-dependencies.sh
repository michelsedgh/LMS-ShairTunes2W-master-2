#!/bin/bash
#
# ShairTunes2W GoPlay2 Integration - Dependency Installation Script
# This script installs and builds all dependencies required for the GoPlay2 integration

set -e  # Exit on error

echo "==================================================================="
echo "ShairTunes2W GoPlay2 Integration - Dependency Installation"
echo "==================================================================="

# Detect platform
if [ -f /etc/debian_version ]; then
    echo "✅ Detected Debian/Ubuntu system"
    PLATFORM="debian"
elif [ -f /etc/redhat-release ]; then
    echo "✅ Detected RedHat/CentOS system"
    PLATFORM="redhat"
elif [ "$(uname)" == "Darwin" ]; then
    echo "✅ Detected macOS system"
    PLATFORM="macos"
else
    echo "❌ Unsupported platform"
    exit 1
fi

# Get script directory for relative paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Create required directories
echo "Creating directory structure..."
mkdir -p "$PARENT_DIR/bin"
mkdir -p "$PARENT_DIR/build"

echo "Installing dependencies for ShairTunes2W with GoPlay2..."

# Install dependencies based on platform
case $PLATFORM in
    debian)
        echo "Installing packages for Debian/Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y build-essential ffmpeg socat \
            golang-go libfdk-aac-dev pulseaudio portaudio19-dev
        ;;
    redhat)
        echo "Installing packages for RedHat/CentOS..."
        sudo yum install -y gcc make ffmpeg socat \
            golang libfdk-aac-devel pulseaudio portaudio-devel
        ;;
    macos)
        echo "Installing packages for macOS..."
        if ! command -v brew &>/dev/null; then
            echo "❌ Homebrew not installed. Please install it first."
            exit 1
        fi
        brew install ffmpeg socat golang libfdk-aac portaudio pulseaudio
        ;;
esac

# Build GoPlay2
echo "Building GoPlay2..."
cd "$PARENT_DIR/build"

if [ ! -d "goplay2" ]; then
    echo "Cloning GoPlay2 repository..."
    git clone https://github.com/openairplay/goplay2.git
fi

cd goplay2
echo "Compiling GoPlay2..."
go build

# Verify the build
if [ ! -f "goplay2" ]; then
    echo "❌ Failed to build GoPlay2. Please check for errors."
    exit 1
fi

# Copy binary to bin directory
echo "Copying GoPlay2 binary to bin directory..."
cp goplay2 "$PARENT_DIR/bin/"

# Set capabilities for GoPlay2
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting capabilities for GoPlay2..."
    sudo setcap 'cap_net_bind_service=+ep' "$PARENT_DIR/bin/goplay2"
fi

# Setup PulseAudio for the current user
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting up PulseAudio..."
    if ! pgrep -x "pulseaudio" > /dev/null; then
        pulseaudio --start
    fi
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Important notes:"
echo "1. Make sure PulseAudio is running when using the plugin"
echo "2. If you're running LMS as a different user, you may need to configure PulseAudio for that user"
echo "3. For troubleshooting, check the LMS logs"
echo ""
echo "Next steps:"
echo "1. Modify Plugin.pm to implement GoPlay2 integration"
echo "2. Update AIRPLAY.pm to handle HTTP streams"
echo "3. Test with a single player"
echo "" 