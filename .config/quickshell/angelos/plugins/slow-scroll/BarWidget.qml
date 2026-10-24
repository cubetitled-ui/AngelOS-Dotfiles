import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// Bar icon and popup for Slow Scroll / Auto Scroll.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    property int hpad: -1
    property bool barInk: false
    readonly property string icon: btn.icon
    readonly property string text: btn.text
    readonly property bool barOpen: popup.visible
    readonly property bool mac: Skin.mac

    implicitWidth: mac ? macRow.implicitWidth : btn.implicitWidth
    implicitHeight: mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !root.mac
        anchors.fill: parent
        compact: true
        flat: true
        hpad: root.hpad
        barInk: root.barInk
        icon: "mouse"
        text: AutoScroll.running ? (AutoScroll.dir > 0 ? "↓" : "↑") : ""
        checked: popup.visible || AutoScroll.running
        onClicked: popup.toggle()
    }

    // Middle click toggles scrolling directly
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: AutoScroll.toggle()
    }

    Row {
        id: macRow
        visible: root.mac
        anchors.centerIn: parent
        spacing: Skin.px(3)

        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "mouse"
            size: Skin.px(16)
            stroke: 2
            color: AutoScroll.running ? Theme.accent : Skin.ink(root.screenName)
        }
        MacText {
            visible: AutoScroll.running
            anchors.verticalCenter: parent.verticalCenter
            text: AutoScroll.dir > 0 ? "↓" : "↑"
            color: Theme.accent
        }
    }

    MouseArea {
        visible: root.mac
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                AutoScroll.toggle();
            else
                popup.toggle();
        }
    }

    BarPopup {
        id: popup
        panelId: "slow-scroll"
        anchorItem: root
        above: BarLayout.bottom && !root.mac
        title: Skin.title(Skin.mac ? I18n.t("Медленное прокручивание", "Slow Scroll") : "slow-scroll")
        icon: "mouse"
        contentWidth: Skin.px(290)
        contentHeight: Skin.px(330)

        PxScroll {
            anchors.fill: parent
            contentHeight: panel.implicitHeight

            Panel {
                id: panel
                width: parent.width
                plugin: root.plugin
            }
        }
    }
}
