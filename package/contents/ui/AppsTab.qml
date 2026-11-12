// My IP & Geo - Tools -> Apps: traffic leaders and connections per application
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    anchors.fill: parent
    spacing: 7
    visible: root.toolsTab === 4

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Network Apps"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Text { text: root.appTrafficLoading ? "Reading…" : root.appTrafficStatus; color: root.appTrafficLoading ? root.themeHighlight : root.themeSecondary; font.pixelSize: 9 }
    }
    // Period of the ranking
    RowLayout {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: [{key: "hour", title: "Last hour"}, {key: "day", title: "24 hours"}, {key: "boot", title: "Since boot"}]
            delegate: Controls.Button {
                id: periodButton
                readonly property bool current: root.appPeriod === modelData.key
                Layout.fillWidth: true
                Layout.preferredWidth: 1    // equal widths, also when the current one is bold
                Layout.preferredHeight: 28
                text: modelData.title
                onClicked: root.setAppPeriod(modelData.key)
                background: Rectangle {
                    radius: 5
                    color: periodButton.current ? root.alpha(root.themeHighlight, .18) : root.alpha(root.themeBackground, .80)
                    border.width: 1
                    border.color: periodButton.current ? root.themeHighlight : root.alpha(root.themeText, .12)
                }
                contentItem: Text {
                    text: periodButton.text
                    color: root.themeText
                    font.pixelSize: 10
                    font.bold: periodButton.current
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
    Text {
        text: root.appPeriodSummary
        color: root.themeText
        font.pixelSize: 10
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    Flickable {
        id: appFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: appTrafficColumn.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: appScroll
            policy: Controls.ScrollBar.AlwaysOn
            visible: appFlick.contentHeight > appFlick.height + 1
        }
        Column {
            id: appTrafficColumn
            width: parent.width - (appFlick.contentHeight > appFlick.height + 1 ? appScroll.width + 4 : 0)
            spacing: 4
            Repeater {
                model: root.appTraffic
                delegate: Rectangle {
                    id: appRow
                    // Expanded state lives in root.appExpanded (key: application name), so it survives updates
                    readonly property string appKey: modelData ? String(modelData.key) : ""
                    readonly property bool expanded: root.appExpanded[appKey] === true
                    readonly property real periodTotal: modelData ? modelData.prx + modelData.ptx : 0
                    readonly property bool live: modelData ? (modelData.rx > 0 || modelData.tx > 0) : false
                    readonly property string lastActive: modelData ? root.appActivity(modelData, Date.now()) : ""
                    width: appTrafficColumn.width
                    height: appRowContent.implicitHeight + 12
                    radius: 6
                    color: root.alpha(root.themeText, .045)
                    border.width: 1
                    border.color: root.alpha(root.themeText, .07)
                    Column {
                        id: appRowContent
                        x: 8
                        y: 6
                        width: parent.width - 16
                        spacing: 4
                        Item {
                            width: parent.width
                            height: appHead.implicitHeight
                            Column {
                                id: appHead
                                width: parent.width
                                spacing: 4
                                RowLayout {
                                    width: parent.width
                                    spacing: 6
                                    // Place in the ranking only for applications with traffic in the period
                                    Text { text: appRow.periodTotal > 0 ? index + 1 : ""; color: root.themeSecondary; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignRight }
                                    Text { text: modelData.display; color: root.themeText; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: appRow.periodTotal > 0 ? root.formatBytes(appRow.periodTotal) : "—"; color: root.themeText; font.pixelSize: 11; font.bold: true }
                                    Text { text: appRow.expanded ? "⌄" : "›"; color: root.themeSecondary; font.pixelSize: 14; Layout.preferredWidth: 12; horizontalAlignment: Text.AlignHCenter }
                                }
                                // Share of the leader: received (blue) and sent (red)
                                Item {
                                    visible: appRow.periodTotal > 0
                                    x: 22
                                    width: parent.width - 22 - 18
                                    height: 5
                                    Rectangle { anchors.fill: parent; radius: 2.5; color: root.alpha(root.themeText, .08) }
                                    Rectangle {
                                        id: rxBar
                                        width: appRow.periodTotal > 0 ? parent.width * modelData.share * modelData.prx / appRow.periodTotal : 0
                                        height: parent.height
                                        radius: 2.5
                                        color: "#69a9ff"
                                    }
                                    Rectangle {
                                        x: rxBar.width
                                        width: appRow.periodTotal > 0 ? parent.width * modelData.share * modelData.ptx / appRow.periodTotal : 0
                                        height: parent.height
                                        radius: 2.5
                                        color: "#ff4040"
                                    }
                                }
                                // Received / sent in the period, then speed right now or the last activity
                                Row {
                                    visible: appRow.periodTotal > 0
                                    x: 22
                                    spacing: 4
                                    Image { source: Qt.resolvedUrl("../images/arrow-down.svg"); sourceSize.width: 8; sourceSize.height: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.formatBytes(modelData.prx); color: root.themeText; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Item { width: 3; height: 1 }
                                    Image { source: Qt.resolvedUrl("../images/arrow-up.svg"); sourceSize.width: 8; sourceSize.height: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.formatBytes(modelData.ptx); color: root.themeText; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        visible: text !== ""
                                        text: appRow.live ? "· now ↓ " + root.formatBytes(modelData.rx) + "/s  ↑ " + root.formatBytes(modelData.tx) + "/s"
                                            : (appRow.lastActive !== "" ? "· " + appRow.lastActive : "")
                                        color: appRow.live ? root.themePositive : root.themeSecondary
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                // Connected, but nothing counted in the period (yet)
                                Text {
                                    visible: appRow.periodTotal <= 0
                                    x: 22
                                    width: parent.width - 22
                                    text: appRow.live ? "now ↓ " + root.formatBytes(modelData.rx) + "/s  ↑ " + root.formatBytes(modelData.tx) + "/s · not counted yet"
                                        : root.appIdleText(modelData, root.appPeriod, Date.now())
                                    color: appRow.live ? root.themePositive : root.themeSecondary
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleAppExpanded(appRow.appKey)
                            }
                        }
                        Rectangle { visible: appRow.expanded; width: parent.width; height: 1; color: root.alpha(root.themeText, .08) }
                        Column {
                            visible: appRow.expanded
                            width: parent.width
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.pids.length
                                    ? (modelData.pids.length === 1 ? "PID " + modelData.pids[0] : modelData.pids.length + " processes · PID " + modelData.pids.join(", "))
                                      + " · " + modelData.tcp + " TCP · " + modelData.udp + " UDP"
                                    : "No connections at the moment"
                                color: root.themeSecondary
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                            }
                            Row {
                                visible: modelData.connections.length > 0
                                width: parent.width
                                height: 18
                                Text { text: "Protocol"; color: root.themeSecondary; font.pixelSize: 9; width: 52 }
                                Text { text: "Remote address"; color: root.themeSecondary; font.pixelSize: 9; width: parent.width - 52 - 72 - 86 }
                                Text { text: "Port"; color: root.themeSecondary; font.pixelSize: 9; width: 72; horizontalAlignment: Text.AlignRight }
                                Text { text: "Activity"; color: root.themeSecondary; font.pixelSize: 9; width: 86; horizontalAlignment: Text.AlignRight }
                            }
                            Repeater {
                                model: modelData.connections
                                delegate: Row {
                                    width: parent.width
                                    height: 22
                                    Text { text: modelData.protocol; color: root.themeText; font.pixelSize: 9; width: 52 }
                                    // "×N": N connections to this address and port
                                    Item {
                                        width: Math.max(70, parent.width - 52 - 72 - 86)
                                        height: connAddress.implicitHeight
                                        Text {
                                            id: connAddress
                                            text: modelData.address
                                            color: root.themeText
                                            font.pixelSize: 9
                                            elide: Text.ElideMiddle
                                            width: Math.min(implicitWidth, parent.width - (connCount.visible ? connCount.implicitWidth + 5 : 0))
                                        }
                                        Text {
                                            id: connCount
                                            // right after the text as drawn, also when a long address is shortened with "…"
                                            x: connAddress.contentWidth + 5
                                            visible: modelData.count > 1
                                            text: "×" + modelData.count
                                            color: root.themeLink
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                    Text { text: modelData.port; color: root.themeText; font.pixelSize: 9; width: 72; horizontalAlignment: Text.AlignRight }
                                    Text { text: modelData.state; color: root.themePositive; font.pixelSize: 9; width: 86; horizontalAlignment: Text.AlignRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        text: root.appRatesState === "missing" || root.appUsageState === "missing" ? "Traffic unavailable: KDE System Monitor helper (ksgrd_network_helper) not found."
            : root.appRatesState === "failed" || root.appUsageState === "failed" ? "Traffic unavailable: KDE System Monitor helper could not start packet capture."
            : !root.settings.trackApps ? "Background counting is off: the totals are not updated, the list shows live connections and \"now\" only."
            : "Counted while Plasma runs (from login), updated every 2 minutes" + (root.appUsageUpdated !== "" ? ", last at " + root.appUsageUpdated : "")
              + ". \"now\" is a 3-second sample. Source: KDE System Monitor helper."
        color: root.themeSecondary
        font.pixelSize: 9
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    // Background counting: what the traffic leaders above are built from
    Controls.CheckBox {
        id: trackAppsBox
        Layout.fillWidth: true
        checked: root.settings.trackApps
        onToggled: {
            root.settings.trackApps = checked
            if (checked) root.startAppUsage(20)
        }
        text: "Count traffic per application in the background"
        font.pixelSize: 12
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.delay: 500
        Controls.ToolTip.text: "Needed for the totals of the last hour, 24 hours and since boot. The KDE System Monitor helper then runs all the time (a few percent of one CPU core). When off, counting stops within two minutes."
    }
    Controls.Button {
        text: root.appTrafficLoading ? "Reading…" : "Refresh"
        enabled: !root.appTrafficLoading
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        onClicked: root.refreshAppTraffic()
    }
}
