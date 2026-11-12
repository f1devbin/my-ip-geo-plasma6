// My IP & Geo - Settings: which blocks the main view shows
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    id: settingsPanel
    visible: false
    anchors.fill: parent
    anchors.margins: 12
    radius: 14
    z: 100
    color: root.alpha(root.themeBackground, 1)
    border.width: 1
    border.color: "#ff3030"

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "Settings"
                color: root.themeText
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }
            Controls.Button {
                text: "×"
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                onClicked: settingsPanel.visible = false
            }
        }

        Text {
            text: "Main view blocks"
            color: root.themeText
            font.pixelSize: 13
            font.bold: true
            Layout.topMargin: 4
        }

        Repeater {
            model: [
                {key: "showSystem", text: "System load (CPU, memory, swap, disk)"},
                {key: "showTraffic", text: "Traffic (totals and current speed)"},
                {key: "showDrives", text: "External drives"}
            ]
            delegate: Controls.CheckBox {
                Layout.fillWidth: true
                checked: root.settings[modelData.key]
                onToggled: root.settings[modelData.key] = checked
                text: modelData.text
                font.pixelSize: 13
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: "The widget height follows the shown blocks and the number of connected drives."
            color: root.themeText
            opacity: 0.85
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

    }
}
