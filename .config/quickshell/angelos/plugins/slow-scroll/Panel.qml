pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Auto-scroll popup panel: controls, speed slider, direction and presets.
Column {
    id: root

    property var plugin
    width: parent ? parent.width : Skin.px(280)
    spacing: Skin.px(10)

    // Status card
    PxBox {
        width: parent.width
        height: Skin.px(46)
        color: AutoScroll.running ? Theme.mix(Theme.face, Theme.accent, 0.15) : Theme.face
        sunken: true

        Row {
            anchors.centerIn: parent
            spacing: Skin.px(8)

            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "mouse"
                pixel: Theme.u
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    text: AutoScroll.running ? I18n.t("Прокрутка активна", "Scrolling active") : I18n.t("Остановлено", "Stopped")
                    kind: "title"
                    font.bold: true
                    color: AutoScroll.running ? Theme.accent : Theme.text
                }
                PxText {
                    text: AutoScroll.running ? (AutoScroll.dir > 0 ? I18n.t("направление вниз ↓", "direction down ↓") : I18n.t("направление вверх ↑", "direction up ↑")) + " · " + AutoScroll.speed.toFixed(1) + "×" : I18n.t("нажми «Старт» для запуска", "press Start to begin")
                    dim: true
                    kind: "tiny"
                }
            }
        }
    }

    // Main Toggle Button
    PxButton {
        width: parent.width
        text: AutoScroll.running ? I18n.t("Остановить", "Stop") : I18n.t("Запустить", "Start")
        icon: AutoScroll.running ? "close" : "play"
        accent: !AutoScroll.running
        kind: "title"
        onClicked: AutoScroll.toggle()
    }

    // Direction row
    Column {
        width: parent.width
        spacing: Skin.px(4)

        PxText {
            text: I18n.t("Направление", "Direction")
            dim: true
            kind: "tiny"
        }

        PxSegmented {
            width: parent.width
            model: [
                {
                    "label": I18n.t("Вниз ↓", "Down ↓"),
                    "value": 1
                },
                {
                    "label": I18n.t("Вверх ↑", "Up ↑"),
                    "value": -1
                }
            ]
            currentValue: AutoScroll.dir
            onActivated: v => AutoScroll.setDir(v)
        }
    }

    // Speed slider
    Column {
        width: parent.width
        spacing: Skin.px(4)

        Item {
            width: parent.width
            implicitHeight: lblSpeed.implicitHeight
            PxText {
                id: lblSpeed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Скорость", "Speed")
                dim: true
                kind: "tiny"
            }
            PxText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: AutoScroll.speed.toFixed(1) + "×"
                kind: "tiny"
                font.bold: true
            }
        }

        PxSlider {
            width: parent.width
            from: 20
            to: 600
            stepSize: 10
            valueScale: 0.01
            decimals: 1
            suffix: "×"
            value: Math.round(AutoScroll.speed * 100)
            onReleased: v => AutoScroll.setSpeed(v / 100)
        }
    }

    // Presets
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Skin.px(6)

        PxButton {
            compact: true
            flat: true
            text: I18n.t("Чтение 0.8×", "Reading 0.8×")
            onClicked: AutoScroll.setSpeed(0.8)
        }
        PxButton {
            compact: true
            flat: true
            text: I18n.t("Норма 1.5×", "Normal 1.5×")
            onClicked: AutoScroll.setSpeed(1.5)
        }
        PxButton {
            compact: true
            flat: true
            text: I18n.t("Быстро 3.5×", "Fast 3.5×")
            onClicked: AutoScroll.setSpeed(3.5)
        }
    }

    // Smooth mode toggle
    Row {
        width: parent.width
        spacing: Skin.px(8)

        PxToggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: AutoScroll.smooth
            onToggled: c => AutoScroll.setSmooth(c)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                text: I18n.t("Плавная прокрутка", "Smooth scrolling")
            }
            PxText {
                text: I18n.t("эмуляция тачпада без рывков", "smooth touchpad axis stream")
                dim: true
                kind: "tiny"
            }
        }
    }

    // Hint
    PxText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        dim: true
        kind: "tiny"
        text: I18n.t("Прокручивается окно под курсором мыши.\nСКМ по значку панели — мгновенный вкл/выкл.", "Scrolls the window currently under the pointer.\nMiddle-click the bar icon to toggle instantly.")
    }
}
