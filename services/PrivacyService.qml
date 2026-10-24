import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What is listening or watching, like the iPhone's orange and green dots,
// plus Caps Lock.
//   mic:    an app is recording from an input (a capture stream). Monitors of
//           an output (visualizers like cava, recorders capturing system
//           sound) don't count.
//   camera: one of your processes holds a /dev/video* device open.
//   caps:   any keyboard's Caps Lock LED is lit.
Item {
  id: privacy

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var micApps: {
    var out = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || !n.isStream || n.isSink || !n.audio) continue
      var p = n.properties || {}
      if (String(p["media.class"] || "") !== "Stream/Input/Audio") continue
      if (String(p["stream.monitor"] || "") === "true" || String(p["stream.capture.sink"] || "") === "true") continue
      var name = p["application.name"] || n.name || ""
      if (out.indexOf(name) === -1) out.push(name)
    }
    return out
  }
  readonly property bool mic: micApps.length > 0
  property bool camera: false
  property bool caps: false

  // Stream properties only fill in once the node is bound.
  PwObjectTracker { objects: privacy.nodes }

  Process {
    id: camProbe
    command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null | head -n1"]
    stdout: StdioCollector { onStreamFinished: privacy.camera = text.trim() !== "" }
  }
  Timer {
    interval: 3000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!camProbe.running) camProbe.running = true
  }

  // sysfs has no change notifications: read the LEDs (in-process) twice a second.
  property var capsLeds: []
  Process {
    running: true
    command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
    stdout: StdioCollector { onStreamFinished: privacy.capsLeds = text.trim().split("\n").filter(s => s) }
  }
  Instantiator {
    id: leds
    model: privacy.capsLeds
    delegate: FileView {
      required property string modelData
      path: modelData + "/brightness"
      blockLoading: true
      printErrors: false
    }
  }
  Timer {
    interval: 500
    repeat: true
    running: privacy.capsLeds.length > 0
    onTriggered: {
      var on = false
      for (var i = 0; i < leds.count; i++) {
        var f = leds.objectAt(i)
        if (!f) continue
        f.reload()
        if (String(f.text()).trim() !== "0" && String(f.text()).trim() !== "") on = true
      }
      privacy.caps = on
    }
  }
}
