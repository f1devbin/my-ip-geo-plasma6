// My IP & Geo - Tools -> Diagnostics: the chain connection -> router -> DNS -> internet -> websites
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    id: diagnosticsTab
    property var root

    anchors.fill: parent
    spacing: 7
    visible: root.toolsTab === 1

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Network Diagnostics"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Text {
            text: root.diagRunning ? "Checking…" : (root.diagUpdated !== "" ? "Checked " + root.diagUpdated : "")
            color: root.diagRunning ? root.themeHighlight : root.themeSecondary
            font.pixelSize: 10
        }
    }

    // Verdict: the first broken link of the chain, a warning or "Everything works"
    Rectangle {
        id: diagBanner
        readonly property var verdict: root.diagView.verdict
        readonly property color tint: root.diagTint(verdict.status)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(50, diagBannerText.implicitHeight + 18)
        radius: 10
        color: root.alpha(tint, 0.13)
        border.width: 1
        border.color: root.alpha(tint, 0.6)
        DiagIcon {
            root: diagnosticsTab.root
            id: diagBannerIcon
            status: diagBanner.verdict.status
            size: 26
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            id: diagBannerText
            anchors.left: diagBannerIcon.right
            anchors.leftMargin: 11
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { width: parent.width; text: diagBanner.verdict.title; color: root.themeText; font.pixelSize: 13; font.bold: true; wrapMode: Text.Wrap }
            Text { width: parent.width; visible: text !== ""; text: diagBanner.verdict.hint; color: root.alpha(root.themeText, 0.88); font.pixelSize: 10; wrapMode: Text.Wrap }
        }
    }

    Flickable {
        id: diagFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: diagColumn.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        // Details and route are below the steps: a visible bar shows there is more
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: diagScroll
            policy: Controls.ScrollBar.AlwaysOn
            visible: diagFlick.contentHeight > diagFlick.height + 1
        }
        Column {
            id: diagColumn
            // room for the style's own scroll bar (Breeze's is wider than 10 px), only while it is shown
            width: parent.width - (diagFlick.contentHeight > diagFlick.height + 1 ? diagScroll.width + 4 : 0)
            spacing: 8

            // The chain: connection -> router -> DNS -> internet -> websites
            Column {
                width: parent.width
                Repeater {
                    model: 5
                    delegate: Item {
                        id: diagStep
                        readonly property var step: root.diagView.steps[index]
                        width: diagColumn.width
                        height: diagStepText.implicitHeight + 10
                        Rectangle {
                            visible: index < 4
                            x: 10
                            y: 22
                            width: 2
                            height: parent.height - 18
                            radius: 1
                            color: root.alpha(root.themeText, 0.16)
                        }
                        DiagIcon { root: diagnosticsTab.root; x: 2; y: 2; size: 18; status: diagStep.step.status }
                        Column {
                            id: diagStepText
                            x: 30
                            y: 2
                            width: parent.width - 30
                            spacing: 1
                            Item {
                                width: parent.width
                                height: 18
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: diagStep.step.title; color: root.themeText; font.pixelSize: 11; font.bold: true }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: diagStep.step.value
                                    color: diagStep.step.status === "warn" || diagStep.step.status === "fail" ? root.diagTint(diagStep.step.status) : root.themeText
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            TextEdit {
                                width: parent.width
                                visible: text !== ""
                                text: diagStep.step.detail
                                color: root.alpha(root.themeText, 0.85)
                                font.pixelSize: 10
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                            }
                        }
                    }
                }
            }

            // Details: public IP, IPv6, VPN, path MTU
            GridLayout {
                width: parent.width
                columns: 2
                rowSpacing: 6
                columnSpacing: 6
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        id: diagTile
                        readonly property var tile: root.diagView.tiles[index]
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.preferredHeight: diagTileText.implicitHeight + 14
                        radius: 8
                        color: root.alpha(root.themeText, 0.045)
                        border.width: 1
                        border.color: root.alpha(root.themeText, 0.08)
                        Column {
                            id: diagTileText
                            x: 9
                            y: 7
                            width: parent.width - 18
                            spacing: 2
                            Row {
                                spacing: 5
                                Rectangle { width: 7; height: 7; radius: 3.5; anchors.verticalCenter: parent.verticalCenter; color: root.diagTint(diagTile.tile.status) }
                                Text { text: diagTile.tile.title; color: root.alpha(root.themeText, 0.85); font.pixelSize: 10 }
                            }
                            TextEdit {
                                width: parent.width
                                text: diagTile.tile.value
                                color: root.themeText
                                font.pixelSize: 11
                                font.bold: true
                                wrapMode: TextEdit.WrapAnywhere
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                            }
                            TextEdit {
                                width: parent.width
                                visible: text !== ""
                                text: diagTile.tile.detail
                                color: root.alpha(root.themeText, 0.85)
                                font.pixelSize: 10
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                            }
                        }
                    }
                }
            }

            // Routers on the way to 1.1.1.1
            Column {
                width: parent.width
                visible: root.diagView.route.length > 0
                spacing: 2
                Text { text: "Route to 1.1.1.1"; color: root.themeText; font.pixelSize: 11; font.bold: true; bottomPadding: 2 }
                Repeater {
                    model: root.diagView.route
                    delegate: Rectangle {
                        width: diagColumn.width
                        height: 22
                        radius: 5
                        color: index % 2 ? "transparent" : root.alpha(root.themeText, 0.035)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            spacing: 8
                            Text { text: modelData.ttl; color: root.themeText; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignRight }
                            TextEdit {
                                text: modelData.ip === "*" ? "no answer" : modelData.ip
                                color: modelData.ip === "*" ? root.alpha(root.themeText, 0.75) : root.themeText
                                font.pixelSize: 10
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                            }
                            Text { text: modelData.name; color: root.themeLink; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text {
                                text: modelData.reached === 2 ? "unreachable" : (modelData.rtt >= 0 ? root.fmtMs(modelData.rtt) : "—")
                                color: modelData.reached === 2 ? "#ff4040" : root.themeText
                                font.pixelSize: 10
                                font.bold: modelData.reached === 1
                            }
                        }
                    }
                }
            }
        }
    }

    Controls.Button {
        text: root.diagRunning ? "Checking…" : (root.diagFinished > 0 ? "Run again" : "Run diagnostics")
        enabled: !root.diagRunning
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        onClicked: root.runDiagnostics()
    }
}
