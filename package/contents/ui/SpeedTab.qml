// My IP & Geo - Tools -> Speed: the speed test with its gauge
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    anchors.fill: parent
    spacing: 7
    visible: root.toolsTab === 3

    RowLayout {
        Layout.fillWidth: true
        Text { text: "Speed Test"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Text {
            text: root.speedLoading || root.speedUpdated === "" ? (root.speedStatus !== "" ? root.speedStatus : "Cloudflare · IPv4") : root.speedStatus + " · " + root.speedUpdated
            color: root.speedPhase === "error" ? root.themeNegative : (root.speedLoading ? root.themeHighlight : root.themeSecondary)
            font.pixelSize: 9
        }
    }

    Item {
        id: speedGauge
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120
        readonly property bool transfer: root.speedPhase === "download" || root.speedPhase === "upload"
        readonly property color accent: root.speedPhase === "upload" ? "#ff4040" : (root.speedPhase === "ping" ? "#35d07f" : "#69a9ff")
        readonly property real radius: Math.max(40, Math.min((width - 24) / 2, (height - 14) / 1.72))
        // Centred in a tall panel instead of leaving all the free space under the tiles
        readonly property real centerY: Math.max(0, (height - radius * 1.72 - 14) / 2) + radius + 9
        property real shown: transfer ? root.speedLiveMbps : (root.speedPhase === "done" ? Math.max(0, root.speedDownMbps) : 0)
        property real spin: 0
        Behavior on shown { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        NumberAnimation on spin { from: 0; to: 1; duration: 1100; loops: Animation.Infinite; running: root.speedPhase === "ping" && speedGauge.visible }
        onShownChanged: gaugeCanvas.requestPaint()
        onSpinChanged: gaugeCanvas.requestPaint()
        onAccentChanged: gaugeCanvas.requestPaint()
        onWidthChanged: gaugeCanvas.requestPaint()
        onHeightChanged: gaugeCanvas.requestPaint()
        Connections { target: root; function onSpeedPhaseChanged() { gaugeCanvas.requestPaint() } }

        Canvas {
            id: gaugeCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var r = speedGauge.radius
                var cx = width / 2
                var cy = speedGauge.centerY
                var start = 0.75 * Math.PI
                var sweep = 1.5 * Math.PI
                ctx.lineCap = "round"
                ctx.lineWidth = 10
                ctx.strokeStyle = root.cssColor(root.themeText, 0.10)
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + sweep, false)
                ctx.stroke()
                ctx.strokeStyle = root.cssColor(speedGauge.accent, 1)
                if (root.speedPhase === "ping") {
                    var seg = 0.22 * sweep
                    var a = start + (sweep - seg) * speedGauge.spin
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, a, a + seg, false)
                    ctx.stroke()
                } else {
                    var f = root.gaugeFraction(speedGauge.shown)
                    if (f > 0.003) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, start, start + sweep * f, false)
                        ctx.stroke()
                    }
                }
                ctx.fillStyle = root.cssColor(root.themeText, 0.65)
                ctx.font = "10px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                var marks = [0, 10, 50, 100, 250, 500, 1000]
                for (var i = 0; i < marks.length; ++i) {
                    var ang = start + sweep * root.gaugeFraction(marks[i])
                    var lr = r - 21
                    ctx.fillText(marks[i] === 1000 ? "1G" : String(marks[i]), cx + lr * Math.cos(ang), cy + lr * Math.sin(ang))
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: speedGauge.centerY - height / 2 + 4
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.speedPhase === "ping" ? (root.speedPingMs >= 0 ? String(Math.round(root.speedPingMs)) : "…")
                    : (speedGauge.transfer || root.speedPhase === "done" ? root.formatSpeed(speedGauge.shown) : "—")
                color: root.themeText
                font.pixelSize: Math.round(Math.max(22, speedGauge.radius * 0.40))
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.speedPhase === "ping" ? "ms" : "Mbps"
                color: root.themeText
                font.pixelSize: 10
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.speedPhase === "ping" ? "Ping" : (root.speedPhase === "upload" ? "Upload"
                    : (root.speedPhase === "download" || root.speedPhase === "done" ? "Download" : (root.speedPhase === "error" ? "Failed" : "Ready")))
                color: root.speedPhase === "error" ? root.themeNegative : speedGauge.accent
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [
                {key: "ping", title: "Ping", tint: "#35d07f", icon: ""},
                {key: "download", title: "Download", tint: "#69a9ff", icon: "../images/arrow-down.svg"},
                {key: "upload", title: "Upload", tint: "#ff4040", icon: "../images/arrow-up.svg"}
            ]
            delegate: Rectangle {
                readonly property bool active: root.speedPhase === modelData.key
                readonly property color tint: modelData.tint
                readonly property real result: modelData.key === "ping" ? root.speedPingMs : (modelData.key === "download" ? root.speedDownMbps : root.speedUpMbps)
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: 10
                color: active ? root.alpha(tint, .10) : root.alpha(root.themeText, .045)
                border.width: active ? 1.5 : 1
                border.color: active ? tint : root.alpha(root.themeText, .08)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 6
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 1
                    Row {
                        spacing: 5
                        Image {
                            visible: modelData.icon !== ""
                            source: modelData.icon !== "" ? Qt.resolvedUrl(modelData.icon) : ""
                            sourceSize.width: 9
                            sourceSize.height: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: modelData.icon === ""
                            width: 8
                            height: 8
                            radius: 4
                            color: tint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text { text: modelData.title; color: root.themeText; font.pixelSize: 10 }
                    }
                    Row {
                        spacing: 3
                        Text {
                            id: tileValue
                            text: modelData.key === "ping"
                                ? (result >= 0 ? String(Math.round(result)) : (active ? "…" : "—"))
                                : (result >= 0 ? root.formatSpeed(result) : (active ? root.formatSpeed(root.speedLiveMbps) : "—"))
                            color: root.themeText
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            text: modelData.key === "ping" ? "ms" : "Mbps"
                            color: root.themeText
                            font.pixelSize: 10
                            anchors.baseline: tileValue.baseline
                        }
                    }
                    Text {
                        text: modelData.key === "ping" && root.speedJitterMs >= 0 ? "jitter " + root.speedJitterMs.toFixed(1) + " ms" : ""
                        color: root.themeText
                        font.pixelSize: 9
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.speedServer !== "" ? "Server: Cloudflare " + root.speedServer : "Server: Cloudflare"
            color: root.themeSecondary
            font.pixelSize: 9
            Layout.fillWidth: true
        }
        Text { text: "IPv4 · 4 streams"; color: root.themeSecondary; font.pixelSize: 9 }
    }

    Controls.Button {
        id: speedStartButton
        text: root.speedLoading ? "Testing…" : (root.speedPhase === "done" || root.speedPhase === "error" ? "Run again" : "Start test")
        enabled: !root.speedLoading
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        onClicked: root.runSpeedTest()
        background: Rectangle {
            radius: 6
            color: speedStartButton.down ? root.alpha(root.themeHighlight, .20) : (speedStartButton.hovered ? root.alpha(root.themeHighlight, .12) : root.alpha(root.themeBackground, .92))
            border.width: 1
            border.color: speedStartButton.enabled ? "#ff3030" : root.alpha(root.themeText, .15)
        }
        contentItem: Text {
            text: speedStartButton.text
            color: speedStartButton.enabled ? root.themeText : root.themeSecondary
            font.pixelSize: 11
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
