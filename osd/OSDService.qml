import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    property bool initialized: false
    property bool osdVisible: false
    property string osdType: "volume" // "volume" | "brightness" | "kbd" | "capslock" | "mic" | "media"
    property string icon: "󰕾"
    property string title: "VOLUME"
    property real value: 0.5
    property string textValue: "50%"
    property bool isMuted: false

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    function triggerOSD(type, icon, title, val, txt, muted) {
        root.osdType = type;
        root.icon = icon;
        root.title = title;
        root.value = Math.max(0.0, Math.min(1.0, val));
        root.textValue = txt;
        root.isMuted = muted;
        root.osdVisible = true;
        hideTimer.restart();
    }

    // ==========================================
    // AUDIO SERVICE (Pipewire)
    // ==========================================
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool hasSink: sink !== null && sink.audio !== null

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasSource: source !== null && source.audio !== null

    function getVolumeIcon(vol, muted) {
        if (muted || vol <= 0.001) return "󰝟";
        if (vol < 0.33) return "󰕿";
        if (vol < 0.66) return "󰖀";
        return "󰕾";
    }

    function showVolumeOSD() {
        if (!hasSink) return;
        let vol = sink.audio.volume;
        let muted = sink.audio.muted;
        let pct = Math.round(vol * 100);
        triggerOSD("volume", getVolumeIcon(vol, muted), "VOLUME", vol, pct + "%", muted);
    }

    function volumeUp() {
        if (!hasSink) return;
        sink.audio.volume = Math.min(1.0, Math.round((sink.audio.volume + 0.05) * 100) / 100);
        if (sink.audio.muted) sink.audio.muted = false;
        showVolumeOSD();
    }

    function volumeDown() {
        if (!hasSink) return;
        sink.audio.volume = Math.max(0.0, Math.round((sink.audio.volume - 0.05) * 100) / 100);
        showVolumeOSD();
    }

    function toggleMute() {
        if (!hasSink) return;
        sink.audio.muted = !sink.audio.muted;
        showVolumeOSD();
    }

    function showMicOSD() {
        if (!hasSource) return;
        let muted = source.audio.muted;
        triggerOSD("mic", muted ? "󰍭" : "󰍬", "MICROPHONE", muted ? 0.0 : 1.0, muted ? "MUTED" : "ACTIVE", muted);
    }

    function toggleMicMute() {
        if (!hasSource) return;
        source.audio.muted = !source.audio.muted;
        showMicOSD();
    }

    property real lastVolume: -1
    property int lastMuted: -1
    property int lastMicMuted: -1

    Connections {
        target: hasSink ? sink.audio : null
        function onVolumeChanged() {
            if (!root.initialized) return;
            let cur = sink.audio.volume;
            if (root.lastVolume >= 0 && Math.abs(cur - root.lastVolume) > 0.005) {
                root.lastVolume = cur;
                showVolumeOSD();
            } else {
                root.lastVolume = cur;
            }
        }
        function onMutedChanged() {
            if (!root.initialized) return;
            let m = sink.audio.muted ? 1 : 0;
            if (root.lastMuted >= 0 && m !== root.lastMuted) {
                root.lastMuted = m;
                showVolumeOSD();
            } else {
                root.lastMuted = m;
            }
        }
    }

    Connections {
        target: hasSource ? source.audio : null
        function onMutedChanged() {
            if (!root.initialized) return;
            let m = source.audio.muted ? 1 : 0;
            if (root.lastMicMuted >= 0 && m !== root.lastMicMuted) {
                root.lastMicMuted = m;
                showMicOSD();
            } else {
                root.lastMicMuted = m;
            }
        }
    }

    // ==========================================
    // DISPLAY BRIGHTNESS SERVICE
    // ==========================================
    property real brightnessValue: 0.5

    function getBrightnessIcon(val) {
        if (val < 0.33) return "󰃞";
        if (val < 0.66) return "󰃟";
        return "󰃠";
    }

    function showBrightnessOSD() {
        let pct = Math.max(1, Math.min(100, Math.round(brightnessValue * 100)));
        triggerOSD("brightness", getBrightnessIcon(brightnessValue), "BRIGHTNESS", pct / 100.0, pct + "%", false);
    }

    property int pendingBrightnessStep: 0

    Process {
        id: setBrightnessProc
        onExited: {
            if (root.pendingBrightnessStep !== 0) {
                let step = root.pendingBrightnessStep;
                root.pendingBrightnessStep = 0;
                if (step > 0) {
                    setBrightnessProc.command = ["brightnessctl", "set", (step * 5) + "%+"];
                } else {
                    setBrightnessProc.command = ["brightnessctl", "-n", "set", ((-step) * 5) + "%-"];
                }
                setBrightnessProc.running = true;
            }
        }
    }

    function brightnessUp() {
        if (setBrightnessProc.running) {
            root.pendingBrightnessStep++;
        } else {
            setBrightnessProc.command = ["brightnessctl", "set", "5%+"];
            setBrightnessProc.running = true;
        }
    }

    function brightnessDown() {
        if (setBrightnessProc.running) {
            root.pendingBrightnessStep--;
        } else {
            setBrightnessProc.command = ["brightnessctl", "-n", "set", "5%-"];
            setBrightnessProc.running = true;
        }
    }

    // ==========================================
    // KEYBOARD BACKLIGHT SERVICE
    // ==========================================
    property int kbdLevel: 1
    property int kbdMaxLevel: 3
    property real kbdValue: 0.33
    property int pendingKbdStep: 0

    function showKbdOSD() {
        let pct = Math.round(kbdValue * 100);
        triggerOSD("kbd", "󰌌", "KEYBOARD", kbdValue, pct + "%", kbdLevel === 0);
    }

    Process {
        id: setKbdProc
        onExited: {
            if (root.pendingKbdStep !== 0) {
                let step = root.pendingKbdStep;
                root.pendingKbdStep = 0;
                let arg = step > 0 ? (step + "+") : ((-step) + "-");
                setKbdProc.command = ["brightnessctl", "--device=asus::kbd_backlight", "set", arg];
                setKbdProc.running = true;
            }
        }
    }

    function kbdBrightnessUp() {
        if (setKbdProc.running) {
            root.pendingKbdStep++;
        } else {
            setKbdProc.command = ["brightnessctl", "--device=asus::kbd_backlight", "set", "1+"];
            setKbdProc.running = true;
        }
    }

    function kbdBrightnessDown() {
        if (setKbdProc.running) {
            root.pendingKbdStep--;
        } else {
            setKbdProc.command = ["brightnessctl", "--device=asus::kbd_backlight", "set", "1-"];
            setKbdProc.running = true;
        }
    }

    // ==========================================
    // CAPS LOCK SERVICE
    // ==========================================
    property bool capsLockOn: false

    function showCapsOSD() {
        triggerOSD("capslock", "󰪛", "CAPS LOCK", capsLockOn ? 1.0 : 0.0, capsLockOn ? "ON" : "OFF", !capsLockOn);
    }

    // ==========================================
    // HARDWARE / KERNEL WATCHER PROCESS (Self-contained, no external scripts)
    // ==========================================
    Process {
        id: osdWatcherProc
        command: [
            "sh", "-c",
            "last_c=''; last_k=''; last_b=''; " +
            "c_path=$(ls /sys/class/leds/*capslock*/brightness 2>/dev/null | head -n 1); " +
            "k_path=$(ls /sys/class/leds/*kbd_backlight*/brightness 2>/dev/null | head -n 1); " +
            "b_path=$(ls /sys/class/backlight/*/actual_brightness 2>/dev/null | head -n 1); " +
            "bm_path=$(ls /sys/class/backlight/*/max_brightness 2>/dev/null | head -n 1); " +
            "bm=1; [ -n \"$bm_path\" ] && read -r bm < \"$bm_path\" 2>/dev/null; [ -z \"$bm\" ] && bm=1; " +
            "[ -n \"$c_path\" ] && read -r last_c < \"$c_path\" 2>/dev/null; " +
            "[ -n \"$k_path\" ] && read -r last_k < \"$k_path\" 2>/dev/null; " +
            "[ -n \"$b_path\" ] && read -r last_b < \"$b_path\" 2>/dev/null; " +
            "init_pct=$(( (last_b * 100 + bm / 2) / bm )); [ \"$init_pct\" -lt 1 ] && init_pct=1; [ \"$init_pct\" -gt 100 ] && init_pct=100; echo \"INIT_BRI:$init_pct\"; " +
            "while true; do " +
            "  if [ -n \"$c_path\" ]; then read -r c < \"$c_path\" 2>/dev/null; if [ \"$c\" != \"$last_c\" ]; then last_c=\"$c\"; echo \"CAPS:$c\"; fi; fi; " +
            "  if [ -n \"$k_path\" ]; then read -r k < \"$k_path\" 2>/dev/null; if [ \"$k\" != \"$last_k\" ]; then last_k=\"$k\"; echo \"KBD:$k\"; fi; fi; " +
            "  if [ -n \"$b_path\" ]; then read -r b < \"$b_path\" 2>/dev/null; if [ \"$b\" != \"$last_b\" ]; then last_b=\"$b\"; pct=$(( (b * 100 + bm / 2) / bm )); [ \"$pct\" -lt 1 ] && pct=1; [ \"$pct\" -gt 100 ] && pct=100; echo \"BRI:$pct\"; fi; fi; " +
            "  sleep 0.02; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;

                if (line.startsWith("INIT_BRI:")) {
                    let pct = parseInt(line.slice(9).trim());
                    if (!isNaN(pct)) {
                        root.brightnessValue = pct / 100.0;
                    }
                } else if (line.startsWith("CAPS:")) {
                    let on = line.slice(5).trim() === "1";
                    root.capsLockOn = on;
                    if (root.initialized) {
                        root.showCapsOSD();
                    }
                } else if (line.startsWith("KBD:")) {
                    let lvl = parseInt(line.slice(4).trim());
                    if (!isNaN(lvl)) {
                        root.kbdLevel = lvl;
                        root.kbdValue = lvl / 3.0;
                        if (root.initialized) {
                            root.showKbdOSD();
                        }
                    }
                } else if (line.startsWith("BRI:")) {
                    let pct = parseInt(line.slice(4).trim());
                    if (!isNaN(pct)) {
                        root.brightnessValue = pct / 100.0;
                        if (root.initialized) {
                            root.showBrightnessOSD();
                        }
                    }
                }
            }
        }
        running: true
    }

    // ==========================================
    // MEDIA CONTROLS SERVICE
    // ==========================================
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players.length > 0 ? players[0] : null;
    }

    function mediaPlayPause() {
        if (activePlayer && activePlayer.canControl) {
            activePlayer.togglePlaying();
            let isPlaying = activePlayer.playbackState === MprisPlaybackState.Playing;
            triggerOSD("media", isPlaying ? "󰏤" : "󰐊", "MEDIA", 1.0, isPlaying ? "PAUSED" : "PLAYING", false);
        }
    }

    function mediaNext() {
        if (activePlayer && activePlayer.canGoNext) {
            activePlayer.next();
            triggerOSD("media", "󰒭", "MEDIA", 1.0, "NEXT TRACK", false);
        }
    }

    function mediaPrev() {
        if (activePlayer && activePlayer.canGoPrevious) {
            activePlayer.previous();
            triggerOSD("media", "󰒮", "MEDIA", 1.0, "PREVIOUS TRACK", false);
        }
    }

    // ==========================================
    // HYPRLAND GLOBAL SHORTCUTS
    // ==========================================
    GlobalShortcut { appid: "quickshell"; name: "osd_volume_up"; onPressed: root.volumeUp() }
    GlobalShortcut { appid: "quickshell"; name: "osd_volume_down"; onPressed: root.volumeDown() }
    GlobalShortcut { appid: "quickshell"; name: "osd_volume_mute"; onPressed: root.toggleMute() }
    GlobalShortcut { appid: "quickshell"; name: "osd_mic_mute"; onPressed: root.toggleMicMute() }

    GlobalShortcut { appid: "quickshell"; name: "osd_brightness_up"; onPressed: root.brightnessUp() }
    GlobalShortcut { appid: "quickshell"; name: "osd_brightness_down"; onPressed: root.brightnessDown() }

    GlobalShortcut { appid: "quickshell"; name: "osd_kbd_brightness_up"; onPressed: root.kbdBrightnessUp() }
    GlobalShortcut { appid: "quickshell"; name: "osd_kbd_brightness_down"; onPressed: root.kbdBrightnessDown() }

    GlobalShortcut { appid: "quickshell"; name: "osd_media_play_pause"; onPressed: root.mediaPlayPause() }
    GlobalShortcut { appid: "quickshell"; name: "osd_media_next"; onPressed: root.mediaNext() }
    GlobalShortcut { appid: "quickshell"; name: "osd_media_prev"; onPressed: root.mediaPrev() }

    Timer {
        id: initTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            if (root.hasSink) {
                root.lastVolume = root.sink.audio.volume;
                root.lastMuted = root.sink.audio.muted ? 1 : 0;
            }
            if (root.hasSource) {
                root.lastMicMuted = root.source.audio.muted ? 1 : 0;
            }
            root.initialized = true;
        }
    }
}
