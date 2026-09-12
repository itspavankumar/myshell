import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

Scope {
    id: root

    property bool open: false
    property string activeType: "volume" // "volume", "mute", "brightness", "keyboard"
    property real displayValue: 0.0

    Timer {
        id: closeTimer
        interval: 2000
        onTriggered: {
            root.open = false;
        }
    }

    function showOsd(type, value) {
        activeType = type;
        displayValue = value;
        root.open = true;
        closeTimer.restart();
    }

    // ── Brightness logic ──────────────────────────────────────────────
    property real currentBrightness: 1.0

    Process {
        id: brightnessGetter
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4, 1, length($4)-1)}'"]
        running: true
        stdout: SplitParser {
            onRead: out => {
                var val = parseFloat(out.trim());
                if (!isNaN(val)) currentBrightness = val / 100.0;
            }
        }
    }

    Process {
        id: brightnessSetter
        property int delta: 0
        command: ["bash", "-c", "current=$(brightnessctl -m 2>/dev/null | head -n1 | awk -F, '{print substr($4, 1, length($4)-1)}'); new_val=$((current + " + delta + ")); if [ $new_val -lt 5 ]; then new_val=5; fi; if [ $new_val -gt 100 ]; then new_val=100; fi; brightnessctl s ${new_val}% -q; echo $new_val"]
        running: false
        stdout: SplitParser {
            onRead: out => {
                var val = parseFloat(out.trim());
                if (!isNaN(val)) {
                    currentBrightness = val / 100.0;
                    showOsd("brightness", currentBrightness);
                }
            }
        }
    }

    function changeBrightness(d) {
        brightnessSetter.delta = d;
        brightnessSetter.running = true;
    }

    // ── Keyboard Brightness logic ─────────────────────────────────────
    property real currentKbdBrightness: -1.0

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            kbdBrightnessPoller.running = true;
        }
    }

    Process {
        id: kbdBrightnessPoller
        command: ["bash", "-c", "brightnessctl -d '*kbd*' -m 2>/dev/null | head -n1 | awk -F, '{print substr($4, 1, length($4)-1)}'"]
        running: false
        stdout: SplitParser {
            onRead: out => {
                var val = parseFloat(out.trim());
                if (!isNaN(val)) {
                    var newB = val / 100.0;
                    if (currentKbdBrightness !== -1.0 && Math.abs(currentKbdBrightness - newB) > 0.001) {
                        currentKbdBrightness = newB;
                        showOsd("keyboard", currentKbdBrightness);
                    } else if (currentKbdBrightness === -1.0) {
                        currentKbdBrightness = newB;
                    }
                }
            }
        }
    }

    Process {
        id: kbdBrightnessSetter
        property string direction: "+"
        command: ["bash", "-c", "brightnessctl -d '*kbd*' s 1" + direction + " -q"]
        running: false
    }

    function changeKbdBrightness(dir) {
        kbdBrightnessSetter.direction = dir;
        kbdBrightnessSetter.running = true;
    }

    // ── Capslock logic ────────────────────────────────────────────────
    property int capslockState: -1

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            capslockGetter.running = true;
        }
    }

    Process {
        id: capslockGetter
        command: ["bash", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | head -n1"]
        running: false
        stdout: SplitParser {
            onRead: out => {
                var state = parseInt(out.trim());
                if (!isNaN(state)) {
                    if (capslockState !== -1 && capslockState !== state) {
                        capslockState = state;
                        showOsd("capslock", state);
                    } else if (capslockState === -1) {
                        capslockState = state; // initialize silently
                    }
                }
            }
        }
    }

    // ── Global Shortcuts ──────────────────────────────────────────────
    GlobalShortcut {
        name: "osd_volume_up"
        description: "Increase Volume"
        onPressed: {
            if (Pipewire.defaultAudioSink) {
                var newVol = Pipewire.defaultAudioSink.audio.volume + 0.0625;
                if (newVol > 1.0) newVol = 1.0;
                Pipewire.defaultAudioSink.audio.volume = newVol;
                Pipewire.defaultAudioSink.audio.muted = false;
                showOsd("volume", newVol);
            }
        }
    }

    GlobalShortcut {
        name: "osd_volume_down"
        description: "Decrease Volume"
        onPressed: {
            if (Pipewire.defaultAudioSink) {
                var newVol = Pipewire.defaultAudioSink.audio.volume - 0.0625;
                if (newVol < 0.0) newVol = 0.0;
                Pipewire.defaultAudioSink.audio.volume = newVol;
                showOsd("volume", newVol);
            }
        }
    }

    GlobalShortcut {
        name: "osd_volume_mute"
        description: "Toggle Mute"
        onPressed: {
            if (Pipewire.defaultAudioSink) {
                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                showOsd(Pipewire.defaultAudioSink.audio.muted ? "mute" : "volume", Pipewire.defaultAudioSink.audio.volume);
            }
        }
    }

    GlobalShortcut {
        name: "osd_brightness_up"
        description: "Increase Brightness"
        onPressed: {
            changeBrightness(6);
        }
    }

    GlobalShortcut {
        name: "osd_brightness_down"
        description: "Decrease Brightness"
        onPressed: {
            changeBrightness(-6);
        }
    }
    
    GlobalShortcut {
        name: "osd_kbd_brightness_up"
        description: "Increase Keyboard Brightness"
        onPressed: {
            changeKbdBrightness("+");
        }
    }

    GlobalShortcut {
        name: "osd_kbd_brightness_down"
        description: "Decrease Keyboard Brightness"
        onPressed: {
            changeKbdBrightness("-");
        }
    }

    // ── UI ────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            Variables { id: v }

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs:osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            // Set size directly on the window so Wayland centers it
            implicitWidth: 160
            implicitHeight: 160
            exclusiveZone: -1

            // Anchor only to the bottom to allow LayerShell to center it horizontally
            anchors {
                top: false
                bottom: true
                left: false
                right: false
            }

            margins { bottom: 20 }

            color: "transparent"
            visible: root.open && isFocusedScreen()

            function isFocusedScreen() {
                var fm = Hyprland.focusedMonitor;
                if (!fm) return true;
                var sm = Hyprland.monitorFor(modelData);
                return sm && sm.name === fm.name;
            }

            Item {
                id: animContainer
                anchors.fill: parent
                
                scale: root.open ? 1.0 : 0.8
                opacity: root.open ? 1.0 : 0.0

                Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Background using the exact popup colors and borders from Variables.qml
    RectangularShadow {
        anchors.fill: bgRect
        anchors.margins: 2
        radius: Math.max(0, bgRect.radius - 2)
        blur: 10
        color: v.shadowColor
    }


                Rectangle {

                    id: bgRect
                    anchors.fill: parent
                    anchors.margins: 8 // Match popup margin style
                    radius: 16 // Match VolumePopup radius exactly
                    color: v.popupBackground
                    border.color: v.popupBorder
                    border.width: 1

                    // Icon
                    Image {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.activeType === "capslock" ? 0 : -8
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: {
                            if (root.activeType === "mute" || (root.activeType === "volume" && root.displayValue <= 0.0)) {
                                return "images/OSD/audio-volume-muted-symbolic.svg";
                            }
                            if (root.activeType === "volume") {
                                if (root.displayValue < 0.33) return "images/OSD/audio-volume-low-symbolic.svg";
                                if (root.displayValue < 0.66) return "images/OSD/audio-volume-medium-symbolic.svg";
                                return "images/OSD/audio-volume-high-symbolic.svg";
                            }
                            if (root.activeType === "brightness") {
                                if (root.displayValue <= 0.05) return "images/OSD/display-brightness-off-symbolic.svg";
                                if (root.displayValue < 0.33) return "images/OSD/display-brightness-low-symbolic.svg";
                                if (root.displayValue < 0.66) return "images/OSD/display-brightness-medium-symbolic.svg";
                                return "images/OSD/display-brightness-symbolic.svg";
                            }
                            if (root.activeType === "keyboard") {
                                if (root.displayValue <= 0.05) return "images/OSD/keyboard-brightness-off-symbolic.svg";
                                if (root.displayValue < 0.33) return "images/OSD/keyboard-brightness-symbolic.svg";
                                if (root.displayValue < 0.66) return "images/OSD/keyboard-brightness-medium-symbolic.svg";
                                return "images/OSD/keyboard-brightness-high-symbolic.svg";
                            }
                            if (root.activeType === "capslock") {
                                if (root.displayValue > 0) return "images/OSD/capslock-enabled-symbolic.svg";
                                return "images/OSD/capslock-disabled-symbolic.svg";
                            }
                            return "";
                        }
                        
                        // Recolor icon to the global text color to match the design philosophy
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: v.textColor
                            brightness: 1.0
                        }
                        opacity: 0.95
                    }

                    // Progress Bar
                    Row {
                        visible: root.activeType !== "capslock"
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: root.activeType === "keyboard" ? 6 : 2
                        
                        Repeater {
                            model: root.activeType === "keyboard" ? 3 : 16
                            Rectangle {
                                width: root.activeType === "keyboard" ? 36 : 6
                                height: 6
                                radius: 2
                                
                                property int totalSegments: root.activeType === "keyboard" ? 3 : 16
                                property bool filled: root.activeType !== "mute" && index < Math.round(root.displayValue * totalSegments)
                                // Use global variables for filled/empty states
                                color: filled ? v.textColor : v.textPlaceholder
                            }
                        }
                    }
                }
            }
        }
    }
}
