// My IP & Geo - Tools -> Scanner: devices of the local network and the port scan of a device
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    anchors.fill: parent
    spacing: 6
    visible: root.toolsTab === 0

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Network Scanner"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Text { text: root.scanLoading ? root.scanProgressText(root.scanRunCidr) : root.scanStatus; color: root.scanLoading ? root.themeHighlight : root.themeSecondary; font.pixelSize: 9 }
    }
    Text {
        text: "Finds every device on the network, including ones that ignore ping (they still answer ARP). A /24 takes about 10 seconds, a /21 about 20. Press the magnifier next to a device to scan its open ports."
        color: root.themeSecondary
        font.pixelSize: 10
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 5
        Controls.TextField {
            id: scanField
            Layout.fillWidth: true
            text: root.scanCidr
            placeholderText: "Network, e.g. 192.168.1.0/24"
            font.pixelSize: 10
            selectByMouse: true
            onEditingFinished: {
                root.scanCidr = text.trim()
                root.scanCidrUserEdited = true
            }
            onAccepted: {
                root.scanCidr = text.trim()
                root.scanCidrUserEdited = true
                root.runNetworkScan()
            }
        }
        Controls.Button {
            text: root.scanLoading ? "Scanning…" : "Scan"
            enabled: !root.scanLoading && root.scanCidr !== "" && root.missingDependencies.indexOf("iputils-ping") === -1
            onClicked: root.runNetworkScan()
        }
    }
    Rectangle {
        id: scanBar
        visible: root.scanLoading
        Layout.fillWidth: true
        Layout.preferredHeight: 3
        radius: 1.5
        color: root.alpha(root.themeText, .08)
        clip: true
        Rectangle {
            id: scanBarFill
            width: scanBar.width * 0.3
            height: scanBar.height
            radius: 1.5
            color: root.themeHighlight
            NumberAnimation on x {
                from: -scanBarFill.width
                to: scanBar.width
                duration: 1400
                loops: Animation.Infinite
                running: scanBar.visible
            }
        }
    }
    RowLayout {
        visible: root.missingDependencies !== ""
        Layout.fillWidth: true
        spacing: 5
        Text {
            text: "Missing: " + root.missingDependencies
            color: root.themeNegative
            font.pixelSize: 10
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
        Controls.Button {
            text: "Check"
            enabled: !root.dependenciesLoading
            onClicked: root.checkDependencies()
        }
    }
    TextEdit {
        visible: root.installCommand !== ""
        Layout.fillWidth: true
        text: root.installCommand
        color: root.themeNegative
        font.pixelSize: 10
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        cursorVisible: false
        wrapMode: TextEdit.Wrap
        Layout.preferredHeight: Math.max(18, contentHeight)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        // as wide as the device rows, which leave room for the scroll bar
        Layout.rightMargin: scanFlick.barSpace
        radius: 6
        color: root.alpha(root.themeText, .035)
        border.width: 1
        border.color: root.alpha(root.themeText, .12)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 5
            spacing: 6
            Text { Layout.fillWidth: true; text: "Device"; color: root.themeText; font.pixelSize: 10; font.bold: true }
            Text { Layout.preferredWidth: 112; text: "MAC address"; color: root.themeText; font.pixelSize: 10; font.bold: true }
            Text { Layout.preferredWidth: 44; text: "Ports"; color: root.themeText; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
            Text { Layout.preferredWidth: 44; text: "Monitor"; color: root.themeText; font.pixelSize: 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
        }
    }

    Flickable {
        id: scanFlick
        // room for the scroll bar while the list is longer than the view
        readonly property real barSpace: contentHeight > height + 1 ? scanScroll.width + 4 : 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: scanHostColumn.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: scanScroll
            policy: Controls.ScrollBar.AlwaysOn
            visible: scanFlick.contentHeight > scanFlick.height + 1
        }

        Column {
            id: scanHostColumn
            width: parent.width - scanFlick.barSpace
            spacing: 3

            Repeater {
                model: root.scanHosts
                delegate: Rectangle {
                    id: hostRow
                    readonly property string ipKey: modelData.ip
                    readonly property string macAddr: modelData.mac
                    readonly property bool expanded: root.scanExpanded[ipKey] === true
                    readonly property var scan: root.portScans[ipKey] || null
                    readonly property string prange: scan ? scan.range : "1-65535"
                    readonly property string pstate: scan ? scan.state : "idle"
                    // "Router" / "This device" and the reverse DNS name, when known
                    readonly property string note: {
                        var parts = []
                        var label = root.scanLabel(modelData.ip)
                        if (label) parts.push(label)
                        var name = root.scanNames[modelData.ip]
                        if (name) parts.push(name)
                        return parts.join(" · ")
                    }
                    width: scanHostColumn.width
                    height: hostBody.implicitHeight
                    radius: 6
                    color: root.alpha(root.themeText, hostRow.expanded ? .07 : .045)
                    border.width: 1
                    border.color: root.alpha(root.themeText, hostRow.expanded ? .16 : .08)
                    clip: true

                    Column {
                        id: hostBody
                        width: parent.width

                        // Header row: click anywhere (except the buttons) to open the port scan
                        Item {
                            width: parent.width
                            height: 38
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePortExpand(hostRow.ipKey)
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 5
                                spacing: 6
                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: modelData.via === "ping" ? root.themePositive : "#e0a030"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    TextEdit {
                                        Layout.fillWidth: true
                                        text: modelData.ip
                                        color: root.themeText
                                        font.pixelSize: 10
                                        readOnly: true
                                        selectByMouse: true
                                        selectByKeyboard: true
                                        cursorVisible: false
                                    }
                                    Text {
                                        visible: hostRow.note !== ""
                                        Layout.fillWidth: true
                                        text: hostRow.note
                                        color: root.themeLink
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                                TextEdit {
                                    Layout.preferredWidth: 112
                                    text: modelData.mac
                                    color: root.themeText
                                    font.pixelSize: 10
                                    readOnly: true
                                    selectByMouse: true
                                    selectByKeyboard: true
                                    cursorVisible: false
                                }
                                // Port scan: opens / closes the panel under the row
                                Item {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 38
                                    Controls.Button {
                                        id: portsButton
                                        anchors.centerIn: parent
                                        width: 30
                                        height: 26
                                        icon.name: "edit-find"
                                        icon.width: 16
                                        icon.height: 16
                                        onClicked: root.togglePortExpand(hostRow.ipKey)
                                        Controls.ToolTip.visible: hovered
                                        Controls.ToolTip.delay: 500
                                        Controls.ToolTip.text: hostRow.expanded ? "Hide port scan" : "Scan ports"
                                    }
                                    // Accent frame while the panel of this device is open (Breeze shows no checked state here)
                                    Rectangle {
                                        visible: hostRow.expanded
                                        anchors.fill: portsButton
                                        anchors.margins: -2
                                        radius: 6
                                        color: "transparent"
                                        border.width: 2
                                        border.color: root.themeHighlight
                                    }
                                }
                                Item {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 38
                                    Controls.Button {
                                        id: watchButton
                                        anchors.centerIn: parent
                                        width: 30
                                        height: 26
                                        Controls.ToolTip.visible: hovered
                                        Controls.ToolTip.delay: 500
                                        Controls.ToolTip.text: watchButton.text === "+" ? "Watch in Monitor" : "Stop watching"
                                        text: {
                                            var watching = false
                                            for (var wi = 0; wi < root.watchedDevices.length; ++wi) {
                                                if (root.watchedDevices[wi].ip === modelData.ip) { watching = true; break }
                                            }
                                            return watching ? "\u2212" : "+"
                                        }
                                        onClicked: root.toggleWatchedDevice(modelData.ip, modelData.mac)
                                    }
                                }
                            }
                        }

                        // Port scan panel
                        Column {
                            visible: hostRow.expanded
                            x: 8
                            width: parent.width - 16
                            spacing: 6
                            bottomPadding: 8

                            Rectangle { width: parent.width; height: 1; color: root.alpha(root.themeText, .08) }

                            Text { text: "Scan TCP ports on " + hostRow.ipKey; color: root.themeText; font.pixelSize: 10; font.bold: true }

                            // Port range stretches with the widget; the magnifier Scan button stays at the right edge
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Controls.TextField {
                                    id: rangeField
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 80
                                    text: hostRow.prange
                                    placeholderText: "e.g. 8000-9000"
                                    font.pixelSize: 11
                                    selectByMouse: true
                                    onEditingFinished: root.setPortRange(hostRow.ipKey, text.trim())
                                    onAccepted: { root.setPortRange(hostRow.ipKey, text.trim()); root.runPortScan(hostRow.ipKey) }
                                }
                                Controls.Button {
                                    id: scanPortsButton
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: rangeField.implicitHeight
                                    display: Controls.AbstractButton.IconOnly
                                    text: "Start scan"
                                    icon.name: "edit-find"
                                    icon.width: 16
                                    icon.height: 16
                                    enabled: root.portScanIp === ""
                                    Controls.ToolTip.visible: hovered
                                    Controls.ToolTip.delay: 500
                                    Controls.ToolTip.text: "Start scan"
                                    onClicked: { root.setPortRange(hostRow.ipKey, rangeField.text.trim()); root.runPortScan(hostRow.ipKey) }
                                }
                            }
                            // Live state / result
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: hostRow.pstate === "error" ? hostRow.scan.error
                                    : hostRow.pstate === "running" ? "Checking " + root.rangeCount(hostRow.prange) + " ports\u2026"
                                    : hostRow.pstate === "done" ? ((hostRow.scan.ports.length > 0
                                        ? hostRow.scan.ports.length + " open \u00b7 " + hostRow.scan.scanned + " checked"
                                        : "No open ports \u00b7 " + hostRow.scan.scanned + " checked")
                                        + (hostRow.scan.secs > 0 ? " \u00b7 " + hostRow.scan.secs.toFixed(1) + " s" : ""))
                                    : "Plain TCP connect, no root needed"
                                color: hostRow.pstate === "error" ? root.themeNegative
                                    : hostRow.pstate === "running" ? root.themeHighlight
                                    : (hostRow.pstate === "done" && hostRow.scan.ports.length > 0) ? root.themePositive
                                    : root.themeSecondary
                                font.pixelSize: 10
                            }
                            // Indeterminate progress while a (possibly large) scan runs
                            Rectangle {
                                id: psBar
                                visible: hostRow.pstate === "running"
                                width: parent.width
                                height: 3
                                radius: 1.5
                                color: root.alpha(root.themeText, .08)
                                clip: true
                                Rectangle {
                                    id: psFill
                                    width: psBar.width * 0.3
                                    height: psBar.height
                                    radius: 1.5
                                    color: root.themeHighlight
                                    NumberAnimation on x {
                                        from: -psFill.width
                                        to: psBar.width
                                        duration: 1200
                                        loops: Animation.Infinite
                                        // only while seen: a running animation makes the window redraw
                                        running: hostRow.pstate === "running" && psBar.visible
                                    }
                                }
                            }
                            // Open ports
                            Flow {
                                width: parent.width
                                spacing: 5
                                Repeater {
                                    model: (hostRow.scan && hostRow.pstate === "done") ? hostRow.scan.ports : []
                                    delegate: Rectangle {
                                        radius: 4
                                        height: 20
                                        width: portChip.width + 12
                                        color: root.alpha(root.themePositive, .16)
                                        border.width: 1
                                        border.color: root.alpha(root.themePositive, .35)
                                        Row {
                                            id: portChip
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: modelData.port; color: root.themeText; font.pixelSize: 10; font.bold: true }
                                            Text { visible: modelData.service !== ""; text: modelData.service; color: root.themeSecondary; font.pixelSize: 10 }
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
    Row {
        visible: root.scanHosts.length > 0
        spacing: 12
        Row {
            spacing: 4
            Rectangle { width: 7; height: 7; radius: 3.5; color: root.themePositive; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "answers ping"; color: root.themeText; font.pixelSize: 9 }
        }
        Row {
            spacing: 4
            Rectangle { width: 7; height: 7; radius: 3.5; color: "#e0a030"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "ignores ping, found via ARP"; color: root.themeText; font.pixelSize: 9 }
        }
    }
}
