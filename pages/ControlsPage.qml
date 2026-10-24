import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../components"

// Controls: quick toggles (Wi-Fi, Bluetooth, Do Not Disturb, night light,
// microphone, stay awake), who is using the microphone or camera, and a
// month calendar. Every toggle goes through Omarchy's own command, so the
// bar, its OSD and its state files stay in step.
Page {
  id: page

  property var island
  implicitHeight: col.implicitHeight + 8

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: page.source ? [page.source] : [] }

  // State only a command can tell: read when the page opens and after a toggle.
  property bool nightlight: false
  property bool stayAwake: false
  Process {
    id: probe
    command: ["sh", "-c", "omarchy-toggle-nightlight --status; omarchy-toggle-idle status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.trim().split("\n")
        try { page.nightlight = JSON.parse(l[0]).enabled === true } catch (e) {}
        try { page.stayAwake = JSON.parse(l[1]).enabled === true } catch (e) {}
      }
    }
  }
  Timer { id: reprobe; interval: 700; onTriggered: probe.running = true }
  onShownChanged: if (shown) { probe.running = true; grid.month = new Date().getMonth(); grid.year = new Date().getFullYear() }

  function run(cmd) { Quickshell.execDetached(cmd); reprobe.restart() }

  component Toggle: Rectangle {
    id: t
    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property color tone: Theme.blue
    signal toggled()
    width: (col.width - 20) / 3
    height: 62
    radius: 18
    opacity: available ? 1 : 0.4
    color: on ? Qt.rgba(tone.r, tone.g, tone.b, mouse.containsMouse ? 0.34 : 0.26) : mouse.containsMouse ? Theme.fillHover : Theme.fill
    Behavior on color { ColorAnimation { duration: Theme.ms(160) } }
    Icon {
      x: 14
      anchors.verticalCenter: parent.verticalCenter
      name: t.icon
      size: 20
      color: t.on ? t.tone : Theme.secondary
    }
    Column {
      x: 44
      width: parent.width - 52
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Label { width: parent.width; text: t.title; font.pixelSize: 13; strong: true }
      Label { width: parent.width; text: t.detail || (t.on ? I18n.t("Aktif") : I18n.t("Kapalı")); font.pixelSize: 11; color: Theme.secondary }
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: t.available
      cursorShape: Qt.PointingHandCursor
      onClicked: t.toggled()
    }
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checked: on
    Accessible.onPressAction: if (available) toggled()
  }

  Column {
    id: col
    width: parent.width
    spacing: 12

    Grid {
      columns: 3
      spacing: 10
      Toggle {
        icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
        title: I18n.t("Wi-Fi")
        on: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
      }
      Toggle {
        icon: "bluetooth"
        title: I18n.t("Bluetooth")
        available: page.adapter !== null
        on: page.adapter !== null && page.adapter.enabled
        // Omarchy's command, not adapter.enabled: it also persists the choice.
        onToggled: page.run(["omarchy-bluetooth-power", on ? "off" : "on"])
      }
      Toggle {
        icon: "bell-off"
        title: I18n.t("Rahatsız etme")
        tone: Theme.orange
        on: island.notifications.dnd
        onToggled: island.notifications.toggleDnd()
      }
      Toggle {
        icon: "moon"
        title: I18n.t("Gece ışığı")
        tone: Theme.orange
        on: page.nightlight
        onToggled: page.run(["omarchy-toggle-nightlight"])
      }
      Toggle {
        readonly property bool muted: page.source && page.source.audio ? page.source.audio.muted : true
        icon: muted ? "mic-off" : "mic"
        title: I18n.t("Mikrofon")
        tone: Theme.red
        available: page.source !== null
        on: muted
        detail: muted ? I18n.t("Sessiz") : island.privacy.mic ? island.privacy.micApps.join(", ") : I18n.t("Aktif")
        onToggled: page.run(["omarchy-audio-input-mute"])
      }
      Toggle {
        icon: "cup"
        title: I18n.t("Uyanık kal")
        tone: Theme.green
        on: page.stayAwake
        onToggled: page.run(["omarchy-toggle-idle"])
      }
    }

    // ---- in use right now
    Row {
      visible: island.privacy.mic || island.privacy.camera
      x: 4
      spacing: 14
      Row {
        visible: island.privacy.mic
        spacing: 6
        Rectangle { width: 8; height: 8; radius: 4; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
        Label { text: I18n.t("Mikrofon kullanımda: ") + island.privacy.micApps.join(", "); font.pixelSize: 12; color: Theme.orange }
      }
      Row {
        visible: island.privacy.camera
        spacing: 6
        Rectangle { width: 8; height: 8; radius: 4; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
        Label { text: I18n.t("Kamera kullanımda"); font.pixelSize: 12; color: Theme.green }
      }
    }

    // ---- calendar
    Rectangle {
      width: parent.width
      height: cal.implicitHeight + 24
      radius: 18
      color: Theme.fill
      Column {
        id: cal
        x: 12; y: 12
        width: parent.width - 24
        spacing: 6
        Item {
          width: parent.width
          height: 28
          Label {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale(island.localeName).toString(new Date(grid.year, grid.month, 1), "MMMM yyyy")
            font.pixelSize: 14
            strong: true
          }
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            IslandButton {
              size: 28; icon: "chevron-left"; iconSize: 14; filled: false
              accessibleName: I18n.t("Önceki ay")
              onClicked: { if (grid.month === 0) { grid.month = 11; grid.year-- } else grid.month-- }
            }
            IslandButton {
              size: 28; icon: "chevron-right"; iconSize: 14; filled: false
              accessibleName: I18n.t("Sonraki ay")
              onClicked: { if (grid.month === 11) { grid.month = 0; grid.year++ } else grid.month++ }
            }
          }
        }
        DayOfWeekRow {
          width: parent.width
          locale: grid.locale
          delegate: Label {
            required property string shortName
            text: shortName
            font.pixelSize: 11
            color: Theme.tertiary
            horizontalAlignment: Text.AlignHCenter
          }
        }
        MonthGrid {
          id: grid
          width: parent.width
          // Cells take their height from the grid, not the other way round.
          height: 6 * 26
          locale: Qt.locale(island.localeName)
          month: new Date().getMonth()
          year: new Date().getFullYear()
          delegate: Item {
            id: cell
            required property int day
            required property int month
            required property bool today
            implicitHeight: 26
            Rectangle {
              anchors.centerIn: parent
              width: 24; height: 24; radius: 12
              visible: cell.today
              color: Theme.red
            }
            Label {
              anchors.fill: parent
              horizontalAlignment: Text.AlignHCenter
              text: cell.day
              font.pixelSize: 12
              tabular: true
              strong: cell.today
              opacity: cell.month === grid.month ? 1 : 0.3
            }
          }
        }
      }
    }
  }
}
