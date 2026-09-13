import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../theme"

Item {
    id: root

    // ==========================================
    // NOTIFICATION STATE
    // ==========================================
    property bool dnd: false
    property bool isCenterOpen: false

    // Active floating toast objects currently on screen
    property var activeToasts: []

    // All stored notifications for history / center
    property var notifications: []

    // Live unread counter
    readonly property int unreadCount: notifications.length

    // Process to focus app window in Hyprland
    Process {
        id: focusProc
    }

    // ==========================================
    // NOTIFICATION SERVER (D-Bus Daemon)
    // ==========================================
    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notif) => {
            root.handleIncoming(notif);
        }
    }

    // Handle new incoming notification
    function handleIncoming(notif) {
        if (!notif) return;

        // Ensure notification is tracked in Quickshell
        notif.tracked = true;

        let item = {
            id: notif.id,
            notif: notif,
            appName: notif.appName && notif.appName.length > 0 ? notif.appName : "System",
            appIcon: notif.appIcon || "",
            summary: notif.summary || "",
            body: notif.body || "",
            urgency: notif.urgency, // 0 = Low, 1 = Normal, 2 = Critical
            desktopEntry: notif.desktopEntry || "",
            image: notif.image || "",
            timeStr: Qt.formatTime(new Date(), "hh:mm"),
            timestamp: Date.now()
        };

        // Add to history (newest at front)
        let list = root.notifications.slice();
        // Remove any existing notification with same ID
        list = list.filter(n => n.id !== notif.id);
        list.unshift(item);
        root.notifications = list;

        // If Do Not Disturb is OFF, display floating toast
        if (!root.dnd) {
            let toasts = root.activeToasts.slice();
            // Remove previous toast with same id if replaced
            toasts = toasts.filter(t => t.id !== notif.id);
            toasts.unshift(item);
            // Cap visible floating toasts to 5 max
            if (toasts.length > 5) {
                toasts.pop();
            }
            root.activeToasts = toasts;
        }

        // Listen for remote close signal
        notif.closed.connect((reason) => {
            root.removeNotification(notif.id);
        });
    }

    // ==========================================
    // TOAST MANAGEMENT
    // ==========================================
    function dismissToast(id) {
        root.activeToasts = root.activeToasts.filter(t => t.id !== id);
    }

    // ==========================================
    // NOTIFICATION MANAGEMENT
    // ==========================================
    function removeNotification(id) {
        dismissToast(id);
        root.notifications = root.notifications.filter(n => n.id !== id);
    }

    function dismissNotification(item) {
        if (!item) return;
        removeNotification(item.id);
        if (item.notif && typeof item.notif.dismiss === "function") {
            try { item.notif.dismiss(); } catch (e) {}
        }
    }

    function dismissAll() {
        for (let item of root.notifications) {
            if (item.notif && typeof item.notif.dismiss === "function") {
                try { item.notif.dismiss(); } catch (e) {}
            }
        }
        root.activeToasts = [];
        root.notifications = [];
    }

    function dismissAppGroup(appName) {
        let remaining = [];
        for (let item of root.notifications) {
            if (item.appName === appName) {
                if (item.notif && typeof item.notif.dismiss === "function") {
                    try { item.notif.dismiss(); } catch (e) {}
                }
            } else {
                remaining.push(item);
            }
        }
        root.activeToasts = root.activeToasts.filter(t => t.appName !== appName);
        root.notifications = remaining;
    }

    // ==========================================
    // ACTION & APP SWITCHING LOGIC
    // ==========================================
    function invokeAction(item, action) {
        if (!item || !action) return;

        if (typeof action.invoke === "function") {
            try { action.invoke(); } catch (e) {}
        }

        // Focus or launch the app
        focusApp(item);

        // Dismiss if not resident
        if (!item.notif || !item.notif.resident) {
            dismissNotification(item);
        } else {
            dismissToast(item.id);
        }
    }

    function focusApp(item) {
        if (!item) return;

        let app = (item.appName || "").replace(/'/g, "");
        let entry = (item.desktopEntry || "").replace(/'/g, "");

        focusProc.command = [
            "sh", "-c",
            "hyprctl clients -j | python3 -c '" +
            "import json, sys, subprocess\n" +
            "app = sys.argv[1].lower() if len(sys.argv) > 1 else \"\"\n" +
            "entry = sys.argv[2].lower() if len(sys.argv) > 2 else \"\"\n" +
            "try:\n" +
            "    clients = json.load(sys.stdin)\n" +
            "    matched = None\n" +
            "    for c in clients:\n" +
            "        c_class = (c.get(\"class\") or \"\").lower()\n" +
            "        c_title = (c.get(\"title\") or \"\").lower()\n" +
            "        c_init = (c.get(\"initialClass\") or \"\").lower()\n" +
            "        if entry and (entry in c_class or entry in c_init):\n" +
            "            matched = c.get(\"address\"); break\n" +
            "        if app and (app in c_class or app in c_init or app in c_title):\n" +
            "            matched = c.get(\"address\"); break\n" +
            "    if matched:\n" +
            "        subprocess.run([\"hyprctl\", \"dispatch\", \"focuswindow\", f\"address:{matched}\"])\n" +
            "    else:\n" +
            "        if entry:\n" +
            "            subprocess.run([\"gtk-launch\", entry])\n" +
            "        elif app:\n" +
            "            subprocess.Popen([app], shell=True)\n" +
            "except Exception:\n" +
            "    pass\n" +
            "' " + JSON.stringify(app) + " " + JSON.stringify(entry)
        ];
        focusProc.running = false;
        focusProc.running = true;
    }

    // ==========================================
    // DRAWER TOGGLE
    // ==========================================
    function toggleCenter() {
        if (isCenterOpen) {
            closeCenter();
        } else {
            openCenter();
        }
    }

    function openCenter() {
        Theme.closePopup();
        isCenterOpen = true;
    }

    function closeCenter() {
        isCenterOpen = false;
    }

    function toggleDnd() {
        dnd = !dnd;
        if (dnd) {
            // Dismiss active toasts on screen when entering DND
            activeToasts = [];
        }
    }
}

