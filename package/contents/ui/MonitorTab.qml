// My IP & Geo - Tools -> Monitor: watched devices
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    anchors.fill: parent
    spacing: 6
    visible: root.toolsTab === 5
    Text {
        text: "Watched devices"
        color: root.themeText
        font.pixelSize: 12
        font.bold: true
        Layout.fillWidth: true
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 5
        Controls.TextField {
            id: monitorIpField
            Layout.fillWidth: true
            placeholderText: "IP address"
            selectByMouse: true
            onTextChanged: {
                root.monitorError = ""
                var normalized = text.replace(/,/g, ".")
                if (normalized !== text) text = normalized
            }
        }
        Controls.Button {
            text: "Add"
            enabled: monitorIpField.text.trim() !== ""
            onClicked: { if (root.addWatchedDevice(monitorIpField.text, "—")) monitorIpField.clear() }
        }
    }
    Text {
        visible: root.monitorError !== ""
        text: root.monitorError
        color: root.themeNegative
        font.pixelSize: 10
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    // Status line and "Check now": the 30-second check can be run at once
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: !root.watchedDevices.length ? "Add an IP or use Watch from Network Scanner."
                : (root.monitorLoading ? "Checking…" : "Status is checked every 30 seconds.")
            color: root.monitorLoading ? root.themeHighlight : root.themeSecondary
            font.pixelSize: 10
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
        Controls.Button {
            visible: root.watchedDevices.length > 0
            text: "Check now"
            icon.name: "view-refresh"
            icon.width: 16
            icon.height: 16
            enabled: !root.monitorLoading
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.delay: 500
            Controls.ToolTip.text: "Check all devices now"
            onClicked: root.monitorWatchedDevices()
        }
    }
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: monitorColumn.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: monitorColumn
            width: parent.width
            spacing: 4
            Repeater {
                model: root.watchedDevices
                delegate: Rectangle {
                    width: monitorColumn.width
                    height: 44
                    radius: 6
                    color: modelData.status === "UP" ? root.alpha(root.themePositive,.10) : (modelData.status === "DOWN" ? root.alpha(root.themeNegative,.10) : root.alpha(root.themeText,.045))
                    border.width: 1
                    border.color: modelData.status === "UP" ? root.alpha(root.themePositive,.35) : (modelData.status === "DOWN" ? root.alpha(root.themeNegative,.35) : root.alpha(root.themeText,.10))
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 7
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            TextEdit {
                                text: modelData.ip
                                color: root.themeText
                                font.pixelSize: 10
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (modelData.mac && modelData.mac !== "—" ? modelData.mac + " · " : "") + "checked " + modelData.lastCheck + (modelData.via === "arp" ? " · ignores ping, answers ARP" : "")
                                color: root.themeSecondary
                                font.pixelSize: 9
                                Layout.fillWidth: true
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 9
                            Layout.preferredHeight: 9
                            radius: 4.5
                            color: modelData.status === "UP" ? root.themePositive : (modelData.status === "DOWN" ? root.themeNegative : root.themeSecondary)
                        }
                        Controls.Button {
                            text: "×"
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            onClicked:root.removeWatchedDevice(index)
                        }
                    }
                }
            }
        }
    }
}
