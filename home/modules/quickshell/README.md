# Quickshell System Control Modules

This Quickshell configuration includes modules for controlling volume, brightness, and monitoring system resources.

## Features

### 🔊 Volume Control

- **VolumeWidget**: Singleton service for audio control via PipeWire
- **VolumeDisplay**: Visual component showing volume level and mute status
- Click to toggle mute, scroll to adjust volume
- Support for both output and input (microphone) devices

### 💡 Brightness Control

- **BrightnessWidget**: Singleton service for display brightness control
- **BrightnessDisplay**: Visual component showing current brightness
- Scroll to adjust brightness
- Uses `brightnessctl` for built-in displays

### 📊 System Monitoring

- **SystemMonitor**: Singleton service monitoring system resources
- **SystemDisplay**: Visual component showing CPU, memory, storage usage
- Real-time CPU usage and temperature monitoring
- Memory usage from `/proc/meminfo`
- Storage usage from `df` command
- Temperature from `lm-sensors` (if available)

### ⌨️ Keyboard Shortcuts

- Volume keys (if supported by your WM)
- Brightness keys (if supported by your WM)
- Custom shortcuts with Ctrl+Alt+:
  - `+`/`=`: Increase volume
  - `-`: Decrease volume
  - `M`: Toggle mute
  - `Up`: Increase brightness
  - `Down`: Decrease brightness

## Components

### Bar Layout

The bar now includes three sections:

- **Left**: System monitoring (CPU, memory, temperature, storage)
- **Center**: Clock
- **Right**: Volume and brightness controls

### Optional Control Panel

`ControlPanel.qml` provides a detailed popup interface with:

- Volume slider and mute button
- Brightness slider
- Detailed system information display

## Configuration

### Dependencies

The following packages are automatically included via Nix:

- `brightnessctl` - For brightness control
- `lm_sensors` - For temperature monitoring
- PipeWire (for audio) - Usually already available in Hyprland setups

### Customization

You can adjust these properties in the respective modules:

**VolumeWidget.qml**:

```qml
property real audioIncrement: 0.05  // Volume step size
```

**BrightnessWidget.qml**:

```qml
property real brightnessIncrement: 0.1  // Brightness step size
```

**SystemMonitor.qml**:

```qml
property int updateInterval: 3000  // Update frequency in milliseconds
```

## Usage

### Basic Usage

The modules work automatically once Quickshell is running. The bar will display:

- System info on the left
- Clock in the center
- Volume and brightness controls on the right

### Mouse Interactions

- **Volume**: Click to mute/unmute, scroll to adjust
- **Brightness**: Scroll to adjust
- **System info**: Visual indicators only

### Adding the Control Panel

To show the control panel as a popup or separate window, you can:

1. Add it to your shell.qml:

```qml
// In shell.qml, add:
ControlPanel {
  // Configure as needed
}
```

2. Or create a keybinding in your window manager to show it conditionally.

### Color Coding

- **Red**: Critical levels (high temperature, low battery, etc.)
- **Orange**: Warning levels
- **White**: Normal levels
- **Green**: Good levels (for sliders)

## Troubleshooting

### Brightness not working

- Ensure `brightnessctl` has proper permissions
- You may need to add your user to the `video` group
- For external monitors, you might need `ddcutil` (see Caelestia config for reference)

### Temperature not showing

- Install and configure `lm-sensors`: `sudo sensors-detect`
- Run `sensors` in terminal to test

### Volume not working

- Ensure PipeWire is running and configured
- Check `pw-top` or similar tools for audio devices

### Performance

- The default update interval is 3 seconds for system monitoring
- Adjust `updateInterval` in SystemMonitor.qml if needed
- File watching for `/proc` files is efficient and shouldn't impact performance

## Extending

You can easily extend these modules:

1. Add new metrics to SystemMonitor.qml
2. Create additional display components
3. Add more keyboard shortcuts in Shortcuts.qml
4. Customize colors and layouts in the display components

The singleton pattern makes it easy to access these services from anywhere in your Quickshell configuration.
