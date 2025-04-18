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

# Create required directories using existing Bin directory
echo "Setting up directory structure..."
mkdir -p "$PARENT_DIR/plugin/Bin"
mkdir -p "$PARENT_DIR/build"

echo "Installing dependencies for ShairTunes2W with GoPlay2..."

# Install dependencies based on platform
case $PLATFORM in
    debian)
        echo "Installing packages for Debian/Ubuntu..."
        
        # Enable non-free repositories for libfdk-aac-dev (which is in non-free)
        if [ -f /etc/apt/sources.list ]; then
            echo "Enabling non-free repositories..."
            # Check if it's Debian or Ubuntu
            if grep -q "debian" /etc/apt/sources.list; then
                # For Debian: check if non-free is already enabled
                if ! grep -q "non-free" /etc/apt/sources.list; then
                    echo "Adding non-free repository to sources.list"
                    sudo sed -i 's/main$/main contrib non-free/g' /etc/apt/sources.list
                else
                    echo "Non-free repository already enabled"
                fi
            elif grep -q "ubuntu" /etc/apt/sources.list; then
                # For Ubuntu: check if multiverse is already enabled
                if ! grep -q "multiverse" /etc/apt/sources.list; then
                    echo "Adding multiverse repository to sources.list"
                    sudo add-apt-repository multiverse -y
                else
                    echo "Multiverse repository already enabled"
                fi
            fi
        else
            echo "Warning: /etc/apt/sources.list not found, cannot enable non-free repository"
            echo "You may need to manually enable it to install libfdk-aac-dev"
        fi
        
        sudo apt-get update
        
        # Try to install fdk-aac from main repositories first
        echo "Attempting to install libfdk-aac-dev..."
        if ! sudo apt-get install -y libfdk-aac-dev; then
            echo "libfdk-aac-dev not found, trying alternative package fdk-aac-dev..."
            sudo apt-get install -y fdk-aac-dev || echo "Warning: Could not install libfdk-aac-dev or fdk-aac-dev"
        fi
        
        # Install other dependencies
        sudo apt-get install -y build-essential ffmpeg socat \
            golang-go pulseaudio portaudio19-dev libsamplerate0-dev git
        ;;
    redhat)
        echo "Installing packages for RedHat/CentOS..."
        sudo yum install -y gcc make ffmpeg socat \
            golang libfdk-aac-devel pulseaudio portaudio-devel libsamplerate-devel git
        ;;
    macos)
        echo "Installing packages for macOS..."
        if ! command -v brew &>/dev/null; then
            echo "❌ Homebrew not installed. Please install it first."
            exit 1
        fi
        brew install ffmpeg socat golang libfdk-aac portaudio pulseaudio libsamplerate git
        ;;
esac

# Determine correct binary name suffix based on platform
if [ "$PLATFORM" == "macos" ]; then
    if [ "$(uname -m)" == "arm64" ]; then
        BINARY_SUFFIX="macos-arm64"
    else
        BINARY_SUFFIX="macos-x86_64"
    fi
else
    # For Linux
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            BINARY_SUFFIX="linux-x86_64"
            ;;
        i?86)
            BINARY_SUFFIX="linux-x86"
            ;;
        aarch64)
            BINARY_SUFFIX="linux-aarch64"
            ;;
        armv7*)
            BINARY_SUFFIX="linux-arm"
            ;;
        arm*)
            if [ $(readelf -A /proc/self/exe | grep Tag_ABI_VFP_args) ]; then
                BINARY_SUFFIX="linux-armv6"
            else
                BINARY_SUFFIX="linux-armv5"
            fi
            ;;
        *)
            BINARY_SUFFIX="linux-$(uname -m)"
            ;;
    esac
fi

# Build GoPlay2 directly from audio-sync branch
echo "Building GoPlay2 from audio-sync branch..."
cd "$PARENT_DIR/build"

# Remove the directory if it exists to ensure a clean build
if [ -d "goplay2" ]; then
    echo "Removing existing goplay2 directory for clean build..."
    rm -rf goplay2
fi

echo "Cloning GoPlay2 repository directly from audio-sync branch..."
git clone -b feature/audio-sync https://github.com/openairplay/goplay2.git
cd goplay2

# Ensure dependencies are fetched
echo "Fetching Go dependencies..."
go get -v ./...

# Check for build issues and attempt to fix the codec.NewStream issue
if grep -r "codec.NewStream(" --include="*.go" .; then
    echo "Found codec.NewStream calls, checking for parameter issues..."
    # Try to check or fix the audio/player.go file if it exists
    if [ -f "audio/player.go" ]; then
        echo "Examining audio/player.go..."
        # Backup the file before making any changes
        cp audio/player.go audio/player.go.bak
        
        # Fix the specific line with the error (removing the float64 parameter)
        sed -i 's/codec.NewStream([^)]*)/codec.NewStream()/g' audio/player.go
        echo "Applied potential fix to audio/player.go"
    fi
fi

echo "Compiling GoPlay2..."
go build

# Verify the build
if [ ! -f "goplay2" ]; then
    echo "❌ Failed to build GoPlay2. Please check for errors."
    exit 1
fi

# Copy binary to the existing Bin directory with appropriate name
echo "Copying GoPlay2 binary to plugin/Bin directory..."
cp goplay2 "$PARENT_DIR/plugin/Bin/goplay2-${BINARY_SUFFIX}"

# Also create a symlink or copy without the suffix for easier reference
if [ "$PLATFORM" == "macos" ]; then
    cp goplay2 "$PARENT_DIR/plugin/Bin/goplay2"
else
    cp goplay2 "$PARENT_DIR/plugin/Bin/goplay2"
fi

# Set capabilities for GoPlay2
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting capabilities for GoPlay2..."
    sudo setcap 'cap_net_bind_service=+ep' "$PARENT_DIR/plugin/Bin/goplay2-${BINARY_SUFFIX}"
    sudo setcap 'cap_net_bind_service=+ep' "$PARENT_DIR/plugin/Bin/goplay2"
fi

# Setup PulseAudio for the current user
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting up PulseAudio..."
    if ! pgrep -x "pulseaudio" > /dev/null; then
        pulseaudio --start
    fi
fi

echo ""
echo "✅ Installation complete with audio synchronization features!"
echo ""
echo "Important notes:"
echo "1. Make sure PulseAudio is running when using the plugin"
echo "2. If you're running LMS as a different user, you may need to configure PulseAudio for that user"
echo "3. For troubleshooting, check the LMS logs"
echo ""
echo "Audio sync features that have been added:"
echo "- Improved multi-room audio synchronization"
echo "- Better latency handling"
echo "- PTP (Precision Time Protocol) support"
echo ""
echo "Next steps:"
echo "1. Modify Plugin.pm to implement GoPlay2 integration"
echo "2. Update AIRPLAY.pm to handle HTTP streams"
echo "3. Test with a single player"
echo "" 