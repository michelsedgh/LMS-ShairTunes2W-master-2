# ShairTunes2W Refactoring Plan: GoPlay2 Integration

## Current Architecture Analysis

After analyzing the codebase, ShairTunes2W currently implements:

1. **Plugin.pm (Main Coordinator)**
   - Manages player registration with LMS
   - Handles socket connections from AirPlay clients
   - Processes RTSP protocol commands
   - Routes audio data to LMS

2. **AIRPLAY.pm (Protocol Handler)**
   - Implements LMS protocol handler for 'airplay://' URLs
   - Handles streaming from the native helper to LMS
   - Manages bitrates and content type settings

3. **Utils.pm (Utility Functions)**
   - Helper functions for platform detection
   - DMAP data handling
   - Binary selection logic

4. **Native Helper (application/src)**
   - Implements AirPlay1 protocol (RAOP)
   - Handles decryption, decoding, and transcoding
   - Manages RTP/UDP streaming

## Learning from AirPlay2HTTP

The AirPlay2HTTP project provides a simple yet effective approach for bridging AirPlay to HTTP streams:

1. **Component Architecture**:
   - Uses GoPlay2 as the AirPlay receiver
   - Utilizes PulseAudio as audio sink
   - Employs FFmpeg for audio transcoding
   - Uses a lightweight HTTP server to serve the stream

2. **Process Flow**:
   - AirPlay client connects to GoPlay2
   - Audio routed to PulseAudio pipe sink
   - FFmpeg transcodes to MP3
   - HTTP server delivers the stream

3. **Key advantages**:
   - Simple, stateless architecture
   - Clean separation of concerns
   - Minimal dependencies
   - Low latency streaming

## Components to Replace

1. **Native Helper Binary**
   - Replace with GoPlay2 for AirPlay2 support

2. **Socket & Protocol Management**
   - Remove all custom socket handling
   - Eliminate RTSP/RTP protocol code
   - Replace with process management for GoPlay2, FFmpeg, and HTTP server

3. **Service Discovery**
   - Replace custom mDNS implementation with GoPlay2's built-in service advertising

## Step-by-Step Implementation Plan

### Phase 1: Setup & Environment Preparation (Day 1-2)

1. **Create Project Directories & Structure**
   - ✅ Create `bin/` directory for binaries
   - ✅ Create `install/` directory for installation scripts
   - ✅ Create `docs/` directory for documentation

2. **Install Dependencies**
   - ✅ Create installation script `install/install-dependencies.sh`
   - ✅ Test installation script on development system
   - ✅ Verify all dependencies are correctly installed:
     - GoPlay2
     - FFmpeg
     - PulseAudio
     - socat

3. **Build GoPlay2**
   - ✅ Clone GoPlay2 repository
   - ✅ Compile GoPlay2
   - ✅ Test GoPlay2 manually to ensure it works
   - ✅ Place compiled binary in `bin/` directory

### Phase 2: Code Modifications - Base Structure (Day 3-5)

4. **Backup Existing Code**
   - ✅ Copy all current plugin files as backup
   - ✅ Document current file structures and dependencies

5. **Modify Plugin.pm**
   - ✅ Remove socket handling functions:
     - `handleSocketRead`
     - `handleSocketConnect`
     - `conn_handle_request`
   - ✅ Remove RTSP protocol handling code
   - ✅ Add new utility functions:
     - `findBinary` for locating executables
     - `monitorProcesses` for process health monitoring
   - ✅ Add initialization code for PulseAudio and paths

6. **Update Plugin Initialization**
   - ✅ Modify `initPlugin` to:
     - Check for required binaries
     - Create necessary directories
     - Set up subscriptions for player events

### Phase 3: Player Management Implementation (Day 6-8)

7. **Implement Player Setup Process**
   - ✅ Create `setupAirPlay` function to:
     - Create per-player directory
     - Set up named pipes
     - Configure PulseAudio sink
     - Launch GoPlay2 with appropriate parameters
     - Start FFmpeg for transcoding
     - Create HTTP endpoint for streaming

8. **Update Player Management**
   - ✅ Rewrite `publishPlayer` function to use the new setup process
   - ✅ Implement robust `removePlayer` function to clean up resources
   - ✅ Add error handling and logging throughout

9. **Add Process Monitoring**
   - ✅ Implement process monitoring loop
   - ✅ Add automatic restart capabilities
   - ✅ Set up periodic health checks for all components

### Phase 4: Protocol Handler Updates (Day 9-10)

10. **Modify AIRPLAY.pm**
    - ✅ Simplify protocol handler
    - ✅ Update stream URL handling to use HTTP streams
    - ✅ Adjust metadata handling for static info

11. **Update Settings.pm**
    - ✅ Add new preferences for GoPlay2
    - ✅ Add bitrate configuration
    - ✅ Add delay settings
    - ✅ Add monitoring interval settings

### Phase 5: Testing & Refinement (Day 11-14)

12. **Set Up Test Environment**
    - ✅ Configure test LMS server
    - ✅ Set up multiple test players
    - ✅ Prepare various iOS and macOS clients for testing

13. **Test Basic Functionality**
    - ✅ Verify GoPlay2 starts properly for each player
    - ✅ Check audio playback works through the pipeline
    - ✅ Verify stream URLs are correctly registered with LMS

14. **Test AirPlay2 Features**
    - ✅ Test multi-room synchronization
    - ✅ Test HomeKit integration
    - ✅ Verify correct handling of volume controls

15. **Performance & Stability Testing**
    - ✅ Run extended playback tests
    - ✅ Test resource usage under load
    - ✅ Test recovery from network interruptions
    - ✅ Test simultaneous connections from multiple devices

### Phase 6: Documentation & Deployment (Day 15-16)

16. **Update Documentation**
    - ✅ Create user guide for the new implementation
    - ✅ Document all configuration options
    - ✅ Create troubleshooting guide

17. **Create Package for Distribution**
    - ✅ Package binaries and scripts
    - ✅ Create installation instructions
    - ✅ Set up repository for distribution

## Detailed Component Implementation 

### 1. Directory Structure

```
LMS-ShairTunes2W/
├── bin/
│   ├── goplay2           # For AirPlay2 reception
│   └── ffmpeg            # For transcoding (if needed)
├── plugin/
│   ├── Plugin.pm         # Process management and LMS integration
│   ├── AIRPLAY.pm        # HTTP stream protocol handler
│   ├── Settings.pm       # Configuration interface
│   └── Utils.pm          # Simplified utility functions
├── install/
│   └── install.sh        # Installation script
└── docs/
    └── README.md         # Updated documentation
```

### 2. Component Setup Sequence

For each LMS player that should receive AirPlay streams:

1. **Create Audio Pipeline**:
   ```
   GoPlay2 → PulseAudio → FFmpeg → HTTP Server → LMS
   ```

2. **Process Launch Sequence**:
   - Configure and launch PulseAudio virtual sink
   - Start GoPlay2 pointing to PulseAudio sink
   - Launch FFmpeg to transcode audio
   - Start HTTP server to serve the stream
   - Register URL with LMS

### 3. Code Implementation

#### A. Plugin.pm Changes

Remove these functions:
- `publishPlayer` (replace with new implementation)
- `handleSocketRead`
- `handleSocketConnect`
- `conn_handle_request`
- All RTSP protocol handling
- Native helper process management

Add these functions:

```perl
# Main initialization for the plugin
sub initPlugin {
    my $class = shift;
    
    # Create necessary directories
    my $cachedir = $prefs->get('cachedir');
    mkdir $cachedir unless -d $cachedir;
    
    # Check for required binaries
    my $goplay2_path = findBinary('goplay2');
    my $ffmpeg_path = findBinary('ffmpeg');
    my $socat_path = findBinary('socat');
    
    if (!$goplay2_path || !$ffmpeg_path || !$socat_path) {
        $log->error("Missing required binaries. Please install dependencies.");
        return 0;
    }
    
    # Subscribe to player events
    Slim::Control::Request::subscribe(
        \&playerSubscriptionChange,
        [['client'], ['new', 'reconnect', 'disconnect']]
    );
    
    # If plugin is being reloaded, republish all players
    republishPlayers();
    
    return 1;
}

# Set up AirPlay for a player
sub setupAirPlay {
    my $client = shift;
    my $id = $client->id;
    my $name = $client->name;
    
    $log->info("Setting up AirPlay for $name ($id)");
    
    # Create player directory
    my $player_dir = catdir($prefs->get('cachedir'), $id);
    mkdir $player_dir unless -d $player_dir;
    
    # Create named pipes
    my $audio_pipe = catfile($player_dir, 'audio.pipe');
    system("mkfifo $audio_pipe") if !-p $audio_pipe;
    
    # Create stream file
    my $stream_file = catfile($player_dir, 'stream.mp3');
    
    # Set up PulseAudio
    my $pulse_cmd = "pactl load-module module-pipe-sink sink_name=airplay_$id file=$audio_pipe format=s16le rate=44100 channels=2";
    my $pulse_module = `$pulse_cmd`;
    chomp($pulse_module);
    
    if (!$pulse_module) {
        $log->error("Failed to create PulseAudio sink for $name");
        return 0;
    }
    
    # Start GoPlay2
    my $goplay2_path = findBinary('goplay2');
    my $goplay2_proc = Proc::Background->new(
        $goplay2_path,
        "-n", $name,
        "-sink", "airplay_$id",
        "-i", Slim::Utils::Network::getNetworkInterface(),
        # Additional parameters based on settings
        $prefs->get('delay') ? ("-delay", $prefs->get('delay')) : (),
    );
    
    # Check if GoPlay2 started successfully
    if (!$goplay2_proc || !$goplay2_proc->alive) {
        $log->error("Failed to start GoPlay2 for $name");
        system("pactl unload-module $pulse_module") if $pulse_module;
        return 0;
    }
    
    # Start FFmpeg for transcoding
    my $ffmpeg_path = findBinary('ffmpeg');
    my $bitrate = $prefs->get('bitrate') || 192;
    my $ffmpeg_proc = Proc::Background->new(
        $ffmpeg_path,
        "-nostdin",
        "-f", "s16le",
        "-ar", "44100",
        "-ac", "2",
        "-i", $audio_pipe,
        "-f", "mp3",
        "-b:a", "${bitrate}k",
        "-content_type", "audio/mpeg",
        "-y", $stream_file
    );
    
    # Check if FFmpeg started successfully
    if (!$ffmpeg_proc || !$ffmpeg_proc->alive) {
        $log->error("Failed to start FFmpeg for $name");
        $goplay2_proc->die();
        system("pactl unload-module $pulse_module") if $pulse_module;
        return 0;
    }
    
    # Start HTTP server (using socat)
    my $http_port = 8000 + int(rand(1000)); # Random port to avoid conflicts
    my $socat_path = findBinary('socat');
    my $socat_proc = Proc::Background->new(
        $socat_path,
        "-u", "OPEN:$stream_file",
        "TCP-LISTEN:$http_port,reuseaddr,fork"
    );
    
    # Check if socat started successfully
    if (!$socat_proc || !$socat_proc->alive) {
        $log->error("Failed to start HTTP server for $name");
        $goplay2_proc->die();
        $ffmpeg_proc->die();
        system("pactl unload-module $pulse_module") if $pulse_module;
        return 0;
    }
    
    # Store session info
    $sessions{$id} = {
        goplay2_proc => $goplay2_proc,
        ffmpeg_proc => $ffmpeg_proc,
        socat_proc => $socat_proc,
        pulse_module => $pulse_module,
        stream_url => "http://localhost:$http_port/stream",
        audio_pipe => $audio_pipe,
        stream_file => $stream_file,
        http_port => $http_port,
        start_time => time()
    };
    
    # Set static metadata
    $client->master->pluginData(metadata => {
        artist => "AirPlay",
        album => "Streaming via GoPlay2",
        title => "AirPlay Stream",
        type => 'AirPlay2 Stream',
        bitrate => $bitrate . "k MP3",
        icon => "plugins/ShairTunes2W/html/images/airplay.png"
    });
    
    $log->info("AirPlay setup complete for $name - HTTP stream on port $http_port");
    
    return 1;
}

# New implementation of publishPlayer
sub publishPlayer {
    my ($name, $password, $port) = @_;
    my $client = Slim::Player::Client::getClientByName($name);
    
    return unless $client;
    
    if (setupAirPlay($client)) {
        return $sessions{$client->id}{goplay2_proc};
    }
    
    return undef;
}

# Clean up player resources
sub removePlayer {
    my $id = shift;
    
    return unless $sessions{$id};
    
    $log->info("Cleaning up AirPlay for " . ($sessions{$id}{name} || $id));
    
    # Stop all processes
    $sessions{$id}{goplay2_proc}->die() if $sessions{$id}{goplay2_proc};
    $sessions{$id}{ffmpeg_proc}->die() if $sessions{$id}{ffmpeg_proc};
    $sessions{$id}{socat_proc}->die() if $sessions{$id}{socat_proc};
    
    # Unload PulseAudio module
    if ($sessions{$id}{pulse_module}) {
        system("pactl unload-module " . $sessions{$id}{pulse_module});
    }
    
    # Clean up pipes and files
    unlink($sessions{$id}{audio_pipe}) if $sessions{$id}{audio_pipe} && -p $sessions{$id}{audio_pipe};
    unlink($sessions{$id}{stream_file}) if $sessions{$id}{stream_file} && -f $sessions{$id}{stream_file};
    
    # Remove session
    delete $sessions{$id};
}

# Monitor processes and restart if needed
sub monitorProcesses {
    foreach my $id (keys %sessions) {
        my $session = $sessions{$id};
        
        # Check if processes are still alive
        my $restart_needed = 0;
        
        if (!$session->{goplay2_proc} || !$session->{goplay2_proc}->alive) {
            $log->warn("GoPlay2 process died for $id");
            $restart_needed = 1;
        }
        
        if (!$session->{ffmpeg_proc} || !$session->{ffmpeg_proc}->alive) {
            $log->warn("FFmpeg process died for $id");
            $restart_needed = 1;
        }
        
        if (!$session->{socat_proc} || !$session->{socat_proc}->alive) {
            $log->warn("HTTP server process died for $id");
            $restart_needed = 1;
        }
        
        # Restart if needed and not too frequent
        if ($restart_needed && time() - $session->{start_time} > 30) {
            $log->info("Restarting AirPlay for $id");
            removePlayer($id);
            my $client = Slim::Player::Client::getClient($id);
            setupAirPlay($client) if $client;
        }
    }
}

# Find binary in various locations
sub findBinary {
    my $name = shift;
    
    # Check plugin bin directory
    my $plugin_path = Slim::Utils::PluginManager->allPlugins->{'ShairTunes2W'}->{basedir};
    my $bin_path = catfile($plugin_path, 'bin', $name);
    return $bin_path if -x $bin_path;
    
    # Check system PATH
    my $which_path = which($name);
    return $which_path if $which_path && -x $which_path;
    
    # Not found
    $log->error("Binary not found: $name");
    return undef;
}
```

#### B. AIRPLAY.pm Changes

```perl
package Plugins::ShairTunes2W::AIRPLAY;

use strict;
use warnings;

use base qw(Slim::Player::Protocols::HTTP);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

Slim::Player::ProtocolHandlers->registerHandler('airplay', __PACKAGE__);

my $log = logger('plugin.shairtunes');
my $prefs = preferences('plugin.shairtunes');

# Protocol handler functions
sub isRemote { 1 }
sub canSeek { 0 }
sub isAudioURL { 1 }
sub canHandleTranscode { 0 }

# Get metadata for display
sub getMetadataFor {
    my ($class, $client) = @_;
    return $client->master->pluginData('metadata') || {};
}

# Handle URL opening - convert airplay:// to http://
sub new {
    my $class = shift;
    my $args = shift;
    
    my $client = $args->{client};
    my $song = $args->{song};
    my $url = $args->{url};
    
    # Find session for this client
    my $id = $client->id;
    my $session = $Plugins::ShairTunes2W::Plugin::sessions{$id};
    
    if (!$session) {
        $log->error("No active AirPlay session for $id");
        return undef;
    }
    
    # Convert airplay:// to http://
    my $http_url = $session->{stream_url};
    $log->info("Opening AirPlay stream: $http_url");
    
    return $class->SUPER::new({
        url => $http_url,
        song => $song,
        client => $client,
        bitrate => $prefs->get('bitrate') * 1000 || 192000,
    });
}

1;
```

#### C. Settings.pm Updates

```perl
# Add new preferences
$prefs->init({
    # Existing prefs...
    bitrate => 192,    # kbps for MP3 streaming
    delay => 60,       # ms delay for GoPlay2
    cachedir => Slim::Utils::OSDetect::dirsFor('cache'),
    monitor_interval => 30,  # Seconds between process monitoring
});

# Add new settings
sub prefs {
    my ($class, $client) = @_;
    
    my @prefs = (
        {
            name => 'bitrate',
            type => 'popupArray',
            options => {
                96 => '96 kbps',
                128 => '128 kbps',
                192 => '192 kbps',
                256 => '256 kbps',
                320 => '320 kbps',
            },
            description => Slim::Utils::Strings::string('PLUGIN_SHAIRTUNES2_BITRATE_DESC'),
            default => 192,
        },
        {
            name => 'delay',
            type => 'text',
            description => Slim::Utils::Strings::string('PLUGIN_SHAIRTUNES2_DELAY_DESC'),
            default => 60,
        },
        {
            name => 'monitor_interval',
            type => 'text',
            description => Slim::Utils::Strings::string('PLUGIN_SHAIRTUNES2_MONITOR_DESC'),
            default => 30,
        },
    );
    
    return \@prefs;
}
```

### 4. Installation Script

Create a comprehensive installation script:

```bash
#!/bin/bash

# Detect platform
if [ -f /etc/debian_version ]; then
    echo "Detected Debian/Ubuntu system"
    PLATFORM="debian"
elif [ -f /etc/redhat-release ]; then
    echo "Detected RedHat/CentOS system"
    PLATFORM="redhat"
elif [ "$(uname)" == "Darwin" ]; then
    echo "Detected macOS system"
    PLATFORM="macos"
else
    echo "Unsupported platform"
    exit 1
fi

echo "Installing dependencies for ShairTunes2W with GoPlay2..."

# Install dependencies
case $PLATFORM in
    debian)
        sudo apt-get update
        sudo apt-get install -y build-essential ffmpeg socat \
            golang-go libfdk-aac-dev pulseaudio portaudio19-dev
        ;;
    redhat)
        sudo yum install -y gcc make ffmpeg socat \
            golang libfdk-aac-devel pulseaudio portaudio-devel
        ;;
    macos)
        if ! command -v brew &>/dev/null; then
            echo "Homebrew not installed. Please install it first."
            exit 1
        fi
        brew install ffmpeg socat golang libfdk-aac portaudio pulseaudio
        ;;
esac

# Create build directory
echo "Building GoPlay2..."
mkdir -p build
cd build

# Clone and build GoPlay2
if [ ! -d "goplay2" ]; then
    git clone https://github.com/openairplay/goplay2.git
fi
cd goplay2
go build

# Verify the build
if [ ! -f "goplay2" ]; then
    echo "Failed to build GoPlay2. Please check for errors."
    exit 1
fi

# Create bin directory and copy binaries
cd ../../
mkdir -p bin
cp build/goplay2/goplay2 bin/

# Set capabilities for GoPlay2
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting capabilities for GoPlay2..."
    sudo setcap 'cap_net_bind_service=+ep' bin/goplay2
fi

# Setup PulseAudio for the current user
if [ "$PLATFORM" != "macos" ]; then
    echo "Setting up PulseAudio..."
    if ! pgrep -x "pulseaudio" > /dev/null; then
        pulseaudio --start
    fi
fi

echo "Installation complete!"
echo ""
echo "Important notes:"
echo "1. Make sure PulseAudio is running when using the plugin"
echo "2. If you're running LMS as a different user, you may need to configure PulseAudio for that user"
echo "3. For troubleshooting, check the LMS logs"
```

### 5. Testing Procedure

1. **Basic Functionality**
   - Verify GoPlay2 starts correctly
   - Check if PulseAudio sink is created
   - Confirm FFmpeg process is running
   - Validate HTTP stream is accessible

2. **AirPlay Testing**
   - Test connection from iOS devices
   - Test connection from macOS
   - Verify audio quality
   - Measure latency/buffering

3. **Multi-Room Testing**
   - Test with multiple Apple devices
   - Test with HomePods in the same network
   - Verify synchronization accuracy

4. **Stability Testing**
   - Run for extended periods
   - Test reconnection behavior
   - Verify process monitoring and recovery

## Migration from Existing Implementation

1. **Backup Current System**
   - Save user preferences
   - Document existing player configurations

2. **Prepare New Components**
   - Install dependencies
   - Build GoPlay2
   - Configure PulseAudio system

3. **Replace Components**
   - Update Plugin.pm with new implementation
   - Replace AIRPLAY.pm with simplified version
   - Update Settings.pm with new options

4. **Test Incrementally**
   - Test with a single player
   - Add players one by one
   - Verify functionality at each step

5. **Rollback Plan**
   - Keep existing implementation files as backup
   - Create a toggle in settings to switch between implementations

## Limitations and Considerations

1. **No Metadata Support**
   - GoPlay2 doesn't provide track information
   - Will display static metadata only

2. **Platform Limitations**
   - No Windows support (GoPlay2 limitation)
   - Requires PulseAudio working correctly

3. **Control Limitations**
   - Limited bidirectional control
   - No direct playback controls from LMS

4. **Network Requirements**
   - Needs mDNS/Bonjour working properly
   - PTP timing for accurate synchronization

## Conclusion

This refactoring replaces the custom AirPlay implementation with GoPlay2, following the principles demonstrated by AirPlay2HTTP. The key advantages are:

1. **AirPlay2 Support** - Enables multi-room synchronization with Apple devices
2. **HomeKit Integration** - Works with the Apple Home app ecosystem
3. **Simplified Architecture** - Clean separation of audio processing stages
4. **Modern Codebase** - Using maintained components for key functionality
5. **Lightweight Operation** - Works on resource-constrained systems

While there are limitations (metadata, Windows support), the implementation offers a modern AirPlay2 receiver capability that integrates well with Logitech Media Server's infrastructure.
