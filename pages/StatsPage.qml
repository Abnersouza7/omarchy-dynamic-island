import QtQuick
import "../components"

// Stats: CPU, memory, network and disk with their history. Clicking CPU or
// Memory lists the apps using the most of it.
Page {
  id: page

  property var island
  readonly property var stats: island.stats
  implicitHeight: col.implicitHeight + 8

  onShownChanged: if (!shown) stats.topKind = ""

  component Card: Rectangle {
    id: card
    property string icon: ""
    property string title: ""
    property string value: ""
    property string detail: ""
    property var history: []
    property real max: 1
    property color tone: Theme.fg
    property string kind: ""
    readonly property bool selected: kind !== "" && page.stats.topKind === kind
    width: (col.width - 10) / 2
    height: 96
    radius: 18
    color: mouse.containsMouse && kind !== "" ? Theme.fillHover : Theme.fill
    border.width: selected ? 1 : 0
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.6)

    Sparkline {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 1
      height: 40
      values: card.history
      max: card.max
      color: card.tone
    }
    Row {
      x: 14; y: 12
      spacing: 7
      Icon { name: card.icon; size: 15; color: card.tone; anchors.verticalCenter: parent.verticalCenter }
      Label { text: card.title; font.pixelSize: 12; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
    }
    Label {
      x: 14; y: 32
      width: parent.width - 28
      text: card.value
      font.pixelSize: 20
      strong: true
      tabular: true
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: 14
      y: 12
      text: card.detail
      font.pixelSize: 11
      tabular: true
      color: Theme.tertiary
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: card.kind !== ""
      cursorShape: Qt.PointingHandCursor
      onClicked: if (card.selected) page.stats.topKind = ""; else page.stats.top(card.kind)
    }
    Accessible.role: card.kind ? Accessible.Button : Accessible.StaticText
    Accessible.name: title + " " + value
  }

  Column {
    id: col
    width: parent.width
    spacing: 10

    Grid {
      columns: 2
      spacing: 10
      Card {
        icon: "cpu"; title: I18n.t("İşlemci"); kind: "cpu"
        value: Math.round(page.stats.cpu * 100) + "%"
        history: page.stats.cpuHistory
        tone: page.stats.cpu >= 0.85 ? Theme.red : Theme.blue
      }
      Card {
        icon: "chart"; title: I18n.t("Bellek"); kind: "mem"
        value: Math.round(page.stats.mem * 100) + "%"
        detail: page.stats.memUsedGb.toFixed(1) + " / " + Math.round(page.stats.memTotalGb) + " GB"
        history: page.stats.memHistory
        tone: page.stats.mem >= 0.9 ? Theme.red : Theme.green
      }
      Card {
        icon: "globe"; title: I18n.t("Ağ")
        value: "↓ " + page.stats.rate(page.stats.rx)
        detail: "↑ " + page.stats.rate(page.stats.tx)
        history: page.stats.netHistory
        max: Math.max(1024, Math.max.apply(null, page.stats.netHistory.concat([0])))
        tone: Theme.orange
      }
      Card {
        icon: "folder"; title: I18n.t("Disk")
        value: Math.round(page.stats.disk * 100) + "%"
        detail: Math.round(page.stats.diskUsedGb) + " / " + Math.round(page.stats.diskTotalGb) + " GB"
        tone: page.stats.disk >= 0.9 ? Theme.red : Theme.secondary
      }
    }

    // ---- top apps for the selected card
    Column {
      visible: page.stats.topKind !== ""
      width: parent.width
      spacing: 2
      Label {
        visible: page.stats.topList.length === 0
        width: parent.width
        height: 30
        horizontalAlignment: Text.AlignHCenter
        text: I18n.t("Ölçülüyor…")
        font.pixelSize: 12
        color: Theme.tertiary
      }
      Repeater {
        model: page.stats.topList
        delegate: Item {
          required property var modelData
          width: parent.width
          height: 26
          readonly property real share: page.stats.topKind === "cpu" ? modelData.value / 100 : modelData.value / Math.max(1, page.stats.memTotalGb)
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            radius: 7
            width: Math.max(4, parent.width * Math.min(1, parent.share))
            color: Qt.rgba(1, 1, 1, 0.06)
          }
          Label {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 110
            text: modelData.name
            font.pixelSize: 13
          }
          Label {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: page.stats.topKind === "cpu" ? modelData.value.toFixed(1) + "%"
              : modelData.value >= 1 ? modelData.value.toFixed(2) + " GB" : Math.round(modelData.value * 1024) + " MB"
            font.pixelSize: 13
            tabular: true
            color: Theme.secondary
          }
        }
      }
    }
  }
}
