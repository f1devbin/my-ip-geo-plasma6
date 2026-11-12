// My IP & Geo - Tools -> Hardware: what the computer is made of
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    anchors.fill: parent
    spacing: 6
    visible: root.toolsTab === 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { text: "Hardware"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Text {
            text: root.hwLoading ? "Reading…" : (root.hwUpdated !== "" ? "Read at " + root.hwUpdated : "")
            color: root.themeText
            opacity: 0.85
            font.pixelSize: 10
        }
        Controls.Button {
            text: root.hwCopied ? "Copied" : "Copy"
            icon.name: "edit-copy"
            enabled: root.hwSections.length > 0
            onClicked: root.copyHardware()
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.delay: 500
            Controls.ToolTip.text: "Copy the whole report as text"
        }
        Controls.Button {
            text: "Refresh"
            icon.name: "view-refresh"
            enabled: !root.hwLoading
            onClicked: root.refreshHardware()
        }
    }

    Text {
        visible: !root.hwLoading && root.hwSections.length === 0
        text: "No hardware information could be read."
        color: root.themeText
        font.pixelSize: 12
    }

    Flickable {
        id: hwFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: hwColumn.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: hwScroll
            policy: Controls.ScrollBar.AlwaysOn
            visible: hwFlick.contentHeight > hwFlick.height + 1
        }
        Column {
            id: hwColumn
            width: parent.width - (hwFlick.contentHeight > hwFlick.height + 1 ? hwScroll.width + 4 : 0)
            spacing: 8

            Repeater {
                model: root.hwSections
                delegate: Rectangle {
                    id: hwCard
                    readonly property var section: modelData
                    width: hwColumn.width
                    height: hwCardBody.implicitHeight + 20
                    radius: 10
                    color: root.alpha(root.themeText, 0.04)
                    border.width: 1
                    border.color: root.alpha(root.themeText, 0.12)

                    Column {
                        id: hwCardBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 5

                        Row {
                            spacing: 8
                            Kirigami.Icon { width: 22; height: 22; source: hwCard.section.icon }
                            Text {
                                height: 22
                                verticalAlignment: Text.AlignVCenter
                                text: hwCard.section.title
                                color: root.themeHighlight
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: root.alpha(root.themeText, 0.10) }

                        Repeater {
                            model: hwCard.section.rows
                            delegate: Item {
                                width: hwCardBody.width
                                height: Math.max(hwKey.implicitHeight, hwValue.implicitHeight)
                                Text {
                                    id: hwKey
                                    width: 104
                                    text: modelData.k
                                    color: root.themeText
                                    opacity: 0.8
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: hwValue
                                    anchors.left: hwKey.right
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    text: modelData.v
                                    color: root.themeText
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // Memory slots and disks: a tile each, two per row
                        Flow {
                            id: hwTiles
                            visible: hwCard.section.tiles.length > 0
                            width: parent.width
                            topPadding: 3
                            spacing: 6
                            Repeater {
                                model: hwCard.section.tiles
                                delegate: Rectangle {
                                    width: Math.floor((hwTiles.width - hwTiles.spacing) / 2)
                                    height: hwTileText.implicitHeight + 12
                                    radius: 8
                                    color: root.alpha(root.themeText, modelData.dim ? 0.02 : 0.06)
                                    border.width: 1
                                    border.color: modelData.dim ? root.alpha(root.themeText, 0.12) : root.alpha(root.themeHighlight, 0.55)
                                    Column {
                                        id: hwTileText
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 1
                                        Text { width: parent.width; text: modelData.title; color: root.themeText; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; text: modelData.line1; color: root.themeText; opacity: modelData.dim ? 0.8 : 1; font.pixelSize: 11; wrapMode: Text.Wrap }
                                        Text { width: parent.width; visible: text !== ""; text: modelData.line2; color: root.themeText; opacity: 0.85; font.pixelSize: 10; wrapMode: Text.Wrap }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
