// My IP & Geo - Status mark of the Diagnostics tab: a check, "!" or a cross in a circle, a spinning arc while running
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    // The widget (main.qml): its state, functions and theme colours
    property var root

    id: diagIcon
    property string status: "pending"
    property real size: 18
    readonly property color tint: root.diagTint(status)
    width: size
    height: size
    Canvas {
        id: diagIconMark
        anchors.fill: parent
        visible: diagIcon.status !== "running"
        antialiasing: true
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var s = width
            var c = s / 2
            if (diagIcon.status === "pending") {
                ctx.lineWidth = 1.5
                ctx.strokeStyle = root.cssColor(diagIcon.tint, 1)
                ctx.beginPath()
                ctx.arc(c, c, c - 1.5, 0, 2 * Math.PI, false)
                ctx.stroke()
                return
            }
            ctx.fillStyle = root.cssColor(diagIcon.tint, 1)
            ctx.beginPath()
            ctx.arc(c, c, c - 0.5, 0, 2 * Math.PI, false)
            ctx.fill()
            ctx.strokeStyle = "#10151d"
            ctx.fillStyle = "#10151d"
            ctx.lineWidth = Math.max(1.8, s * 0.12)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            if (diagIcon.status === "ok") {
                ctx.moveTo(s * 0.29, s * 0.53)
                ctx.lineTo(s * 0.44, s * 0.68)
                ctx.lineTo(s * 0.72, s * 0.37)
                ctx.stroke()
            } else if (diagIcon.status === "fail") {
                ctx.moveTo(s * 0.35, s * 0.35)
                ctx.lineTo(s * 0.65, s * 0.65)
                ctx.moveTo(s * 0.65, s * 0.35)
                ctx.lineTo(s * 0.35, s * 0.65)
                ctx.stroke()
            } else if (diagIcon.status === "warn") {
                ctx.moveTo(c, s * 0.27)
                ctx.lineTo(c, s * 0.56)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(c, s * 0.74, ctx.lineWidth * 0.6, 0, 2 * Math.PI, false)
                ctx.fill()
            } else {
                ctx.moveTo(s * 0.32, c)
                ctx.lineTo(s * 0.68, c)
                ctx.stroke()
            }
        }
    }
    Canvas {
        id: diagIconSpinner
        anchors.fill: parent
        visible: diagIcon.status === "running"
        antialiasing: true
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            ctx.lineWidth = Math.max(2, width * 0.13)
            ctx.lineCap = "round"
            ctx.strokeStyle = root.cssColor(diagIcon.tint, 1)
            ctx.beginPath()
            ctx.arc(c, c, c - ctx.lineWidth / 2 - 0.5, 0, 1.4 * Math.PI, false)
            ctx.stroke()
        }
        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: diagIconSpinner.visible
        }
    }
    onStatusChanged: { diagIconMark.requestPaint(); diagIconSpinner.requestPaint() }
    onTintChanged: { diagIconMark.requestPaint(); diagIconSpinner.requestPaint() }
}
