import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    property bool isOpen: false
    property string searchQuery: ""
    property int selectedIndex: 0

    property var history: []
    property var filteredHistory: []
    property var rawLines: []

    Process {
        id: clipListProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line) return;
                line = line.replace(/[\r\n]+$/, "");
                let tab = line.indexOf("\t");
                if (tab !== -1) {
                    let id = line.substring(0, tab);
                    let content = line.substring(tab + 1);
                    root.rawLines.push({ id: id, preview: content, raw: line });
                }
            }
        }
        onExited: {
            root.history = root.rawLines;
            root.updateFiltered();
        }
    }

    Process {
        id: copyProc
    }

    Process {
        id: deleteProc
    }

    function refresh() {
        root.rawLines = [];
        clipListProc.running = false;
        clipListProc.running = true;
    }

    function updateFiltered() {
        let q = root.searchQuery.trim().toLowerCase();
        if (!q) {
            root.filteredHistory = root.history;
            root.selectedIndex = 0;
            return;
        }

        let matched = [];
        for (let i = 0; i < root.history.length; i++) {
            let item = root.history[i];
            if (item.preview && item.preview.toLowerCase().includes(q)) {
                matched.push(item);
            }
        }

        root.filteredHistory = matched;
        root.selectedIndex = 0;
    }

    onSearchQueryChanged: {
        updateFiltered();
    }

    function open() {
        Theme.closePopup();
        searchQuery = "";
        selectedIndex = 0;
        refresh();
        isOpen = true;
    }

    function close() {
        isOpen = false;
        searchQuery = "";
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    function copyIndex(idx) {
        if (idx < 0 || idx >= filteredHistory.length) return;
        let item = filteredHistory[idx];
        copyProc.command = ["sh", "-c", "echo " + JSON.stringify(item.raw) + " | cliphist decode | wl-copy"];
        copyProc.running = true;
        close();
    }

    function deleteIndex(idx) {
        if (idx < 0 || idx >= filteredHistory.length) return;
        let item = filteredHistory[idx];
        deleteProc.command = ["sh", "-c", "echo " + JSON.stringify(item.raw) + " | cliphist delete"];
        deleteProc.running = true;

        let newHist = [];
        for (let i = 0; i < history.length; i++) {
            if (history[i].id !== item.id) {
                newHist.push(history[i]);
            }
        }
        history = newHist;
        updateFiltered();
    }

    function clearAll() {
        deleteProc.command = ["cliphist", "wipe"];
        deleteProc.running = true;
        history = [];
        filteredHistory = [];
        close();
    }

    // ==========================================
    // HYPRLAND GLOBAL SHORTCUTS
    // ==========================================
    GlobalShortcut {
        appid: "quickshell"
        name: "clipboard_toggle"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "toggle_clipboard"
        onPressed: root.toggle()
    }
}

