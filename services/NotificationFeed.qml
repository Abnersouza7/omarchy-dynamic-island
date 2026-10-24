import QtQuick
import Quickshell
import Quickshell.Io

// Omarchy's notifications, read from where its daemon already keeps them:
// one JSON file per on-screen popup under ~/.local/state/omarchy/notifications/,
// moved into history/ when it leaves the screen. Nothing here writes there;
// actions go through the daemon's own IPC (`omarchy-shell notifications …`).
// A file appearing in the popup directory is a new notification: `arrived`.
// Silenced ones (Do Not Disturb) go straight to history and never arrive.
Item {
  id: feed

  readonly property string dir: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/notifications/"
  property var items: []        // newest first: { file, live, app, appIcon, summary, body, image, urgency, timestamp }
  property bool dnd: false
  property int unseen: 0        // arrived since the notifications page was last open
  property var seen: ({})
  property bool primed: false

  signal arrived(var n)

  function iconFor(n) {
    var i = n.image || n.appIcon || ""
    if (i.indexOf("/") === 0) return i
    if (i.indexOf("file://") === 0) return i.substring(7)
    if (i.indexOf("image://") === 0) return i
    // Senders often leave the icon out; the app's name usually is one.
    return Quickshell.iconPath(i || String(n.app || "").toLowerCase().replace(/\s+/g, "-"), true)
  }
  // The daemon accepts body markup; the island shows plain text.
  function plain(s) { return String(s || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'") }

  function ipc(args) { Quickshell.execDetached(["omarchy-shell", "-q", "notifications"].concat(args)) }
  function invokeLast() { ipc(["invokeLast"]) }
  function toggleDnd() { dnd = !dnd; ipc(["toggleDnd"]) }
  function clearAll() { ipc(["dismissAll"]); ipc(["clear"]) }

  // `tag` file per line, then its JSON: live popups first, then history.
  Process {
    id: reader
    command: ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; for f in *.json history/*.json; do [ -f \"$f\" ] && printf '%s\\t%s\\n' \"$f\" \"$(head -c 65536 \"$f\" | tr '\\n' ' ')\"; done", "--", feed.dir]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [], next = {}
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab < 0) continue
          var file = lines[i].substring(0, tab)
          try {
            var n = JSON.parse(lines[i].substring(tab + 1))
            n.file = file
            n.live = file.indexOf("history/") !== 0
            n.summary = feed.plain(n.summary)
            n.body = feed.plain(n.body)
            out.push(n)
            if (n.live) {
              next[file] = true
              if (feed.primed && !feed.seen[file]) { feed.unseen++; feed.arrived(n) }
            }
          } catch (e) {}
        }
        out.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
        feed.items = out
        feed.seen = next
        feed.primed = true
      }
    }
  }
  Timer {
    id: debounce
    interval: 120
    onTriggered: if (!reader.running) reader.running = true; else restart()
  }

  // The popup directory changes on every arrival, update, expiry and dismiss.
  // (The directories may not exist yet on a fresh install: try again later.)
  Process {
    id: watcher
    running: true
    command: ["inotifywait", "-m", "-q", "-e", "close_write,moved_to,moved_from,delete", "--format", "%f", feed.dir, feed.dir + "history/"]
    stdout: SplitParser { onRead: debounce.restart() }
    onExited: rewatch.start()
  }
  Timer { id: rewatch; interval: 5000; onTriggered: watcher.running = true }

  FileView {
    path: feed.dir + "../notifications.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { feed.dnd = JSON.parse(text()).dnd === true } catch (e) {} }
  }

  Component.onCompleted: reader.running = true
}
