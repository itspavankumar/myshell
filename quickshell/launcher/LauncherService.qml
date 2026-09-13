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

    property var allApps: []
    property var filteredApps: []

    Process {
        id: termLaunchProc
    }

    function refreshApps() {
        let raw = DesktopEntries.applications.values;
        let list = [];
        let seen = {};

        for (let i = 0; i < raw.length; i++) {
            let app = raw[i];
            if (!app || app.noDisplay || !app.name || !app.name.trim()) continue;
            
            // Deduplicate by name if command is identical
            let key = (app.name + "::" + (app.execString || app.id)).toLowerCase();
            if (seen[key]) continue;
            seen[key] = true;

            list.push(app);
        }

        // Sort alphabetically case-insensitive
        list.sort((a, b) => {
            let na = (a.name || "").toLowerCase();
            let nb = (b.name || "").toLowerCase();
            return na.localeCompare(nb);
        });

        root.allApps = list;
        updateFiltered();
    }

    function updateFiltered() {
        let q = root.searchQuery.trim().toLowerCase();
        if (!q) {
            root.filteredApps = root.allApps;
            root.selectedIndex = 0;
            return;
        }

        let prefixMatches = [];
        let nameMatches = [];
        let otherMatches = [];

        for (let i = 0; i < root.allApps.length; i++) {
            let app = root.allApps[i];
            let name = (app.name || "").toLowerCase();
            
            if (name.startsWith(q)) {
                prefixMatches.push(app);
            } else if (name.includes(q)) {
                nameMatches.push(app);
            } else {
                let gen = (app.genericName || "").toLowerCase();
                let com = (app.comment || "").toLowerCase();
                let exec = (app.execString || "").toLowerCase();
                let catMatch = (app.categories || []).some(c => c.toLowerCase().includes(q));
                let keyMatch = (app.keywords || []).some(k => k.toLowerCase().includes(q));

                if (gen.includes(q) || com.includes(q) || exec.includes(q) || catMatch || keyMatch) {
                    otherMatches.push(app);
                }
            }
        }

        root.filteredApps = prefixMatches.concat(nameMatches).concat(otherMatches);
        root.selectedIndex = 0;
    }

    onSearchQueryChanged: {
        updateFiltered();
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.refreshApps();
        }
    }

    Component.onCompleted: {
        refreshApps();
    }

    function open() {
        Theme.closePopup();
        searchQuery = "";
        selectedIndex = 0;
        updateFiltered();
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

    function launchIndex(idx) {
        if (idx < 0 || idx >= filteredApps.length) return;
        let app = filteredApps[idx];
        launch(app);
    }

    function launch(app) {
        if (!app) return;
        close();
        if (app.runInTerminal) {
            termLaunchProc.command = ["ghostty", "-e"].concat(app.command);
            termLaunchProc.running = true;
        } else {
            app.execute();
        }
    }

    // ==========================================
    // HYPRLAND GLOBAL SHORTCUTS
    // ==========================================
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher_toggle"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "toggle_launcher"
        onPressed: root.toggle()
    }
}
