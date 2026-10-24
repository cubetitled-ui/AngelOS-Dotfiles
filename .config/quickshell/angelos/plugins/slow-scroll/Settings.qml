import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

Column {
    id: root

    property var plugin
    width: parent ? parent.width : 400
    spacing: Skin.px(10)

    PxGroup {
        title: I18n.t("Медленное прокручивание", "Slow Scroll")
        icon: "mouse"
        width: parent.width

        Panel {
            width: parent.width
            plugin: root.plugin
        }
    }
}
