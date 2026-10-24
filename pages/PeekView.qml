import QtQuick
import "../components"

// Brief banner: icon (or artwork / an agent's mark) on the left, two lines of text.
Page {
  id: view

  property var island
  readonly property var info: island.peekData
  readonly property bool isAgent: info.icon.indexOf("agent") === 0
  readonly property bool isApp: info.icon.indexOf("app:") === 0
  readonly property bool hasProgress: info.progress !== undefined && info.progress >= 0
  readonly property string agentLogo: isAgent ? island.logoFor(info.icon.split(":")[1] || island.agentId) : ""

  Accessible.role: Accessible.AlertMessage
  Accessible.name: info.title + (info.subtitle ? ", " + info.subtitle : "")

  Item {
    id: lead
    x: 14
    width: 38; height: 38
    anchors.verticalCenter: parent.verticalCenter

    Art {
      anchors.fill: parent
      visible: view.info.icon === "music"
      source: view.island.music.artUrl
      radius: 10
    }
    Rectangle {
      anchors.fill: parent
      visible: view.info.icon !== "music"
      radius: width / 2
      color: Qt.rgba(view.info.tint.r, view.info.tint.g, view.info.tint.b, 0.18)
      Icon {
        anchors.centerIn: parent
        visible: !view.info.glyph
        size: view.isApp ? 26 : 20
        name: view.isApp ? "" : view.isAgent ? (view.agentLogo ? "" : "sparkles") : view.info.icon
        source: view.isApp ? view.info.icon.substring(4) : view.agentLogo
        color: view.info.tint
      }
      // An OSD sent with a raw Nerd Font glyph instead of a known icon.
      Text {
        anchors.centerIn: parent
        visible: !!view.info.glyph
        textFormat: Text.PlainText
        text: view.info.glyph || ""
        font.family: Theme.icons
        font.pixelSize: 18
        color: view.info.tint
      }
    }
  }

  Column {
    anchors.left: lead.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: view.info.icon === "music" ? 50 : 20
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Label {
      width: parent.width
      text: view.info.title
      font.pixelSize: 15
      strong: true
    }
    Label {
      width: parent.width
      visible: text !== "" && !view.hasProgress
      text: view.info.subtitle
      font.pixelSize: 13
      color: Theme.secondary
    }
    // Volume, brightness…: a level bar instead of the second line.
    Item {
      visible: view.hasProgress
      width: parent.width
      height: 16
      Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: percent.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.fill
        Rectangle {
          height: parent.height
          radius: 3
          width: parent.width * Math.max(0, Math.min(1, view.info.progress))
          color: view.info.tint
          Behavior on width { enabled: !Theme.reduceMotion; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
      }
      Label {
        id: percent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        horizontalAlignment: Text.AlignRight
        text: view.info.subtitle
        font.pixelSize: 12
        tabular: true
        color: Theme.secondary
      }
    }
  }

  Equalizer {
    visible: view.info.icon === "music"
    anchors.right: parent.right
    anchors.rightMargin: 18
    anchors.verticalCenter: parent.verticalCenter
    playing: view.island.music.playing
    color: view.island.music.accent
    maxHeight: 20
  }
}
