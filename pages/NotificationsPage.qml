import QtQuick
import "../components"

// Notifications: what is on screen now and the recent history Omarchy keeps,
// newest first; Do Not Disturb and clear all.
Page {
  id: page

  property var island
  readonly property var feed: island.notifications
  implicitHeight: col.implicitHeight + 8

  function ago(ts) {
    var s = Math.max(0, Math.floor((island.nowMs - ts) / 1000))
    if (s < 60) return I18n.t("şimdi")
    if (s < 3600) return Math.floor(s / 60) + I18n.t(" dk")
    if (s < 86400) return Math.floor(s / 3600) + I18n.t(" sa")
    return Qt.locale(island.localeName).toString(new Date(ts), "d MMM")
  }

  Column {
    id: col
    width: parent.width
    spacing: 10

    Item {
      width: parent.width
      height: 34
      Label {
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        text: page.feed.dnd ? I18n.t("Rahatsız etmeyin açık") : I18n.t("Bildirimler")
        font.pixelSize: 15
        strong: true
        color: page.feed.dnd ? Theme.orange : Theme.fg
      }
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        IslandButton {
          size: 32
          icon: page.feed.dnd ? "bell-off" : "bell"
          iconSize: 16
          tint: page.feed.dnd ? Theme.orange : Theme.fg
          fillColor: page.feed.dnd ? Qt.rgba(1, 0.62, 0.04, 0.18) : Theme.fill
          accessibleName: I18n.t("Rahatsız etmeyin")
          onClicked: page.feed.toggleDnd()
        }
        IslandButton {
          size: 32
          icon: "trash"
          iconSize: 15
          enabled2: page.feed.items.length > 0
          accessibleName: I18n.t("Tümünü temizle")
          onClicked: page.feed.clearAll()
        }
      }
    }

    Label {
      visible: page.feed.items.length === 0
      width: parent.width
      height: 70
      horizontalAlignment: Text.AlignHCenter
      text: I18n.t("Bildirim yok")
      color: Theme.tertiary
    }

    ListView {
      id: list
      visible: count > 0
      width: parent.width
      height: Math.min(contentHeight, 340)
      clip: true
      spacing: 6
      boundsBehavior: Flickable.StopAtBounds
      model: page.feed.items
      delegate: Rectangle {
        id: row
        required property var modelData
        readonly property string iconPath: page.feed.iconFor(modelData)
        width: list.width
        height: 60
        radius: 16
        color: modelData.urgency === 2 ? Qt.rgba(1, 0.27, 0.23, 0.16) : Theme.fill

        Item {
          id: lead
          x: 12
          width: 32; height: 32
          anchors.verticalCenter: parent.verticalCenter
          Icon {
            anchors.centerIn: parent
            size: row.iconPath ? 32 : 18
            source: row.iconPath
            name: "bell"
            color: Theme.secondary
          }
        }
        Column {
          anchors.left: lead.right
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Item {
            width: parent.width
            height: 18
            Label {
              width: parent.width - when.width - 8
              text: modelData.summary || modelData.app
              font.pixelSize: 13
              strong: true
            }
            Label {
              id: when
              anchors.right: parent.right
              text: (modelData.live ? "● " : "") + page.ago(modelData.timestamp) + (modelData.app ? " · " + modelData.app : "")
              font.pixelSize: 11
              color: modelData.live ? Theme.blue : Theme.tertiary
            }
          }
          Label {
            width: parent.width
            visible: text !== ""
            text: modelData.body
            font.pixelSize: 12
            color: Theme.secondary
          }
        }
        Accessible.role: Accessible.ListItem
        Accessible.name: (modelData.app || "") + ": " + (modelData.summary || "") + " " + (modelData.body || "")
      }
    }
  }
}
