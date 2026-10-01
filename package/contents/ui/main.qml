import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Plasma 6: use Kirigami theme attached properties for palette colors.
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    width: 500
    height: 480
    Layout.minimumWidth: 400
    Layout.minimumHeight: 400

    property int tab: 0
    property int toolsTab: 0
    property var watchedDevices: []
    property bool monitorLoading: false
    property bool loading: false
    property bool localLoading: false
    property bool networkLoading: false
    property bool speedLoading: false
    property bool appTrafficLoading: false
    property var appTraffic: []
    property var appExpanded: ({})
    property string appTrafficStatus: "Ready"
    property string appRatesState: ""
    // Traffic per process name: since boot (apps), wall-clock hours (hours), 2-minute chunks of the
    // last hour (recent) and the last time each name had traffic (seen). Saved with the boot id.
    property var appStore: ({apps: {}, hours: {}, recent: [], seen: {}, start: 0})
    property string appPeriod: "day"
    property var appProcs: []
    property var appRatesNow: ({state: "", rates: {}})
    property string appPeriodSummary: ""
    property string appUsageBoot: ""
    property string appUsageState: ""
    property string appUsageUpdated: ""
    property real appUsageChunkStart: 0
    property int appUsageChunkSecs: 120
    property int appUsageSeq: 0
    property int speedSampleSeq: 0
    property bool dependenciesLoading: false
    property string missingDependencies: ""
    property string installCommand: ""
    property string scanCidr: ""
    property bool scanCidrUserEdited: false
    property bool scanLoading: false
    property string scanStatus: ""
    property var scanHosts: []
    property var scanNames: ({})
    property string scanRunCidr: ""
    property var scanExpanded: ({})              // Scanner: host rows opened for a port scan (ip -> true)
    property var portScans: ({})                 // ip -> {mode, range, state, scanned, ports:[{port,service}], error}
    property string portScanIp: ""               // host being scanned right now (one at a time)
    property int portScanSeq: 0
    property string portScanSource: ""
    property string systemUptime: "—"

    property color themeBackgroundRaw: Kirigami.Theme.backgroundColor
    property color themeTextRaw: Kirigami.Theme.textColor
    property color themeLinkRaw: Kirigami.Theme.linkColor
    property color themeSecondaryRaw: Kirigami.Theme.disabledTextColor
    property color themePositiveRaw: Kirigami.Theme.positiveTextColor
    property color themeNegativeRaw: Kirigami.Theme.negativeTextColor
    property color themeHighlight: Kirigami.Theme.highlightColor

    function luminance(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    function contrastText(bg, preferred) {
        var db = Math.abs(luminance(bg) - luminance(preferred))
        if (db >= 0.34) return preferred
        return luminance(bg) < 0.5 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0.08, 0.08, 0.08, 1)
    }

    // Status colours (green = up/ok, red = down/error) must keep their hue. Breeze Dark's red has too
    // little contrast for contrastText, which then turned it white: offline devices and errors lost
    // their red. Here the colour is lightened (dark background) or darkened (light background) in
    // steps until it is readable, so red stays red.
    function statusColor(bg, preferred) {
        var lb = luminance(bg)
        if (Math.abs(lb - luminance(preferred)) >= 0.34) return preferred
        var to = lb < 0.5 ? 1 : 0
        for (var i = 1; i < 10; ++i) {
            var t = i / 10
            var c = Qt.rgba(preferred.r + (to - preferred.r) * t, preferred.g + (to - preferred.g) * t,
                            preferred.b + (to - preferred.b) * t, 1)
            if (Math.abs(lb - luminance(c)) >= 0.34) return c
        }
        return contrastText(bg, preferred)
    }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    property color themeBackground: themeBackgroundRaw
    property color themeText: contrastText(themeBackgroundRaw, themeTextRaw)
    property color themeLink: contrastText(themeBackgroundRaw, themeLinkRaw)
    // Secondary text is mostly the text colour: the theme's "disabled" grey is hard to read on a dark background
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    property color themeSecondary: contrastText(themeBackgroundRaw, mix(themeTextRaw, themeSecondaryRaw, 0.25))
    property color themePositive: statusColor(themeBackgroundRaw, themePositiveRaw)
    property color themeNegative: statusColor(themeBackgroundRaw, themeNegativeRaw)
    property color themeSurface: root.themeBackground

    property string publicIp: "—"
    property string country: "—"
    property string countryCode: ""
    property string city: "—"
    property string region: "—"
    property string latitude: "—"
    property string longitude: "—"
    property string provider: "—"
    property string asn: "—"
    property string timezone: "—"
    property string updated: "—"
    property string errorText: ""
    property string ipSource: ""
    property var localItems: []
    property var gatewayMap: ({})
    property var dnsMap: ({})

    property string internetStatus: "—"
    property string internetQuality: "unknown"
    property bool vpnActive: false
    property int statusSeq: 0
    property int monitorSeq: 0
    // Diagnostics: parsed result per check, checks still running, run id and times
    readonly property var diagChecks: ["link", "gateway", "dns", "internet", "web", "ipv6", "mtu", "route"]
    property var diag: ({})
    property var diagPending: ({})
    property bool diagRunning: false
    property int diagSeq: 0
    property real diagStarted: 0
    property real diagFinished: 0
    property string diagUpdated: ""
    readonly property var diagView: diagEvaluate(diag, diagPending, diagRunning)
    property string speedStatus: ""
    property string speedUpdated: ""
    property string speedPhase: ""
    property real speedPingMs: -1
    property real speedJitterMs: -1
    property real speedDownMbps: -1
    property real speedUpMbps: -1
    property real speedLiveMbps: 0
    property string speedServer: ""
    property var speedSamplePrev: ({})
    property real speedSampleTime: 0
    property string trafficReceived: "—"
    property string trafficSent: "—"
    property string trafficUpdated: "—"

    Settings {
        id: appSettings
        property string watchedDevicesJson: "[]"
        property string appUsageJson: ""
        property string appPeriod: "day"
    }

    Plasmoid.icon: "/icon.png"

    // Status mark of the Diagnostics tab: filled circle with a check, "!" or a cross, a spinning arc while running
    component DiagIcon: Item {
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

    // publicip.sh output: "__SRC__ <provider>" and the provider's answer -> one set of fields
    function parsePublicIp(text) {
        var t = String(text || "")
        var m = t.match(/^__SRC__ (\S+)/m)
        var src = m ? m[1] : ""
        var body = m ? t.substring(m.index + m[0].length) : t
        var r = {ok: false, src: src, ip: "", country: "", countryCode: "", city: "", region: "", lat: NaN, lon: NaN, isp: "", asn: "", tz: "", error: ""}
        try {
            if (src === "ipwho.is") {
                var d = JSON.parse(body)
                r.ip = d.ip || ""
                r.country = d.country || ""
                r.countryCode = d.country_code || ""
                r.city = d.city || ""
                r.region = d.region || ""
                r.lat = d.latitude !== undefined ? Number(d.latitude) : NaN
                r.lon = d.longitude !== undefined ? Number(d.longitude) : NaN
                r.isp = d.connection && d.connection.isp ? d.connection.isp : ""
                r.asn = d.connection && d.connection.asn ? "AS" + d.connection.asn : ""
                r.tz = d.timezone && d.timezone.id ? d.timezone.id : ""
            } else if (src === "ipapi.co") {
                var a = JSON.parse(body)
                r.ip = a.ip || ""
                r.country = a.country_name || ""
                r.countryCode = a.country_code || ""
                r.city = a.city || ""
                r.region = a.region || ""
                r.lat = a.latitude !== undefined && a.latitude !== null ? Number(a.latitude) : NaN
                r.lon = a.longitude !== undefined && a.longitude !== null ? Number(a.longitude) : NaN
                r.isp = a.org || ""
                r.asn = a.asn || ""
                r.tz = a.timezone || ""
            } else if (src === "cloudflare") {
                var ip = body.match(/^ip=(\S+)/m)
                var loc = body.match(/^loc=([A-Z]{2})\s*$/m)
                r.ip = ip ? ip[1] : ""
                r.countryCode = loc ? loc[1] : ""
                r.country = r.countryCode
            }
        } catch (e) {
            r.ip = ""
        }
        r.ok = r.ip !== ""
        if (!r.ok) r.error = src === "none" || src === "" ? "No connection to the IP services (ipwho.is, ipapi.co, Cloudflare)" : "Unreadable answer from " + src
        return r
    }

    function formatUptime(seconds) {
        var s = Math.max(0, Math.floor(Number(seconds)))
        var days = Math.floor(s / 86400); s %= 86400
        var hours = Math.floor(s / 3600); s %= 3600
        var minutes = Math.floor(s / 60)
        if (days > 0) return days + "d " + hours + "h " + minutes + "m"
        if (hours > 0) return hours + "h " + minutes + "m"
        if (minutes > 0) return minutes + "m"
        return "<1m"
    }

    function flag(code) {
        if (!code || code.length !== 2) return "🌐"
        return String.fromCodePoint(code.charCodeAt(0) + 127397, code.charCodeAt(1) + 127397)
    }

    function gatewayFor(name) { return gatewayMap[name] || "—" }
    function dnsFor(name) { return dnsMap[name] || "—" }
    function sortLocalItems() {
        var sorted = root.localItems.slice()
        function score(item) {
            // Prefer interfaces with the most complete network information.
            // Count IPv4/IPv6 addresses individually so a fully populated
            // interface is not pushed below a sparse virtual interface.
            var value = 0
            value += item.ipv4.length * 2
            value += item.ipv6.length * 2
            value += item.ipv4Prefix.length
            value += item.ipv6Prefix.length
            if (root.gatewayFor(item.iface) !== "—") value += 3
            if (root.dnsFor(item.iface) !== "—") value += 3
            if (item.mac && item.mac !== "—") value += 2
            return value
        }
        sorted.sort(function(a,b) {
            var sa = score(a), sb = score(b)
            if (sb !== sa) return sb - sa
            // The interface with the default gateway is the active network.
            // Keep it first when two interfaces are equally complete.
            var ag = root.gatewayFor(a.iface) !== "—" ? 1 : 0
            var bg = root.gatewayFor(b.iface) !== "—" ? 1 : 0
            if (bg !== ag) return bg - ag
            return a.iface.localeCompare(b.iface)
        })
        root.localItems = sorted
    }

    function maskFor(prefix, family) {
        var p = parseInt(prefix)
        if (family === "IPv6" || isNaN(p)) return "/" + prefix
        if (p <= 0) return "0.0.0.0 (/0)"
        if (p >= 32) return "255.255.255.255 (/32)"
        var mask = (0xffffffff << (32 - p)) >>> 0
        return ((mask >>> 24) & 255) + "." + ((mask >>> 16) & 255) + "." + ((mask >>> 8) & 255) + "." + (mask & 255) + " (/" + p + ")"
    }

    // Dotted subnet mask without the "(/p)" suffix, e.g. 21 -> "255.255.248.0"
    function plainMask(prefix) {
        var p = parseInt(prefix)
        if (isNaN(p) || p < 0 || p > 32) return ""
        if (p === 0) return "0.0.0.0"
        var mask = (0xffffffff << (32 - p)) >>> 0
        return ((mask >>> 24) & 255) + "." + ((mask >>> 16) & 255) + "." + ((mask >>> 8) & 255) + "." + (mask & 255)
    }

    // One flat list of address rows for an interface: an "IPv4"/"IPv6" header, then one entry per address
    function ifaceAddrRows(item) {
        if (!item) return []
        var rows = []
        if (item.ipv4 && item.ipv4.length) {
            rows.push({header: item.ipv4.length > 1 ? "IPv4  \u00b7  " + item.ipv4.length + " addresses" : "IPv4"})
            for (var i = 0; i < item.ipv4.length; ++i)
                rows.push({addr: item.ipv4[i] + "/" + item.ipv4Prefix[i], mask: root.plainMask(item.ipv4Prefix[i]), fam: 4})
        }
        if (item.ipv6 && item.ipv6.length) {
            rows.push({header: item.ipv6.length > 1 ? "IPv6  \u00b7  " + item.ipv6.length + " addresses" : "IPv6"})
            for (var j = 0; j < item.ipv6.length; ++j)
                rows.push({addr: item.ipv6[j] + "/" + item.ipv6Prefix[j], mask: "", fam: 6})
        }
        return rows
    }

    function activeInterface() {
        return root.localItems.length > 0 ? root.localItems[0] : null
    }

    function ipv4Network(ip, prefix) {
        var p = parseInt(prefix)
        if (!ip || isNaN(p) || p < 0 || p > 32) return ""
        var parts = ip.split(".")
        if (parts.length !== 4) return ""
        var n = 0
        for (var i = 0; i < 4; ++i) {
            var oct = parseInt(parts[i])
            if (isNaN(oct) || oct < 0 || oct > 255) return ""
            n = (n * 256 + oct) >>> 0
        }
        var mask = p === 0 ? 0 : (0xffffffff << (32 - p)) >>> 0
        var net = (n & mask) >>> 0
        return ((net >>> 24) & 255) + "." + ((net >>> 16) & 255) + "." + ((net >>> 8) & 255) + "." + (net & 255) + "/" + p
    }

    // Absolute path of a script shipped in contents/code, quoted for sh
    function codePath(name) {
        var path = decodeURIComponent(String(Qt.resolvedUrl("../code/" + name)).replace(/^file:\/\//, ""))
        return "'" + path.replace(/'/g, "'\\''") + "'"
    }

    // Interface for the scanner: a real Ethernet/Wi-Fi link (it has a MAC), not a VPN tunnel
    function scanInterface() {
        for (var i = 0; i < root.localItems.length; ++i) {
            var it = root.localItems[i]
            var p = it.ipv4Prefix.length ? parseInt(it.ipv4Prefix[0]) : 32
            if (it.ipv4.length && p <= 30 && it.mac && it.mac !== "—" && it.mac !== "00:00:00:00:00:00") return it
        }
        return activeInterface()
    }

    function updateScanDefault() {
        var item = scanInterface()
        if (!item || !item.ipv4.length || !item.ipv4Prefix.length) return
        var prefix = parseInt(item.ipv4Prefix[0])
        // Networks bigger than /22 are scanned as the /24 around this device
        var cidr = ipv4Network(item.ipv4[0], prefix < 22 ? 24 : prefix)
        if (cidr && !root.scanCidrUserEdited) root.scanCidr = cidr
    }

    function checkDependencies() {
        if (dependenciesLoading) return
        dependenciesLoading = true
        dependencyApi.connectSource("sh -c 'command -v curl >/dev/null 2>&1 || echo curl; command -v ip >/dev/null 2>&1 || echo iproute2; command -v ping >/dev/null 2>&1 || echo iputils-ping'")
    }

    function ipToInt(ip) {
        var p = String(ip).split(".")
        return ((+p[0] << 24) >>> 0) + (+p[1] << 16) + (+p[2] << 8) + (+p[3])
    }

    function scanLabel(ip) {
        for (var i = 0; i < root.localItems.length; ++i)
            if (root.localItems[i].ipv4.indexOf(ip) !== -1) return "This device"
        for (var k in root.gatewayMap)
            if (root.gatewayMap.hasOwnProperty(k) && root.gatewayMap[k] === ip) return "Router"
        return ""
    }

    // netscan.sh output -> devices. Up = answered ping, or answered ARP (neighbour entry REACHABLE).
    // Cached entries (STALE) do not count: the scan re-validates them, gone devices end up FAILED.
    function parseScan(text, cidr) {
        var out = String(text || "")
        if (out.indexOf("__BADCIDR__") !== -1) return {error: "Invalid network address", hosts: []}
        var big = out.match(/__TOOBIG__ (\d+)/)
        if (big) return {error: "Network too large (" + big[1] + " addresses, max 1024)", hosts: []}
        if (out.indexOf("__NEIGH__") === -1) return {error: "Scan failed", hosts: []}
        var m = String(cidr).match(/^(\d+\.\d+\.\d+\.\d+)(?:\/(\d+))?$/)
        if (!m) return {error: "Invalid network address", hosts: []}
        var bits = m[2] === undefined ? 32 : parseInt(m[2])
        var mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0
        var net = (root.ipToInt(m[1]) & mask) >>> 0
        function inRange(ip) { return ((root.ipToInt(ip) & mask) >>> 0) === net }
        var own = {}
        for (var li = 0; li < root.localItems.length; ++li)
            for (var lj = 0; lj < root.localItems[li].ipv4.length; ++lj)
                own[root.localItems[li].ipv4[lj]] = String(root.localItems[li].mac || "—").toUpperCase()
        var found = {}
        var lines = out.split("\n")
        var inNeigh = false
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (line === "__NEIGH__") { inNeigh = true; continue }
            if (!inNeigh) {
                var up = line.match(/^UP (\d+\.\d+\.\d+\.\d+)$/)
                if (up && inRange(up[1])) found[up[1]] = {ip: up[1], mac: own[up[1]] || "—", via: "ping"}
                continue
            }
            var n = line.match(/^(\d+\.\d+\.\d+\.\d+)\s+dev\s+\S+(?:\s+lladdr\s+([0-9a-fA-F:]{17}))?.*\s([A-Z]+)$/)
            if (!n || !inRange(n[1])) continue
            var mac = n[2] ? n[2].toUpperCase() : ""
            if (found[n[1]]) {
                if (mac) found[n[1]].mac = mac
            } else if (mac && (n[3] === "REACHABLE" || n[3] === "PERMANENT" || n[3] === "NOARP")) {
                found[n[1]] = {ip: n[1], mac: mac, via: "arp"}
            }
        }
        var hosts = []
        for (var k in found) if (found.hasOwnProperty(k)) hosts.push(found[k])
        hosts.sort(function(a, b) { return root.ipToInt(a.ip) - root.ipToInt(b.ip) })
        return {error: "", hosts: hosts}
    }

    function runNetworkScan() {
        if (scanLoading) return
        var cidr = String(scanCidr || "").trim()
        var m = cidr.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:\/(\d{1,2}))?$/)
        if (!m || +m[1] > 255 || +m[2] > 255 || +m[3] > 255 || +m[4] > 255 || (m[5] !== undefined && +m[5] > 32)) {
            scanStatus = "Enter a network like 192.168.1.0/24"
            return
        }
        if (m[5] !== undefined && +m[5] < 22) {
            scanStatus = "Too large: use /22 or smaller"
            return
        }
        scanLoading = true
        scanRunCidr = cidr
        scanApi.connectSource("sh " + codePath("netscan.sh") + " scan " + cidr)
    }

    // ----- Scanner: per-host TCP port check (portscan.sh) -----
    function portEntry(ip) {
        var e = root.portScans[ip]
        return e ? e : {range: "1-65535", state: "idle", scanned: 0, ports: [], error: "", secs: 0}
    }
    function setPortScan(ip, patch) {
        var e = root.portEntry(ip)
        var merged = {range: e.range, state: e.state, scanned: e.scanned, ports: e.ports, error: e.error, secs: e.secs || 0}
        for (var k in patch) if (patch.hasOwnProperty(k)) merged[k] = patch[k]
        var next = {}
        for (var i in root.portScans) if (root.portScans.hasOwnProperty(i)) next[i] = root.portScans[i]
        next[ip] = merged
        root.portScans = next
    }
    function togglePortExpand(ip) {
        var next = {}
        for (var k in root.scanExpanded) if (root.scanExpanded.hasOwnProperty(k)) next[k] = root.scanExpanded[k]
        if (next[ip]) delete next[ip]; else next[ip] = true
        root.scanExpanded = next
    }
    function setPortRange(ip, range) { root.setPortScan(ip, {range: range}) }

    // "1-1024" clamped to 1..65535, low value first; "" when it is not a valid range
    function sanitizeRange(str) {
        var m = String(str || "").match(/^\s*(\d{1,5})\s*-\s*(\d{1,5})\s*$/)
        if (!m) return ""
        var a = Math.min(65535, Math.max(1, +m[1])), b = Math.min(65535, Math.max(1, +m[2]))
        if (a > b) { var t = a; a = b; b = t }
        return a + "-" + b
    }
    function rangeCount(str) {
        var r = root.sanitizeRange(str)
        if (r === "") return 0
        var ab = r.split("-")
        return +ab[1] - +ab[0] + 1
    }
    // The spec string passed to portscan.sh
    function portSpec(ip) {
        return root.sanitizeRange(root.portEntry(ip).range)
    }
    function runPortScan(ip) {
        if (root.portScanIp !== "") return
        var spec = root.portSpec(ip)
        if (spec === "") { root.setPortScan(ip, {state: "error", error: "Enter a range like 1-1024"}); return }
        var safeIp = String(ip).replace(/[^0-9a-fA-F:.]/g, "")
        if (!safeIp) return
        root.portScanIp = ip
        root.portScanSeq += 1
        root.setPortScan(ip, {state: "running", ports: [], scanned: 0, error: "", secs: 0})
        root.portScanSource = "bash " + root.codePath("portscan.sh") + " " + safeIp + " " + spec + " " + root.portScanSeq
        portScanApi.connectSource(root.portScanSource)
        portScanWatchdog.restart()
    }
    function parsePortScan(text) {
        var out = {scanned: 0, ports: [], done: false, error: "", secs: 0}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var f = lines[i].split(/\s+/)
            if (f[0] === "SCAN") out.scanned = +f[2] || 0
            else if (f[0] === "OPEN" && f[1]) out.ports.push({port: +f[1], service: f[2] || ""})
            else if (f[0] === "DONE") out.done = true
            else if (f[0] === "TIME") out.secs = parseFloat(f[1]) || 0
            else if (f[0] === "ERROR") out.error = lines[i].substring(6).trim() || "scan failed"
        }
        return out
    }

    function saveWatchedDevices() {
        appSettings.watchedDevicesJson = JSON.stringify(root.watchedDevices)
    }

    function loadWatchedDevices() {
        try {
            var parsed = JSON.parse(appSettings.watchedDevicesJson || "[]")
            root.watchedDevices = Array.isArray(parsed) ? parsed : []
        } catch (e) {
            root.watchedDevices = []
        }
    }

    function addWatchedDevice(ip, mac) {
        var safeIp = String(ip || "").trim().replace(/[^0-9a-fA-F:./]/g, "")
        if (!safeIp) return
        var list = root.watchedDevices.slice(0)
        for (var i = 0; i < list.length; ++i) if (list[i].ip === safeIp) return
        list.push({ ip: safeIp, mac: mac || "—", status: "Unknown", lastCheck: "—" })
        root.watchedDevices = list
        saveWatchedDevices()
        root.toolsTab = 5
        monitorWatchedDevices()
    }

    function removeWatchedDevice(index) {
        var list = root.watchedDevices.slice(0)
        if (index < 0 || index >= list.length) return
        list.splice(index, 1)
        root.watchedDevices = list
        saveWatchedDevices()
    }

    function toggleWatchedDevice(ip, mac) {
        var safeIp = String(ip || "").trim().replace(/,/g, ".").replace(/[^0-9a-fA-F:./]/g, "")
        if (!safeIp) return
        var list = root.watchedDevices.slice(0)
        for (var i = 0; i < list.length; ++i) {
            if (list[i].ip === safeIp) {
                list.splice(i, 1)
                root.watchedDevices = list
                saveWatchedDevices()
                return
            }
        }
        list.push({ ip: safeIp, mac: mac || "—", status: "Unknown", lastCheck: "—" })
        root.watchedDevices = list
        saveWatchedDevices()
        root.toolsTab = 5
        monitorWatchedDevices()
    }

    function monitorWatchedDevices() {
        if (monitorLoading || root.watchedDevices.length === 0) return
        if (root.missingDependencies.indexOf("ping") !== -1) return
        monitorLoading = true
        var ips = []
        for (var i = 0; i < root.watchedDevices.length; ++i) {
            var safeIp = String(root.watchedDevices[i].ip || "").replace(/[^0-9a-fA-F:./]/g, "")
            if (safeIp) ips.push(safeIp)
        }
        if (!ips.length) { monitorLoading = false; return }
        root.monitorSeq += 1
        monitorApi.connectSource("MYIPGEO_RUN=" + root.monitorSeq + " sh " + codePath("monitor.sh") + " " + ips.join(" "))
    }

    function refreshAll() {
        uptimeApi.disconnectSource("cut -d' ' -f1 /proc/uptime")
        uptimeApi.connectSource("cut -d' ' -f1 /proc/uptime")
        if (!loading) {
            loading = true
            publicApi.connectSource("sh " + codePath("publicip.sh") + " " + Date.now())
        }
        if (!localLoading) {
            localLoading = true
            localApi.connectSource("ip -j addr show")
            routeApi.connectSource("ip -j route show default")
            dnsApi.connectSource("bash " + codePath("netdiag.sh") + " dnsmap " + Date.now())
        }
        refreshNetwork()
    }

    // Header indicators (internet dot, VPN shield): one light check every 30 s
    function refreshNetwork() {
        if (networkLoading) return
        networkLoading = true
        root.statusSeq += 1
        statusApi.connectSource("bash " + codePath("netdiag.sh") + " status " + root.statusSeq)
    }

    // ---------- Diagnostics ----------
    // Every check is a separate process, so results show up one by one. A run id keeps the
    // command strings unique and drops late answers of an older run.
    function runDiagnostics() {
        if (root.diagRunning) return
        root.diagSeq += 1
        root.diagRunning = true
        root.diagStarted = Date.now()
        var pending = {}
        for (var i = 0; i < root.diagChecks.length; ++i) pending[root.diagChecks[i]] = true
        root.diagPending = pending
        root.diag = ({})
        for (var j = 0; j < root.diagChecks.length; ++j)
            diagApi.connectSource("bash " + codePath("netdiag.sh") + " " + root.diagChecks[j] + " " + root.diagSeq)
        diagWatchdog.restart()
        root.refreshNetwork()
    }

    // Opening the tab shows fresh results: a run starts when there is none or it is older than 5 minutes
    function autoRunDiagnostics() {
        if (!featurePanel.visible || root.toolsTab !== 1 || root.diagRunning) return
        if (root.diagFinished === 0 || Date.now() - root.diagFinished > 300000) root.runDiagnostics()
    }

    function diagResult(check, text) {
        var next = {}
        for (var k in root.diag) if (root.diag.hasOwnProperty(k)) next[k] = root.diag[k]
        next[check] = root.parseDiag(check, text)
        root.diag = next
        var pending = {}
        var left = 0
        for (var p in root.diagPending)
            if (root.diagPending.hasOwnProperty(p) && p !== check && root.diagPending[p] === true) { pending[p] = true; left++ }
        root.diagPending = pending
        if (left === 0) root.finishDiagnostics()
    }

    function finishDiagnostics() {
        diagWatchdog.stop()
        root.diagPending = ({})
        root.diagRunning = false
        root.diagFinished = Date.now()
        root.diagUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
    }

    function parseDiag(check, text) {
        var t = String(text || "")
        if (check === "link") return root.parseDiagLink(t)
        if (check === "gateway") return root.parseDiagGateway(t)
        if (check === "dns") return root.parseDiagDns(t)
        if (check === "internet") return root.parseDiagInternet(t)
        if (check === "web") return root.parseDiagWeb(t)
        if (check === "ipv6") return root.parseDiagIpv6(t)
        if (check === "mtu") return root.parseDiagMtu(t)
        if (check === "route") return root.parseDiagRoute(t)
        return null
    }

    // ping output -> packets, loss, round trip (ms) and jitter (mean difference of consecutive replies)
    function parsePing(text) {
        var out = String(text || "")
        var r = {sent: 0, recv: 0, loss: 100, errors: 0, min: -1, avg: -1, max: -1, jitter: -1, times: [], error: "", from: ""}
        var sum = out.match(/(\d+) packets transmitted, (\d+) received((?:, \+\d+ \w+)*), ([\d.]+)% packet loss/)
        if (sum) {
            r.sent = +sum[1]
            r.recv = +sum[2]
            r.loss = parseFloat(sum[4])
            var e = sum[3].match(/\+(\d+) errors/)
            if (e) r.errors = +e[1]
        }
        var rtt = out.match(/= ([\d.]+)\/([\d.]+)\/([\d.]+)\/[\d.]+ ms/)
        if (rtt) { r.min = parseFloat(rtt[1]); r.avg = parseFloat(rtt[2]); r.max = parseFloat(rtt[3]) }
        var re = /bytes from [^:]+: .*?time=([\d.]+) ms/g
        var m
        while ((m = re.exec(out)) !== null) r.times.push(parseFloat(m[1]))
        if (r.times.length > 1) {
            var j = 0
            for (var i = 1; i < r.times.length; ++i) j += Math.abs(r.times[i] - r.times[i - 1])
            r.jitter = j / (r.times.length - 1)
        } else if (r.times.length === 1) r.jitter = 0
        var err = out.match(/^ping: (.+)$/m)
        if (err) r.error = err[1].replace(/^connect: /, "")
        var from = out.match(/^From (\S+) icmp_seq=\d+ (.+)$/m)
        if (from) r.from = from[1] + ": " + from[2]
        return r
    }

    // "default via 10.0.0.1 dev wlp2s0 proto dhcp src 10.0.0.5 metric 600" -> {dev, via, src, metric}
    function parseRouteLine(line) {
        var f = String(line || "").trim().split(/\s+/)
        var r = {dev: "", via: "", src: "", metric: 0}
        for (var i = 0; i < f.length - 1; ++i) {
            if (f[i] === "dev") r.dev = f[i + 1]
            else if (f[i] === "via") r.via = f[i + 1]
            else if (f[i] === "src") r.src = f[i + 1]
            else if (f[i] === "metric") r.metric = +f[i + 1] || 0
        }
        return r
    }

    // nmcli -t output: fields split by ":", a ":" inside a value is written as "\:"
    function splitTerse(line) {
        var parts = []
        var cur = ""
        var s = String(line || "")
        for (var i = 0; i < s.length; ++i) {
            var c = s.charAt(i)
            if (c === "\\" && i + 1 < s.length) { cur += s.charAt(++i); continue }
            if (c === ":") { parts.push(cur); cur = ""; continue }
            cur += c
        }
        parts.push(cur)
        return parts
    }

    // NetworkManager's scale: -40 dBm and better = 100 %, -100 dBm = 0 %
    function wifiQuality(dbm) {
        var v = Math.min(-40, Math.max(-100, dbm))
        return Math.round(100 - (Math.abs(v + 40) * 100) / 60)
    }

    function parseDiagLink(text) {
        var r = {routes4: [], routes6: [], egress: null, ifaces: {}, order: [], vpns: [], nm: "", nmNames: {}, apps: []}
        function iface(dev) {
            if (!r.ifaces[dev]) {
                r.ifaces[dev] = {dev: dev, kind: "other", devtype: "", mtu: 0, speed: -1, duplex: "", mac: "", addrs: [], addrs6: [], wifi: null}
                r.order.push(dev)
            }
            return r.ifaces[dev]
        }
        function wifi(dev) {
            var it = iface(dev)
            if (!it.wifi) it.wifi = {ssid: "", freq: 0, dbm: null, signal: -1, rate: 0, chan: ""}
            return it.wifi
        }
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i]
            var m
            if ((m = line.match(/^ROUTE4 (.+)$/))) r.routes4.push(root.parseRouteLine(m[1]))
            else if ((m = line.match(/^ROUTE6 (.+)$/))) r.routes6.push(root.parseRouteLine(m[1]))
            else if ((m = line.match(/^EGRESS (.+)$/))) r.egress = root.parseRouteLine(m[1])
            else if ((m = line.match(/^IFACE (\S+) (.*)$/))) {
                var it = iface(m[1])
                var kv = m[2].split(/\s+/)
                for (var k = 0; k < kv.length; ++k) {
                    var eq = kv[k].indexOf("=")
                    if (eq < 0) continue
                    var key = kv[k].substring(0, eq), val = kv[k].substring(eq + 1)
                    if (key === "kind") it.kind = val
                    else if (key === "devtype") it.devtype = val === "-" ? "" : val
                    else if (key === "mtu") it.mtu = +val || 0
                    else if (key === "speed") it.speed = val !== "" && !isNaN(+val) ? +val : -1
                    else if (key === "duplex") it.duplex = val
                    else if (key === "mac") it.mac = val
                }
            } else if ((m = line.match(/^ADDR (\S+) (inet6?) (\S+)/))) {
                if (m[2] === "inet") iface(m[1]).addrs.push(m[3])
                else if (!/^fe80/i.test(m[3])) iface(m[1]).addrs6.push(m[3])
            } else if ((m = line.match(/^IW (\S+)\s+(.*)$/))) {
                var w = wifi(m[1])
                var v = m[2].trim()
                var x
                if ((x = v.match(/^SSID: (.*)$/))) w.ssid = x[1]
                else if ((x = v.match(/^freq: ([\d.]+)/))) w.freq = Math.round(parseFloat(x[1]))
                else if ((x = v.match(/^signal: (-?\d+)/))) w.dbm = +x[1]
                else if ((x = v.match(/^tx bitrate: ([\d.]+)/))) w.rate = parseFloat(x[1])
            } else if ((m = line.match(/^NMWIFI (\S+) (.*)$/))) {
                // IN-USE:SSID:CHAN:FREQ:RATE:SIGNAL
                var f = root.splitTerse(m[2])
                var nw = wifi(m[1])
                if (!nw.ssid && f[1]) nw.ssid = f[1]
                if (f[2]) nw.chan = f[2]
                if (!nw.freq && f[3]) nw.freq = parseInt(f[3]) || 0
                if (!nw.rate && f[4]) nw.rate = parseFloat(f[4]) || 0
                if (f[5] !== undefined && f[5] !== "") nw.signal = parseInt(f[5])
            } else if ((m = line.match(/^PROCWL (\S+): \S+\s+[\d.]+\s+(-?\d+)/))) {
                var pw = wifi(m[1])
                if (pw.dbm === null) pw.dbm = +m[2]
            } else if ((m = line.match(/^VPN (\S+) (\S+)(?: (\S+))?/))) r.vpns.push({dev: m[1], kind: m[2], type: m[3] || ""})
            else if ((m = line.match(/^NMCONN (\S+)/))) r.nm = m[1]
            else if ((m = line.match(/^VPNAPP (\S+)/))) r.apps.push(m[1])
            else if ((m = line.match(/^NMACTIVE (.*)$/))) {
                // DEVICE:NAME of active NetworkManager connections
                var nf = root.splitTerse(m[1])
                if (nf[0] && nf[1]) r.nmNames[nf[0]] = nf[1]
            }
        }
        return r
    }

    function parseDiagGateway(text) {
        var t = String(text || "")
        if (/^NOGW\s*$/m.test(t)) return {none: true}
        var gw = t.match(/^GW (\S+) ?(\S*)/m)
        var a = t.indexOf("__PING__"), b = t.indexOf("__NEIGH__")
        var neigh = b >= 0 ? t.substring(b).match(/\n(\S+) dev \S+(?: lladdr ([0-9a-fA-F:]+))?.*?\s([A-Z]+)\s*$/m) : null
        return {
            none: false,
            gw: gw ? gw[1] : "",
            dev: gw ? gw[2] : "",
            ping: root.parsePing(a >= 0 ? t.substring(a, b >= 0 ? b : t.length) : ""),
            neigh: neigh ? neigh[3] : "",
            mac: neigh && neigh[2] ? neigh[2].toUpperCase() : ""
        }
    }

    function parseDiagDns(text) {
        var r = {links: {}, global: [], stub: false, lookup: null, nx: null, doh: ""}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var m
            if ((m = lines[i].match(/^SERVERS Link \d+ \(([^)]+)\):\s*(.*)$/))) r.links[m[1]] = m[2].trim() ? m[2].trim().split(/\s+/) : []
            else if ((m = lines[i].match(/^SERVERS Global:\s*(.*)$/))) r.global = m[1].trim() ? m[1].trim().split(/\s+/) : []
            else if (/^STUB/.test(lines[i])) r.stub = true
            else if ((m = lines[i].match(/^(LOOKUP|NXLOOKUP) rc=(\d+) ms=(\d+) addr=(\S*)/))) {
                var res = {rc: +m[2], ms: +m[3], addr: m[4]}
                if (m[1] === "LOOKUP") r.lookup = res
                else r.nx = res
            } else if ((m = lines[i].match(/^DOH (\S+)/))) r.doh = m[1]
        }
        return r
    }

    function parseDiagInternet(text) {
        var t = String(text || "")
        var r = {targets: [], tcp: null}
        var parts = t.split(/^__PING__ /m)
        for (var i = 1; i < parts.length; ++i) {
            var nl = parts[i].indexOf("\n")
            var ip = (nl >= 0 ? parts[i].substring(0, nl) : parts[i]).trim()
            r.targets.push({ip: ip, ping: root.parsePing(nl >= 0 ? parts[i].substring(nl + 1) : "")})
        }
        var tcp = t.match(/^TCP ([\d.]+) (\d+)/m)
        if (tcp) r.tcp = {connect: parseFloat(tcp[1]), code: +tcp[2]}
        return r
    }

    function parseDiagWeb(text) {
        var t = String(text || "")
        var r = {rc: -1, code: 0, dns: 0, connect: 0, tls: 0, ttfb: 0, total: 0, ip: "", portal: 0, portalTo: "", err: "", trace: {}, ntp: "", v4: null}
        var m
        if ((m = t.match(/^WEBRC (\d+)/m))) r.rc = +m[1]
        if ((m = t.match(/^WEB (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ?(\S*)/m))) {
            r.code = +m[1]; r.dns = parseFloat(m[2]); r.connect = parseFloat(m[3]); r.tls = parseFloat(m[4])
            r.ttfb = parseFloat(m[5]); r.total = parseFloat(m[6]); r.ip = m[7]
        }
        if ((m = t.match(/^WEB4 (\d+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ?(\S*)/m)))
            r.v4 = {code: +m[1], dns: parseFloat(m[2]), connect: parseFloat(m[3]), tls: parseFloat(m[4]), ttfb: parseFloat(m[5]), total: parseFloat(m[6]), ip: m[7]}
        if ((m = t.match(/^PORTAL (\d+) ?(\S*)/m))) { r.portal = +m[1]; r.portalTo = m[2] }
        if ((m = t.match(/^WEBERR (?:curl: \(\d+\) )?(.+)$/m))) r.err = m[1].trim()
        var re = /^TRACE (\w+)=(.*)$/gm
        while ((m = re.exec(t)) !== null) r.trace[m[1]] = m[2].trim()
        if ((m = t.match(/^NTP (\S+)/m))) r.ntp = m[1]
        return r
    }

    function parseDiagIpv6(text) {
        var t = String(text || "")
        var r = {addrs: [], routes: 0, ping: null, pub: "", egress: ""}
        var re = /^ADDR6 (\S+)/gm
        var m
        while ((m = re.exec(t)) !== null) r.addrs.push(m[1])
        r.routes = (t.match(/^ROUTE6 /gm) || []).length
        if ((m = t.match(/^EGRESS6 .* dev (\S+)/m))) r.egress = m[1]
        var a = t.indexOf("__PING__")
        if (a >= 0) r.ping = root.parsePing(t.substring(a))
        if ((m = t.match(/^PUBLIC6 (\S+)/m))) r.pub = m[1]
        return r
    }

    // Path MTU: the MTU a router reported, else 1500 when a full-size packet passes,
    // else the largest packet that got an answer (a lower bound), -1 when ping gets no answer at all
    function parseDiagMtu(text) {
        var t = String(text || "")
        var r = {dev: "", devMtu: 0, pmtu: -1, exact: false}
        var m
        if ((m = t.match(/^DEVMTU (\S+) (\d+)/m))) { r.dev = m[1]; r.devMtu = +m[2] }
        var a = t.indexOf("__PMTU__"), b = t.indexOf("__SIZES__")
        var probe = a >= 0 ? t.substring(a, b >= 0 ? b : t.length) : ""
        var best = 0
        var re = /^OK (\d+)/gm
        while ((m = re.exec(t)) !== null) best = Math.max(best, +m[1])
        var told = probe.match(/mtu ?= ?(\d+)/)
        if (told) { r.pmtu = +told[1]; r.exact = true }
        else if (/ bytes from /.test(probe) || best >= 1472) { r.pmtu = 1500; r.exact = true }
        else if (best > 0) r.pmtu = best + 28
        return r
    }

    function parseDiagRoute(text) {
        var hops = []
        var rtt = {}
        var names = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var m
            if ((m = lines[i].match(/^HOP (\d+) (\S+) (\S+) ([012])/))) hops.push({ttl: +m[1], ip: m[2], rtt: m[3] === "-" ? -1 : parseFloat(m[3]), reached: +m[4], name: ""})
            else if ((m = lines[i].match(/^RTT (\S+) ([\d.]+)/))) rtt[m[1]] = parseFloat(m[2])
            else if ((m = lines[i].match(/^NAME (\S+) (\S+)/)) && m[2].charAt(0) !== "_") names[m[1]] = m[2]
        }
        hops.sort(function(a, b) { return a.ttl - b.ttl })
        // Trailing hops without an answer are shown as one "*" row
        var last = -1
        for (var j = 0; j < hops.length; ++j) if (hops[j].ip !== "*") last = j
        var out = hops.slice(0, last + 1)
        if (last + 1 < hops.length) out.push(hops[last + 1])
        for (var k = 0; k < out.length; ++k) {
            if (out[k].rtt < 0 && rtt[out[k].ip] !== undefined) out[k].rtt = rtt[out[k].ip]
            out[k].name = names[out[k].ip] || ""
        }
        return out
    }

    function fmtMs(ms) {
        if (!(ms >= 0)) return "—"
        if (ms < 1) return "<1 ms"
        if (ms < 10) return ms.toFixed(1) + " ms"
        return Math.round(ms) + " ms"
    }

    function diagTint(status) {
        if (status === "ok") return "#35d07f"
        if (status === "warn") return "#e0a030"
        if (status === "fail") return "#ff4040"
        if (status === "running") return root.themeHighlight
        return root.alpha(root.themeText, 0.55)
    }

    // The adapter of the connection: first default route that is not a VPN tunnel
    function diagMainIface(link) {
        var routes = link.routes4.concat(link.routes6)
        var fallback = null
        for (var i = 0; i < routes.length; ++i) {
            var it = link.ifaces[routes[i].dev]
            if (!it) continue
            if (!fallback) fallback = it
            if (it.kind !== "vpn") return it
        }
        return fallback
    }

    function diagVpnName(v, nmNames, apps) {
        if (v.dev === "CloudflareWARP") return "Cloudflare WARP"
        if (/^tailscale/.test(v.dev)) return "Tailscale"
        if (v.dev === "nordlynx") return "NordVPN"
        if (/^proton/.test(v.dev)) return "Proton VPN"
        // A VPN set up in NetworkManager keeps its own name
        if (nmNames && nmNames[v.dev] && nmNames[v.dev] !== v.dev) return nmNames[v.dev]
        // A plain tunnel: named after the VPN application that runs (first match wins)
        var known = [["riseup-vpn", "RiseupVPN"], ["calyx-vpn", "CalyxVPN"], ["bitmask", "Bitmask"], ["mullvad-daemon", "Mullvad"],
                     ["nordvpnd", "NordVPN"], ["expressvpnd", "ExpressVPN"], ["windscribe", "Windscribe"], ["protonvpn-app", "Proton VPN"],
                     ["protonvpn", "Proton VPN"], ["AmneziaVPN", "Amnezia VPN"], ["amnezia-vpn", "Amnezia VPN"], ["hiddify", "Hiddify"],
                     ["openconnect", "OpenConnect"], ["openfortivpn", "FortiClient VPN"]]
        if (apps && v.type !== "wireguard" && v.type !== "ppp") {
            for (var k = 0; k < known.length; ++k)
                if (apps.indexOf(known[k][0]) !== -1) return known[k][1] + " · " + v.dev
        }
        if (v.type === "wireguard") return "WireGuard · " + v.dev
        if (v.type === "openvpn") return "OpenVPN · " + v.dev
        if (v.type === "ppp") return "PPP · " + v.dev
        return "VPN · " + v.dev
    }

    // Results -> the five steps, the detail tiles, the route and the overall verdict
    function diagEvaluate(d, pending, running) {
        d = d || {}
        pending = pending || {}
        function busy(k) { return pending[k] === true }
        function step(key, title) {
            return {key: key, title: title, status: busy(key) ? "running" : "pending", value: busy(key) ? "…" : "", detail: ""}
        }
        var L = d.link, G = d.gateway, N = d.dns, I = d.internet, W = d.web, V6 = d.ipv6, M = d.mtu
        var main = L ? root.diagMainIface(L) : null
        var ip4 = main && main.addrs.length ? main.addrs[0] : ""

        // Internet first: other steps use it ("router ignores ping" when the internet still works)
        var s4 = step("internet", "Internet")
        var net = {ok: false, avg: -1, jitter: -1, loss: -1, target: ""}
        var webOk = !!(W && W.rc === 0 && W.code >= 200 && W.code < 400)
        var portal = !!(W && W.portal > 0 && W.portal !== 204)
        if (I) {
            var best = null, sent = 0, recv = 0
            for (var t = 0; t < I.targets.length; ++t) {
                var pg = I.targets[t].ping
                sent += pg.sent
                recv += pg.recv
                if (pg.recv > 0 && (!best || pg.recv > best.ping.recv || (pg.recv === best.ping.recv && pg.avg < best.ping.avg))) best = I.targets[t]
            }
            if (best) {
                net = {ok: true, avg: best.ping.avg, jitter: best.ping.jitter, loss: sent > 0 ? Math.round((sent - recv) * 100 / sent) : 0, target: best.ip}
                s4.status = net.loss >= 5 || net.avg >= 150 || net.jitter >= 30 ? "warn" : "ok"
                s4.value = root.fmtMs(net.avg)
                s4.detail = best.ip + " · jitter " + root.fmtMs(net.jitter) + " · " + net.loss + "% loss"
            } else if (I.tcp && I.tcp.connect > 0 && !(portal && !webOk)) {
                net.ok = true
                s4.status = "ok"
                s4.value = root.fmtMs(I.tcp.connect * 1000)
                s4.detail = "Ping is blocked on this network · TCP to 1.1.1.1 works"
            } else if (portal && !webOk) {
                // Behind a sign-in page only the portal answers, a TCP connection proves nothing
                s4.status = "warn"
                s4.value = "Blocked"
                s4.detail = "Traffic is held by the sign-in page"
            } else if (webOk) {
                net.ok = true
                s4.status = "ok"
                s4.value = "OK"
                s4.detail = "Ping is blocked on this network · websites work"
            } else {
                s4.status = "fail"
                s4.value = "No reply"
                var why = I.targets.length ? (I.targets[0].ping.from || I.targets[0].ping.error) : ""
                s4.detail = "1.1.1.1 and 8.8.8.8 do not answer" + (why ? " · " + why : "")
            }
        }

        var s1 = step("link", "Connection")
        var wifiWeak = null
        if (L) {
            if (!L.routes4.length && !L.routes6.length) {
                s1.status = "fail"
                s1.value = "Offline"
                s1.detail = "No network connection (no default route)"
            } else if (main) {
                var parts = []
                s1.status = "ok"
                if (main.kind === "wifi") {
                    var w = main.wifi || {ssid: "", freq: 0, dbm: null, signal: -1, rate: 0, chan: ""}
                    // Same percentage as the network applet when NetworkManager reports one
                    var q = w.signal >= 0 ? w.signal : (w.dbm !== null ? root.wifiQuality(w.dbm) : -1)
                    s1.value = "Wi-Fi" + (q >= 0 ? " " + q + "%" : "")
                    if (w.ssid) parts.push("“" + w.ssid + "”")
                    if (w.freq > 0) parts.push((w.freq >= 5925 ? "6 GHz" : (w.freq >= 4900 ? "5 GHz" : "2.4 GHz")) + (w.chan ? " ch " + w.chan : ""))
                    if (w.dbm !== null) parts.push(w.dbm + " dBm")
                    if (w.rate > 0) parts.push(Math.round(w.rate) + " Mbit/s")
                    if ((w.dbm !== null && w.dbm <= -76) || (w.dbm === null && q >= 0 && q < 40)) {
                        s1.status = "warn"
                        wifiWeak = {dbm: w.dbm, q: q}
                    }
                } else if (main.kind === "ethernet") {
                    s1.value = "Ethernet" + (main.speed > 0 ? " " + (main.speed >= 1000 ? (main.speed / 1000) + " Gbit/s" : main.speed + " Mbit/s") : "")
                    if (main.duplex === "half") { parts.push("half duplex"); s1.status = "warn" }
                } else if (main.kind === "mobile") s1.value = "Mobile"
                else if (main.kind === "ppp") s1.value = "PPP"
                else if (main.kind === "bridge") s1.value = "Bridge"
                else if (main.kind === "vpn") s1.value = "VPN tunnel"
                else s1.value = "Connected"
                parts.push(main.dev + (ip4 ? " " + ip4 : ""))
                if (L.nm === "portal") { parts.push("sign-in required"); s1.status = "warn" }
                s1.detail = parts.join(" · ")
            } else {
                s1.status = "ok"
                s1.value = "Connected"
                s1.detail = L.routes4.length ? L.routes4[0].dev : L.routes6[0].dev
            }
        }

        var s2 = step("gateway", "Router")
        if (G) {
            if (G.none) {
                s2.status = "info"
                s2.value = "—"
                s2.detail = L && !L.routes4.length && !L.routes6.length ? "No default gateway" : "Point-to-point link: no router to check"
            } else if (G.ping.recv > 0) {
                s2.status = G.ping.loss >= 20 || G.ping.avg >= 100 ? "warn" : "ok"
                s2.value = root.fmtMs(G.ping.avg)
                s2.detail = G.gw + " · " + Math.round(G.ping.loss) + "% loss"
            } else if (G.neigh === "REACHABLE" || net.ok || webOk) {
                s2.status = "ok"
                s2.value = "OK"
                s2.detail = G.gw + " · does not answer ping, but is reachable"
            } else {
                s2.status = "fail"
                s2.value = "No reply"
                s2.detail = G.gw + " does not respond"
            }
        }

        var s3 = step("dns", "DNS")
        var dnsFail = false, dnsWarn = ""
        if (N) {
            var servers = []
            var devs = []
            if (L && L.egress && L.egress.dev && N.links[L.egress.dev]) devs.push(L.egress.dev)
            if (main && devs.indexOf(main.dev) === -1) devs.push(main.dev)
            for (var dv in N.links) if (N.links.hasOwnProperty(dv) && devs.indexOf(dv) === -1 && N.links[dv].length) devs.push(dv)
            for (var di = 0; di < devs.length; ++di) {
                var list = N.links[devs[di]] || []
                for (var li = 0; li < list.length; ++li) if (servers.indexOf(list[li]) === -1) servers.push(list[li])
            }
            for (var gi = 0; gi < N.global.length; ++gi) if (servers.indexOf(N.global[gi]) === -1) servers.push(N.global[gi])
            var srv = servers.length ? servers.slice(0, 3).join(", ") + (servers.length > 3 ? " …" : "") : ""
            if (N.lookup && N.lookup.rc === 0) {
                var ms = N.nx && (N.nx.rc === 0 || N.nx.rc === 2) ? N.nx.ms : N.lookup.ms
                s3.status = "ok"
                s3.value = root.fmtMs(ms)
                s3.detail = srv ? "Servers: " + srv : "Names are resolved"
                if (N.nx && N.nx.rc === 0 && N.nx.addr) {
                    s3.status = "warn"
                    dnsWarn = "hijack"
                    s3.detail = "Answers for names that do not exist" + (srv ? " · " + srv : "")
                } else if (ms >= 500) {
                    s3.status = "warn"
                    dnsWarn = "slow"
                    s3.detail = "Slow lookups" + (srv ? " · " + srv : "")
                }
            } else {
                dnsFail = true
                var rc = N.lookup ? N.lookup.rc : -1
                s3.status = "fail"
                s3.value = rc === 124 ? "No answer" : "Failed"
                s3.detail = (rc === 124 ? "DNS server does not answer" : (rc === 2 ? "Names are not found" : "Lookup failed")) + (srv ? " · " + srv : "")
                if (N.doh === "ok") s3.detail += " · 1.1.1.1 works"
            }
        }

        var s5 = step("web", "Websites")
        var v6Delay = 0
        if (W) {
            if (webOk) {
                s5.status = W.total > 3 ? "warn" : "ok"
                s5.value = root.fmtMs(W.total * 1000)
                s5.detail = "HTTPS · DNS " + Math.round(W.dns * 1000) + " · connect " + Math.round(Math.max(0, W.connect - W.dns) * 1000)
                    + " · TLS " + Math.round(Math.max(0, W.tls - W.connect) * 1000) + " · reply " + Math.round(Math.max(0, W.ttfb - W.tls) * 1000) + " ms"
                // Connected over IPv4, but much later than an IPv4-only request: IPv6 was tried first and failed
                if (W.v4 && W.v4.code >= 200 && W.v4.code < 400 && W.ip && W.ip.indexOf(":") === -1) {
                    var extra = (W.connect - W.dns) - (W.v4.connect - W.v4.dns)
                    if (extra >= 0.15) {
                        v6Delay = Math.round(extra * 1000)
                        s5.status = "warn"
                        s5.detail += " · failed IPv6 attempts +" + v6Delay + " ms"
                    }
                }
            } else {
                s5.status = "fail"
                s5.value = portal ? "Sign-in" : "Failed"
                s5.detail = portal ? "The network shows a sign-in page" : (W.err ? W.err.replace(/ after \d+ ms/, "") : "HTTP " + W.code)
            }
        }

        // VPN interfaces: found by the script, plus the tunnel that internet traffic leaves through
        var vpns = L ? L.vpns.slice() : []
        if (L && L.egress && L.egress.dev && L.ifaces[L.egress.dev] && L.ifaces[L.egress.dev].kind === "vpn") {
            var listed = false
            for (var vl = 0; vl < vpns.length; ++vl) if (vpns[vl].dev === L.egress.dev) listed = true
            if (!listed) vpns.unshift({dev: L.egress.dev, kind: "vpn", type: ""})
        }
        function isVpn(dev) {
            for (var q = 0; q < vpns.length; ++q) if (vpns[q].dev === dev) return true
            return false
        }
        var vpnFull = !!(L && L.egress && isVpn(L.egress.dev))

        // Detail tiles
        var tiles = []
        var tIp = {key: "web", title: "Public IP", status: busy("web") ? "running" : "pending", value: busy("web") ? "…" : "—", detail: ""}
        if (W) {
            if (webOk && W.trace.ip) {
                tIp.status = "info"
                tIp.value = W.trace.ip
                var ipd = []
                if (W.trace.loc) ipd.push(W.trace.loc)
                if (W.trace.colo) ipd.push("Cloudflare " + W.trace.colo)
                if (W.trace.warp === "on" || W.trace.warp === "plus") ipd.push("WARP " + W.trace.warp)
                tIp.detail = ipd.join(" · ")
            } else {
                tIp.status = "info"
                tIp.detail = "Unavailable"
            }
        }
        tiles.push(tIp)

        var t6 = {key: "ipv6", title: "IPv6", status: busy("ipv6") ? "running" : "pending", value: busy("ipv6") ? "…" : "—", detail: ""}
        var v6Broken = false, v6Leak = false
        if (V6) {
            var v6Works = !!((V6.ping && V6.ping.recv > 0) || V6.pub)
            var v6Global = V6.addrs.filter(function(a) { return /^[23]/.test(a) })
            if (!V6.addrs.length) { t6.status = "info"; t6.value = "Not provided"; t6.detail = "No IPv6 address from the network" }
            else if (vpnFull && V6.egress && isVpn(V6.egress) && !v6Works) { t6.status = "info"; t6.value = "Blocked by VPN"; t6.detail = "The VPN stops IPv6 so it cannot leak around the tunnel" }
            else if (!v6Global.length && !v6Works) { t6.status = "info"; t6.value = "Not provided"; t6.detail = "Only a local address (" + V6.addrs[0].replace(/\/\d+$/, "") + ")" }
            else if (!V6.routes) { t6.status = "info"; t6.value = "No route"; t6.detail = V6.addrs[0] }
            else if (v6Works && vpnFull && V6.egress && !isVpn(V6.egress)) {
                // IPv4 goes through the VPN, IPv6 around it: sites see the real address
                t6.status = "warn"; t6.value = "Bypasses VPN"; t6.detail = "IPv6 leaves through " + V6.egress + ", not the VPN"; v6Leak = true
            }
            else if (V6.ping && V6.ping.recv > 0) { t6.status = "ok"; t6.value = "Works · " + root.fmtMs(V6.ping.avg); t6.detail = V6.pub || V6.addrs[0] }
            else if (V6.pub) { t6.status = "ok"; t6.value = "Works"; t6.detail = V6.pub }
            else if (vpnFull) { t6.status = "info"; t6.value = "Blocked by VPN"; t6.detail = "The VPN stops IPv6 so it cannot leak around the tunnel" }
            else { t6.status = "warn"; t6.value = "No connection"; t6.detail = "Address set, IPv6 traffic fails"; v6Broken = true }
        }
        tiles.push(t6)

        var tv = {key: "link", title: "VPN", status: busy("link") ? "running" : "pending", value: busy("link") ? "…" : "—", detail: ""}
        if (L) {
            if (!vpns.length) { tv.status = "info"; tv.value = "Off"; tv.detail = "No VPN connection" }
            else {
                tv.status = "ok"
                // The tunnel that carries the internet traffic first
                var main0 = vpns[0]
                for (var vv = 0; vv < vpns.length; ++vv) if (L.egress && vpns[vv].dev === L.egress.dev) main0 = vpns[vv]
                tv.value = root.diagVpnName(main0, L.nmNames, L.apps) + (vpns.length > 1 ? " +" + (vpns.length - 1) : "")
                tv.detail = vpnFull ? "Internet traffic goes through the VPN" : "Internet traffic goes around the VPN"
            }
        }
        tiles.push(tv)

        var tm = {key: "mtu", title: "Path MTU", status: busy("mtu") ? "running" : "pending", value: busy("mtu") ? "…" : "—", detail: ""}
        var mtuSmall = false
        if (M) {
            if (M.pmtu > 0) {
                tm.status = M.pmtu < 1280 ? "warn" : "info"
                mtuSmall = M.pmtu < 1280
                tm.value = (M.exact ? "" : "≥ ") + M.pmtu + " bytes"
                tm.detail = M.dev ? M.dev + " MTU " + M.devMtu : ""
            } else {
                tm.status = "info"
                tm.detail = "Unknown: ping gets no answer"
            }
        }
        tiles.push(tm)

        // Verdict: the first broken link of the chain, else the most important warning
        var verdict
        var done = 0
        for (var c = 0; c < root.diagChecks.length; ++c) if (d[root.diagChecks[c]]) done++
        var anyResult = done > 0
        if (running) {
            verdict = {status: "running", title: "Checking the connection…", hint: done + " of " + root.diagChecks.length + " checks done"}
        } else if (!anyResult) {
            verdict = {status: "pending", title: "Not checked yet", hint: "Checks the adapter, router, DNS, internet and websites in about 5 seconds."}
        } else if (s1.status === "fail") {
            verdict = {status: "fail", title: "No network connection", hint: "Connect to Wi-Fi or plug in the network cable."}
        } else if (s2.status === "fail" && !net.ok) {
            verdict = {status: "fail", title: "Router does not respond", hint: "The router" + (G && G.gw ? " " + G.gw : "") + " does not answer. Restart the router or check the cable / Wi-Fi."}
        } else if (!net.ok && !webOk) {
            verdict = portal
                ? {status: "warn", title: "Sign-in required", hint: "This network shows a sign-in page. Open any website in the browser and sign in."}
                : {status: "fail", title: "No internet access", hint: "The router answers, but the internet does not. Check the router's internet connection or call the provider."}
        } else if (dnsFail) {
            verdict = {status: "fail", title: "DNS does not work", hint: "Websites do not open by name. " + (N && N.doh === "ok" ? "Cloudflare DNS 1.1.1.1 works: set it as DNS server or restart the router." : "Restart the router or set DNS to 1.1.1.1.")}
        } else if (!webOk && s5.status === "fail") {
            verdict = portal
                ? {status: "warn", title: "Sign-in required", hint: "This network shows a sign-in page. Open any website in the browser and sign in."}
                : {status: "fail", title: "Websites do not open", hint: "HTTPS fails" + (W && W.err ? ": " + W.err : "") + "." + (W && W.ntp === "no" ? " The system clock is not synchronized." : " Check VPN, proxy or firewall.")}
        } else if (wifiWeak) {
            verdict = {status: "warn", title: "Weak Wi-Fi signal", hint: "Signal " + (wifiWeak.dbm !== null ? wifiWeak.dbm + " dBm, " : "") + wifiWeak.q + "%. Move closer to the router, use 5 GHz or a cable."}
        } else if (s4.status === "warn") {
            verdict = net.loss >= 5
                ? {status: "warn", title: "Unstable connection", hint: net.loss + "% of pings to the internet are lost: calls and games may stutter."}
                : (net.avg >= 150
                    ? {status: "warn", title: "High latency", hint: "Ping to " + net.target + " is " + root.fmtMs(net.avg) + "."}
                    : {status: "warn", title: "Unstable latency", hint: "Jitter " + root.fmtMs(net.jitter) + ": calls and games may stutter."})
        } else if (s2.status === "warn") {
            verdict = {status: "warn", title: "Unstable link to the router", hint: s2.detail + ", " + s2.value + " average."}
        } else if (dnsWarn === "hijack") {
            verdict = {status: "warn", title: "DNS gives fake answers", hint: "Your DNS server answers for names that do not exist. Consider DNS 1.1.1.1."}
        } else if (dnsWarn === "slow") {
            verdict = {status: "warn", title: "Slow DNS", hint: "An uncached lookup takes " + s3.value + ": websites open slowly. Try DNS 1.1.1.1."}
        } else if (v6Delay > 0) {
            verdict = {status: "warn", title: "IPv6 slows down new connections", hint: "Every new connection first tries IPv6, which does not work here: +" + v6Delay + " ms. "
                + (vpnFull ? "The VPN blocks IPv6: turn on its IPv6 support or turn IPv6 off while it is connected." : "Fix IPv6 on the router or turn it off in the network settings.")}
        } else if (s5.status === "warn") {
            verdict = {status: "warn", title: "Websites respond slowly", hint: "A small HTTPS request took " + s5.value + "."}
        } else if (v6Leak) {
            verdict = {status: "warn", title: "IPv6 bypasses the VPN", hint: "IPv6 traffic leaves through " + V6.egress + ": websites can see your real IPv6 address. Turn IPv6 off or enable the VPN's leak protection."}
        } else if (v6Broken) {
            verdict = {status: "warn", title: "IPv6 does not work", hint: "An IPv6 address is set, but IPv6 traffic fails: some apps may be slow."}
        } else if (W && W.ntp === "no") {
            verdict = {status: "warn", title: "Clock not synchronized", hint: "Secure websites may fail when the system time is wrong."}
        } else if (mtuSmall) {
            verdict = {status: "warn", title: "Very small MTU", hint: "Packets larger than " + (M ? M.pmtu : 0) + " bytes do not pass."}
        } else {
            var quality = !net.ok || net.avg < 0 ? "" : (net.loss === 0 && net.avg < 30 && net.jitter < 5 ? "Excellent" : (net.loss < 2 && net.avg < 60 && net.jitter < 10 ? "Good" : (net.loss < 5 && net.avg < 120 && net.jitter < 25 ? "Fair" : "Poor")))
            verdict = {status: "ok", title: "Everything works", hint: quality ? "Quality: " + quality + " · " + root.fmtMs(net.avg) + " · jitter " + root.fmtMs(net.jitter) + " · " + net.loss + "% loss" : "Adapter, router, DNS, internet and websites answer."}
        }
        return {steps: [s1, s2, s3, s4, s5], tiles: tiles, route: d.route || [], verdict: verdict}
    }

    function refreshAppTraffic() {
        if (root.toolsTab !== 4 || !featurePanel.visible || root.appTrafficLoading) return
        root.appTrafficLoading = true
        root.appTrafficStatus = "Reading active connections…"
        // Connections via ss, then a 3 s per-process traffic sample from KDE System Monitor's helper
        appTrafficApi.connectSource("sh -c 'echo __TCP__; ss -Htnp state established 2>/dev/null || echo __FAIL__; echo __UDP__; ss -Hunp 2>/dev/null || echo __FAIL__; echo __RATES__; for h in /usr/lib/*/libexec/ksysguard/ksgrd_network_helper /usr/libexec/ksysguard/ksgrd_network_helper /usr/lib/libexec/ksysguard/ksgrd_network_helper; do [ -x \"$h\" ] || continue; timeout 3 \"$h\" 2>/dev/null; echo __RC__$?; break; done'")
    }

    function toggleAppExpanded(key) {
        // Reassign a copy: mutating the stored object would not notify bindings
        var next = {}
        for (var k in root.appExpanded)
            if (root.appExpanded.hasOwnProperty(k) && root.appExpanded[k] === true) next[k] = true
        if (next[key] === true) delete next[key]
        else next[key] = true
        root.appExpanded = next
    }

    // "addr:port" as printed by ss: IPv6 is "[addr]:port", "%iface" may follow the address, "*" means any
    function appEndpoint(token) {
        var t = String(token || "")
        var i = t.lastIndexOf(":")
        if (i < 0) return {address: "—", port: "—"}
        var address = t.substring(0, i)
        var port = t.substring(i + 1)
        var scope = address.lastIndexOf("%")
        if (scope > address.lastIndexOf("]")) address = address.substring(0, scope)
        if (address.charAt(0) === "[" && address.charAt(address.length - 1) === "]") address = address.substring(1, address.length - 1)
        if (/^::ffff:\d+\.\d+\.\d+\.\d+$/i.test(address)) address = address.substring(7)
        if (!address || address === "*") address = "—"
        if (!port || port === "*") port = "—"
        return {address: address, port: port}
    }

    // ss line: [Netid] [State] Recv-Q Send-Q Local Peer users:(("name",pid=N,fd=N),...)
    // ss drops Netid/State when the filter selects a single table/state, so fields are found by content.
    // Returns null when ss failed or the output is not usable (caller keeps the previous list).
    function parseAppConnections(text) {
        var out = String(text || "")
        if (out.indexOf("__TCP__") === -1 || out.indexOf("__UDP__") === -1 || out.indexOf("__FAIL__") !== -1) return null
        var lines = out.split("\n")
        var map = {}
        var proto = ""
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (!line) continue
            if (line === "__TCP__") { proto = "TCP"; continue }
            if (line === "__UDP__") { proto = "UDP"; continue }
            if (!proto) continue
            var u = line.indexOf("users:((")
            if (u < 0) continue
            var owner = line.substring(u).match(/^users:\(\("(.*?)",pid=(\d+)/)
            if (!owner) continue
            var fields = line.substring(0, u).trim().split(/\s+/)
            var endpoints = []
            for (var f = 0; f < fields.length; ++f)
                if (fields[f].indexOf(":") !== -1) endpoints.push(f)
            if (endpoints.length < 2) continue
            var state = ""
            for (var s = 0; s < endpoints[endpoints.length - 2]; ++s)
                if (/^[A-Z][A-Z0-9-]*$/.test(fields[s])) state = fields[s]
            var peer = root.appEndpoint(fields[endpoints[endpoints.length - 1]])
            var key = owner[1] + "|" + owner[2]
            if (!map[key]) map[key] = {process: owner[1], pid: owner[2], tcp: 0, udp: 0, total: 0, connections: []}
            if (proto === "TCP") map[key].tcp++
            else map[key].udp++
            map[key].total++
            map[key].connections.push({
                protocol: proto,
                address: peer.address,
                port: peer.port,
                state: (!state || state === "ESTAB") ? (proto === "TCP" ? "ESTABLISHED" : "ACTIVE") : state
            })
        }
        var rows = []
        for (var k in map) if (map.hasOwnProperty(k)) rows.push(map[k])
        rows.sort(function(a, b) {
            if (b.total !== a.total) return b.total - a.total
            var n = a.process.localeCompare(b.process)
            return n !== 0 ? n : Number(a.pid) - Number(b.pid)
        })
        // Stable order keeps an expanded list from reshuffling between refreshes
        function byEndpoint(a, b) {
            if (a.protocol !== b.protocol) return a.protocol < b.protocol ? -1 : 1
            if (a.address !== b.address) return a.address < b.address ? -1 : 1
            var p = (Number(a.port) || 0) - (Number(b.port) || 0)
            if (p !== 0) return p
            return a.state === b.state ? 0 : (a.state < b.state ? -1 : 1)
        }
        for (var r = 0; r < rows.length; ++r) {
            // Sockets to the same remote address and port differ only by the local port, which is not shown:
            // one row with a count instead of identical rows
            var seen = {}
            var unique = []
            var conns = rows[r].connections
            for (var c = 0; c < conns.length; ++c) {
                var id = conns[c].protocol + "|" + conns[c].address + "|" + conns[c].port + "|" + conns[c].state
                if (seen.hasOwnProperty(id)) { seen[id].count++; continue }
                conns[c].count = 1
                seen[id] = conns[c]
                unique.push(conns[c])
            }
            rows[r].connections = unique.sort(byEndpoint).slice(0, 30)
            rows[r].display = root.appDisplayName(rows[r].process)
        }
        return rows
    }

    // ksgrd_network_helper (libksysguard, installed with cap_net_raw by the distro package) prints once per second
    // "HH:MM:SS" or "HH:MM:SS|PID|pid|IN|bytes|OUT|bytes" with the bytes of the last second.
    // Returns {state: "ok"|"missing"|"failed"|"nodata", rates: {pid: {rx, tx}}}, rates in bytes per second.
    function parseAppRates(text) {
        var out = String(text || "")
        var rc = out.match(/__RC__(\d+)/)
        if (!rc) return {state: "missing", rates: {}}
        if (rc[1] !== "124" && rc[1] !== "0") return {state: "failed", rates: {}}
        var lines = out.split("\n")
        var stamps = []
        var sums = {}
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].trim().match(/^(\d\d:\d\d:\d\d)(?:\|PID\|(-?\d+)\|IN\|(\d+)\|OUT\|(\d+))?$/)
            if (!m) continue
            if (stamps.indexOf(m[1]) === -1) stamps.push(m[1])
            // The first second only covers helper start-up; sockets without a visible owner come as pid -1
            if (stamps.length < 2 || m[2] === undefined || Number(m[2]) <= 0) continue
            if (!sums[m[2]]) sums[m[2]] = {rx: 0, tx: 0}
            sums[m[2]].rx += Number(m[3])
            sums[m[2]].tx += Number(m[4])
        }
        var seconds = stamps.length - 1
        if (seconds < 1) return {state: "nodata", rates: {}}
        var rates = {}
        for (var pid in sums)
            if (sums.hasOwnProperty(pid)) rates[pid] = {rx: Math.round(sums[pid].rx / seconds), tx: Math.round(sums[pid].tx / seconds)}
        return {state: "ok", rates: rates}
    }

    // Process name -> application name. Processes of one application (Firefox content processes,
    // WARP daemon and tray) end up in one row.
    function appDisplayName(name) {
        var n = String(name || "").trim()
        var names = {
            "?": "Ended processes",
            "chrome": "Chromium", "chromium": "Chromium", "chromium-browse": "Chromium",
            "firefox": "Firefox", "firefox-bin": "Firefox", "Web Content": "Firefox", "Isolated Web Co": "Firefox",
            "Socket Process": "Firefox", "WebExtensions": "Firefox", "Privileged Cont": "Firefox",
            "thunderbird": "Thunderbird", "thunderbird-bin": "Thunderbird",
            "telegram-deskto": "Telegram Desktop", "Telegram": "Telegram Desktop",
            "warp-taskbar": "Cloudflare WARP", "warp-svc": "Cloudflare WARP",
            "riseup-vpn": "RiseupVPN", "syncthing": "Syncthing", "wechat": "WeChat",
            "kdeconnectd": "KDE Connect", "plasmashell": "Plasma", "plasma-discover": "Discover",
            "packagekitd": "PackageKit", "claude-desktop": "Claude"
        }
        if (names.hasOwnProperty(n)) return names[n]
        return n || "Unknown"
    }

    // Traffic per application since boot. KDE's helper only sees traffic while it runs, so it runs
    // in back-to-back 2-minute chunks from Plasma start. Totals are kept per process name and saved
    // with the boot id: they survive Plasma restarts, a reboot starts from zero.
    function startAppUsage(secs) {
        root.appUsageChunkSecs = secs > 0 ? secs : 120
        root.appUsageChunkStart = Date.now()
        // A new command string every time: re-connecting the same source right after it finished
        // makes the executable engine hand back the previous result instead of running it again
        root.appUsageSeq += 1
        appUsageApi.connectSource("sh " + root.codePath("appusage.sh") + " " + root.appUsageChunkSecs + " " + root.appUsageSeq)
    }

    function loadAppUsage(bootId) {
        root.appUsageBoot = bootId
        var saved = null
        try { saved = JSON.parse(appSettings.appUsageJson || "null") } catch (e) { saved = null }
        saved = saved || {}
        // Since-boot totals start from zero after a reboot; hours and recent chunks are wall-clock time and stay.
        // start: when hourly counting began (first run of this version), so a short history is not taken for a full day
        root.appStore = {
            apps: saved.boot === bootId && saved.apps ? saved.apps : {},
            hours: saved.hours || {},
            recent: Array.isArray(saved.recent) ? saved.recent : [],
            seen: saved.seen || {},
            start: saved.start > 0 ? saved.start : Date.now()
        }
        root.appPeriod = ["hour", "day", "boot"].indexOf(appSettings.appPeriod) !== -1 ? appSettings.appPeriod : "day"
        root.saveAppUsage()
        root.rebuildApps()
        // A short first chunk, so totals show up soon after Plasma starts
        root.startAppUsage(20)
    }

    function saveAppUsage() {
        appSettings.appUsageJson = JSON.stringify({boot: root.appUsageBoot, apps: root.appStore.apps, hours: root.appStore.hours,
                                                   recent: root.appStore.recent, seen: root.appStore.seen, start: root.appStore.start})
    }

    function setAppPeriod(period) {
        if (root.appPeriod === period) return
        root.appPeriod = period
        appSettings.appPeriod = period
        root.rebuildApps()
    }

    // appusage.sh lines "<pid> <rx> <tx> <name>" -> bytes per process name in this chunk: {name: [rx, tx]}
    function parseUsageChunk(text) {
        var d = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].match(/^(\d+) (\d+) (\d+) (.+)$/)
            if (!m) continue
            if (!d[m[4]]) d[m[4]] = [0, 0]
            d[m[4]][0] += +m[2]
            d[m[4]][1] += +m[3]
        }
        return d
    }

    // Local wall-clock hour of a time stamp as "yyyyMMddHH"
    function hourKey(ms) {
        var t = new Date(ms)
        function two(n) { return (n < 10 ? "0" : "") + n }
        return String(t.getFullYear()) + two(t.getMonth() + 1) + two(t.getDate()) + two(t.getHours())
    }

    function hourStart(key) {
        var k = String(key)
        return new Date(+k.substring(0, 4), +k.substring(4, 6) - 1, +k.substring(6, 8), +k.substring(8, 10)).getTime()
    }

    // One chunk that ended at time t added to a copy of the store; hours older than 25 h,
    // chunks older than 65 min and last-activity times older than 30 days are dropped
    function addUsageChunk(store, d, t) {
        var next = {apps: {}, hours: {}, recent: [], seen: {}, start: store.start || 0}
        var k
        for (k in store.apps) if (store.apps.hasOwnProperty(k)) next.apps[k] = {rx: store.apps[k].rx, tx: store.apps[k].tx}
        for (k in store.seen) if (store.seen.hasOwnProperty(k) && store.seen[k] > t - 30 * 24 * 3600000) next.seen[k] = store.seen[k]
        var oldest = t - 25 * 3600000
        for (k in store.hours) {
            if (!store.hours.hasOwnProperty(k) || root.hourStart(k) < oldest) continue
            next.hours[k] = {}
            for (var n in store.hours[k]) if (store.hours[k].hasOwnProperty(n)) next.hours[k][n] = store.hours[k][n].slice()
        }
        for (var r = 0; r < store.recent.length; ++r) if (store.recent[r].t > t - 65 * 60000) next.recent.push(store.recent[r])
        var hk = root.hourKey(t)
        if (!next.hours[hk]) next.hours[hk] = {}
        var any = false
        for (var name in d) {
            if (!d.hasOwnProperty(name)) continue
            var rx = d[name][0], tx = d[name][1]
            if (rx + tx <= 0) continue
            any = true
            if (!next.apps[name]) next.apps[name] = {rx: 0, tx: 0}
            next.apps[name].rx += rx
            next.apps[name].tx += tx
            if (!next.hours[hk][name]) next.hours[hk][name] = [0, 0]
            next.hours[hk][name][0] += rx
            next.hours[hk][name][1] += tx
            // Keep-alive packets do not make an application "active"
            if (rx + tx >= 2048) next.seen[name] = t
        }
        if (any) next.recent.push({t: t, d: d})
        return next
    }

    // Traffic per application (display name) in a period: {name: {rx, tx, seen}}
    function periodUsage(store, period, now) {
        var out = {}
        function add(name, rx, tx) {
            var key = root.appDisplayName(name)
            if (!out[key]) out[key] = {rx: 0, tx: 0, seen: 0}
            out[key].rx += rx
            out[key].tx += tx
            if ((store.seen[name] || 0) > out[key].seen) out[key].seen = store.seen[name]
        }
        var n
        if (period === "boot") {
            for (n in store.apps) if (store.apps.hasOwnProperty(n)) add(n, store.apps[n].rx, store.apps[n].tx)
        } else if (period === "hour") {
            for (var r = 0; r < store.recent.length; ++r) {
                if (store.recent[r].t <= now - 3600000) continue
                var d = store.recent[r].d
                for (n in d) if (d.hasOwnProperty(n)) add(n, d[n][0], d[n][1])
            }
        } else {
            // 24 hours: every hourly bucket that overlaps the last 24 hours
            for (var k in store.hours) {
                if (!store.hours.hasOwnProperty(k) || root.hourStart(k) + 3600000 <= now - 24 * 3600000) continue
                for (n in store.hours[k]) if (store.hours[k].hasOwnProperty(n)) add(n, store.hours[k][n][0], store.hours[k][n][1])
            }
        }
        return out
    }

    // Last activity per application (display name), whatever the period
    function appLastSeen(store) {
        var out = {}
        for (var n in store.seen) {
            if (!store.seen.hasOwnProperty(n)) continue
            var key = root.appDisplayName(n)
            if ((out[key] || 0) < store.seen[n]) out[key] = store.seen[n]
        }
        return out
    }

    // Connections of several processes: identical endpoints once, with their count
    function mergeConnections(lists) {
        var seen = {}
        var all = []
        for (var i = 0; i < lists.length; ++i) {
            for (var j = 0; j < lists[i].length; ++j) {
                var c = lists[i][j]
                var id = c.protocol + "|" + c.address + "|" + c.port + "|" + c.state
                if (seen.hasOwnProperty(id)) { seen[id].count += c.count || 1; continue }
                seen[id] = {protocol: c.protocol, address: c.address, port: c.port, state: c.state, count: c.count || 1}
                all.push(seen[id])
            }
        }
        all.sort(function(a, b) {
            if (a.protocol !== b.protocol) return a.protocol < b.protocol ? -1 : 1
            if (a.address !== b.address) return a.address < b.address ? -1 : 1
            var p = (Number(a.port) || 0) - (Number(b.port) || 0)
            if (p !== 0) return p
            return a.state === b.state ? 0 : (a.state < b.state ? -1 : 1)
        })
        return all.slice(0, 30)
    }

    // One row per application: processes with the same name together, traffic of the period,
    // live speed from the 3-second sample. Leaders by traffic first, then who is busy right now,
    // then who was active last.
    function buildAppRows(procs, rates, usage, lastSeen) {
        var groups = {}
        function group(name) {
            if (!groups[name]) groups[name] = {key: name, display: name, pids: [], tcp: 0, udp: 0, total: 0, lists: [], rx: -1, tx: -1, prx: 0, ptx: 0, seen: 0}
            return groups[name]
        }
        for (var i = 0; i < procs.length; ++i) {
            var p = procs[i]
            var g = group(p.display)
            g.pids.push(p.pid)
            g.tcp += p.tcp
            g.udp += p.udp
            g.total += p.total
            g.lists.push(p.connections)
            if (rates.state === "ok") {
                var rate = rates.rates[p.pid]
                g.rx = Math.max(0, g.rx) + (rate ? rate.rx : 0)
                g.tx = Math.max(0, g.tx) + (rate ? rate.tx : 0)
            }
        }
        for (var name in usage) {
            if (!usage.hasOwnProperty(name)) continue
            var u = usage[name]
            if (u.rx + u.tx <= 0 && !groups[name]) continue
            var gu = group(name)
            gu.prx = u.rx
            gu.ptx = u.tx
            gu.seen = u.seen
        }
        var rows = []
        for (var k in groups) {
            if (!groups.hasOwnProperty(k)) continue
            var r = groups[k]
            if (lastSeen && (lastSeen[r.display] || 0) > r.seen) r.seen = lastSeen[r.display]
            r.pids.sort(function(a, b) { return Number(a) - Number(b) })
            r.connections = root.mergeConnections(r.lists)
            delete r.lists
            rows.push(r)
        }
        rows.sort(function(a, b) {
            var d = (b.prx + b.ptx) - (a.prx + a.ptx)
            if (d !== 0) return d
            d = (Math.max(0, b.rx) + Math.max(0, b.tx)) - (Math.max(0, a.rx) + Math.max(0, a.tx))
            if (d !== 0) return d
            if (b.seen !== a.seen) return b.seen - a.seen
            if (b.total !== a.total) return b.total - a.total
            return a.display.localeCompare(b.display)
        })
        var lead = rows.length ? rows[0].prx + rows[0].ptx : 0
        for (var j = 0; j < rows.length; ++j) rows[j].share = lead > 0 ? (rows[j].prx + rows[j].ptx) / lead : 0
        return rows.slice(0, 30)
    }

    function rebuildApps() {
        var now = Date.now()
        var usage = root.periodUsage(root.appStore, root.appPeriod, now)
        var rows = root.buildAppRows(root.appProcs, root.appRatesNow, usage, root.appLastSeen(root.appStore))
        var rx = 0, tx = 0, count = 0
        for (var n in usage) if (usage.hasOwnProperty(n) && usage[n].rx + usage[n].tx > 0) { rx += usage[n].rx; tx += usage[n].tx; count++ }
        var title = root.appPeriod === "hour" ? "Last hour" : (root.appPeriod === "boot" ? "Since boot" : "Last 24 hours")
        var span = root.appPeriod === "hour" ? 3600000 : (root.appPeriod === "day" ? 24 * 3600000 : 0)
        if (span && root.appStore.start > now - span) title += " (counted since " + root.clockText(root.appStore.start, now) + ")"
        root.appPeriodSummary = count ? title + ": ↓ " + root.formatBytes(rx) + "  ↑ " + root.formatBytes(tx) + " · " + count + " app" + (count === 1 ? "" : "s")
                                      : title + ": no traffic counted yet"
        var present = {}
        for (var i = 0; i < rows.length; ++i) present[rows[i].key] = true
        var kept = {}
        var pruned = false
        for (var k in root.appExpanded) {
            if (!root.appExpanded.hasOwnProperty(k)) continue
            if (present[k]) kept[k] = true
            else pruned = true
        }
        if (pruned) root.appExpanded = kept
        // Replace the model in one step, and only when something changed
        if (JSON.stringify(rows) !== JSON.stringify(root.appTraffic)) root.appTraffic = rows
    }

    // "14:05" today, "23 Sep 22:05" on another day
    function clockText(ms, now) {
        var t = new Date(ms)
        function two(n) { return (n < 10 ? "0" : "") + n }
        var hm = two(t.getHours()) + ":" + two(t.getMinutes())
        if (t.toDateString() === new Date(now).toDateString()) return hm
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return t.getDate() + " " + months[t.getMonth()] + " " + hm
    }

    // "last active 14:05" while the application is idle; empty while it is busy (the speed is shown then)
    function appActivity(row, now) {
        if (row.rx > 0 || row.tx > 0) return ""
        if (!row.seen) return ""
        return "last active " + root.clockText(row.seen, now)
    }

    // Detail line of an application that is connected but moved no data in the period
    function appIdleText(row, period, now) {
        var when = period === "hour" ? "in the last hour" : (period === "boot" ? "since boot" : "in the last 24 hours")
        var last = root.appActivity(row, now)
        return "No traffic " + when + (last !== "" ? " · " + last : "")
    }

    function runSpeedTest() {
        if (speedLoading) return
        speedLoading = true
        speedPingMs = -1
        speedJitterMs = -1
        speedDownMbps = -1
        speedUpMbps = -1
        speedServer = ""
        startSpeedPhase("ping")
    }

    function startSpeedPhase(phase) {
        speedLiveMbps = 0
        speedSamplePrev = ({})
        speedSampleTime = 0
        speedPhase = phase
        speedStatus = phase === "ping" ? "Measuring ping…" : (phase === "download" ? "Measuring download…" : "Measuring upload…")
        var cmd = "sh " + codePath("speedtest.sh") + " " + (phase === "download" ? "down" : (phase === "upload" ? "up" : "ping"))
        Qt.callLater(function() { speedApi.connectSource(cmd) })
    }

    function finishSpeedTest(error) {
        speedLoading = false
        speedLiveMbps = 0
        speedUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
        if (error) {
            speedPhase = "error"
            speedStatus = error
        } else {
            speedPhase = "done"
            speedStatus = speedDownMbps < 0 || speedUpMbps < 0 ? "Completed with errors" : "Completed"
        }
    }

    // Cloudflare's method: time to first byte of empty requests minus the server time from
    // Server-Timing; latency = median, jitter = mean difference between consecutive samples
    function parseSpeedPing(text) {
        var lines = String(text || "").split("\n")
        var samples = []
        var colo = ""
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].trim().match(/^PING\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\S*)\|(.*)$/)
            if (!m || m[3] !== "200") continue
            var ms = (parseFloat(m[2]) - parseFloat(m[1])) * 1000
            var st = m[5].match(/cfReq(?:uest)?Dur(?:ation)?;\s*dur=([0-9.]+)/i)
            if (st) ms -= parseFloat(st[1])
            if (ms > 0) samples.push(ms)
            var ray = m[4].match(/-([A-Za-z]{3})$/)
            if (ray) colo = ray[1].toUpperCase()
        }
        if (samples.length < 3) return null
        var sorted = samples.slice().sort(function(a, b) { return a - b })
        var mid = Math.floor(sorted.length / 2)
        var jitter = 0
        for (var j = 1; j < samples.length; ++j) jitter += Math.abs(samples[j] - samples[j - 1])
        return {
            ping: sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2,
            jitter: jitter / (samples.length - 1),
            colo: colo
        }
    }

    // 4 parallel streams: all received bytes over the longest transfer time
    function parseSpeedDown(text) {
        var lines = String(text || "").split("\n")
        var bytes = 0
        var longest = 0
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].trim().match(/^DOWN\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)$/)
            if (!m || m[4] !== "200" || +m[1] <= 0) continue
            var t = parseFloat(m[3]) - parseFloat(m[2])
            if (t <= 0) continue
            bytes += +m[1]
            longest = Math.max(longest, t)
        }
        return longest > 0 ? bytes * 8 / longest / 1e6 : -1
    }

    // Completed upload requests only; streams run in parallel, so their rates add up
    function parseSpeedUp(text) {
        var lines = String(text || "").split("\n")
        var streams = {}
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].trim().match(/^UP\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)$/)
            if (!m) continue
            var t = parseFloat(m[4]) - parseFloat(m[3])
            if (t <= 0 || +m[2] <= 0) continue
            if (!streams[m[1]]) streams[m[1]] = {bytes: 0, time: 0}
            streams[m[1]].bytes += +m[2]
            streams[m[1]].time += t
        }
        var mbps = 0
        var any = false
        for (var k in streams) {
            if (!streams.hasOwnProperty(k)) continue
            mbps += streams[k].bytes * 8 / streams[k].time / 1e6
            any = true
        }
        return any ? mbps : -1
    }

    function formatSpeed(mbps) {
        if (!(mbps >= 0)) return "—"
        if (mbps < 10) return mbps.toFixed(2)
        if (mbps < 100) return mbps.toFixed(1)
        return String(Math.round(mbps))
    }

    // Log scale 0..1000 Mbps for the gauge arc
    function gaugeFraction(mbps) {
        return Math.min(1, Math.log(1 + Math.max(0, mbps)) / Math.log(1001))
    }

    function cssColor(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    // Live gauge value from /proc/net/dev. With a VPN the same bytes pass two interfaces,
    // so the busiest interface is used instead of the sum.
    function applySpeedSample(text) {
        if (root.speedPhase !== "download" && root.speedPhase !== "upload") return
        var now = Date.now()
        var cur = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
            var m = lines[i].match(/^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/)
            if (m && m[1] !== "lo") cur[m[1]] = {rx: +m[2], tx: +m[3]}
        }
        var dt = (now - root.speedSampleTime) / 1000
        if (root.speedSampleTime > 0 && dt > 0.2) {
            var best = 0
            for (var k in cur) {
                var prev = root.speedSamplePrev[k]
                if (!cur.hasOwnProperty(k) || !prev) continue
                var d = root.speedPhase === "upload" ? cur[k].tx - prev.tx : cur[k].rx - prev.rx
                if (d > best) best = d
            }
            var mbps = best * 8 / dt / 1e6
            root.speedLiveMbps = root.speedLiveMbps > 0 ? root.speedLiveMbps * 0.35 + mbps * 0.65 : mbps
        }
        root.speedSamplePrev = cur
        root.speedSampleTime = now
    }

    function formatBytes(bytes) {
        var n = Number(bytes)
        if (!isFinite(n) || n < 0) return "—"
        if (n < 1024) return Math.round(n) + " B"
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
        if (n < 1024 * 1024 * 1024 * 1024) return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
        return (n / (1024 * 1024 * 1024 * 1024)).toFixed(2) + " TB"
    }

    function refreshTraffic() {
        trafficApi.connectSource("awk 'NR > 2 && $1 != \"lo:\" {rx += $2; tx += $10} END {printf \"%s %s\\n\", rx+0, tx+0}' /proc/net/dev")
    }

    Plasma5Support.DataSource {
        id: publicApi; engine: "executable"
        onNewData: function(source, data) {
            publicApi.disconnectSource(source); root.loading = false
            var r = root.parsePublicIp(data.stdout)
            // On failure the last known data stays on screen
            if (!r.ok) { root.errorText = r.error; return }
            root.errorText = ""
            root.ipSource = r.src
            root.publicIp = r.ip
            root.country = r.country || "—"
            root.countryCode = r.countryCode
            root.city = r.city || "—"
            root.region = r.region || "—"
            root.latitude = isFinite(r.lat) ? r.lat.toFixed(5) : "—"
            root.longitude = isFinite(r.lon) ? r.lon.toFixed(5) : "—"
            root.provider = r.isp || "—"
            root.asn = r.asn || "—"
            root.timezone = r.tz || "—"
            root.updated = Qt.formatTime(new Date(), "HH:mm:ss")
        }
    }

    Plasma5Support.DataSource {
        id: localApi; engine: "executable"
        onNewData: function(source, data) {
            localApi.disconnectSource(source); var result = []
            try {
                var all = JSON.parse(data.stdout || "[]")
                for (var i=0;i<all.length;++i) {
                    var iface=all[i], addresses=iface.addr_info||[]
                    var item={iface:iface.ifname||"?",mac:iface.address||"—",ipv4:[],ipv4Prefix:[],ipv6:[],ipv6Prefix:[]}
                    for (var j=0;j<addresses.length;++j) { var a=addresses[j]; if(!a.local) continue; var p=a.prefixlen!==undefined?String(a.prefixlen):"—"; if(a.family==="inet6"){item.ipv6.push(a.local);item.ipv6Prefix.push(p)}else{item.ipv4.push(a.local);item.ipv4Prefix.push(p)} }
                    if(iface.link_type==="loopback"||item.iface==="lo") continue
                    if(item.ipv4.length||item.ipv6.length) result.push(item)
                }
            } catch(e) {}
            root.localItems=result
            root.sortLocalItems()
            root.updateScanDefault()
        }
    }

    Plasma5Support.DataSource {
        id: routeApi; engine: "executable"
        onNewData: function(source,data){ routeApi.disconnectSource(source); var map={}; try{var routes=JSON.parse(data.stdout||"[]");for(var i=0;i<routes.length;++i)if(routes[i].dev&&routes[i].gateway)map[routes[i].dev]=routes[i].gateway}catch(e){} root.gatewayMap=map;root.sortLocalItems();root.updateScanDefault() }
    }
    Plasma5Support.DataSource {
        id: dnsApi; engine: "executable"
        onNewData: function(source,data){ dnsApi.disconnectSource(source); var map={}; var lines=String(data.stdout||"").split("\n"); for(var i=0;i<lines.length;++i){var line=lines[i].trim();var m=line.match(/^Link\s+\d+\s+\(([^)]+)\):\s*(.*)$/);if(m&&m[1]&&m[2])map[m[1]]=m[2].trim().replace(/\s+/g,", ")} root.dnsMap=map;root.sortLocalItems();root.updateScanDefault();root.localLoading=false }
    }
    Plasma5Support.DataSource { id: uptimeApi; engine:"executable"; onNewData:function(source,data){uptimeApi.disconnectSource(source);var raw=String(data.stdout||"").trim();if(raw)root.systemUptime=root.formatUptime(raw)} }

    Plasma5Support.DataSource {
        id: statusApi; engine: "executable"
        onNewData: function(source, data) {
            statusApi.disconnectSource(source)
            var state = String(data.stdout || "").trim().split(/\s+/)[0] || "OFFLINE"
            root.internetStatus = state === "VPN" || state === "ONLINE" ? "Online" : "Offline"
            root.internetQuality = state === "VPN" || state === "ONLINE" ? "online" : "offline"
            root.vpnActive = state === "VPN"
            root.networkLoading = false
        }
    }
    Plasma5Support.DataSource {
        id: diagApi; engine: "executable"
        onNewData: function(source, data) {
            diagApi.disconnectSource(source)
            var m = String(source).match(/netdiag\.sh' (\w+) (\d+)$/)
            if (!m || +m[2] !== root.diagSeq || !root.diagRunning) return
            root.diagResult(m[1], data.stdout)
        }
    }
    // A check that hangs must not keep the run open forever
    Timer {
        id: diagWatchdog
        interval: 25000
        onTriggered: {
            for (var k in root.diagPending)
                if (root.diagPending.hasOwnProperty(k)) diagApi.disconnectSource("bash " + root.codePath("netdiag.sh") + " " + k + " " + root.diagSeq)
            root.finishDiagnostics()
        }
    }
    Plasma5Support.DataSource {
        id: speedApi; engine: "executable"
        onNewData: function(source, data) {
            speedApi.disconnectSource(source)
            var out = String(data.stdout || "")
            if (root.speedPhase === "ping") {
                var p = root.parseSpeedPing(out)
                if (!p) { root.finishSpeedTest("Cloudflare is not reachable"); return }
                root.speedPingMs = p.ping
                root.speedJitterMs = p.jitter
                root.speedServer = p.colo
                root.startSpeedPhase("download")
            } else if (root.speedPhase === "download") {
                root.speedDownMbps = root.parseSpeedDown(out)
                root.startSpeedPhase("upload")
            } else if (root.speedPhase === "upload") {
                root.speedUpMbps = root.parseSpeedUp(out)
                root.finishSpeedTest("")
            }
        }
    }
    Plasma5Support.DataSource {
        id: speedSampleApi; engine: "executable"
        onNewData: function(source, data) { speedSampleApi.disconnectSource(source); root.applySpeedSample(data.stdout) }
    }
    // Live gauge: interface byte counters twice a second, only while a transfer runs
    Timer {
        interval: 500
        repeat: true
        running: root.speedPhase === "download" || root.speedPhase === "upload"
        onTriggered: {
            root.speedSampleSeq += 1
            speedSampleApi.connectSource("MYIPGEO_SEQ=" + root.speedSampleSeq + " cat /proc/net/dev")
        }
    }
    Plasma5Support.DataSource { id: trafficApi; engine:"executable"; onNewData:function(source,data){trafficApi.disconnectSource(source);var p=String(data.stdout||"").trim().split(/\s+/);if(p.length>=2){root.trafficReceived=root.formatBytes(p[0]);root.trafficSent=root.formatBytes(p[1]);root.trafficUpdated=Qt.formatTime(new Date(),"HH:mm:ss")}} }
    Plasma5Support.DataSource {
        id: appUsageApi; engine: "executable"
        onNewData: function(source, data) {
            appUsageApi.disconnectSource(source)
            var out = String(data.stdout || "")
            var ran = (Date.now() - root.appUsageChunkStart) / 1000
            if (out.indexOf("__OK__") === -1) {
                root.appUsageState = out.indexOf("__MISSING__") !== -1 ? "missing" : "failed"
                appUsageRetry.start()
                return
            }
            // A chunk that ended far too early is not trusted and retried later instead of spinning
            if (ran < root.appUsageChunkSecs / 2) { appUsageRetry.start(); return }
            root.appUsageState = "ok"
            root.appStore = root.addUsageChunk(root.appStore, root.parseUsageChunk(out), Date.now())
            root.appUsageUpdated = Qt.formatTime(new Date(), "HH:mm")
            root.saveAppUsage()
            root.rebuildApps()
            Qt.callLater(function() { root.startAppUsage(120) })
        }
    }
    Plasma5Support.DataSource {
        id: bootIdApi; engine: "executable"
        onNewData: function(source, data) { bootIdApi.disconnectSource(source); root.loadAppUsage(String(data.stdout || "").trim()) }
    }
    Timer { id: appUsageRetry; interval: 600000; onTriggered: root.startAppUsage(120) }
    Plasma5Support.DataSource { id: appTrafficApi; engine:"executable"; onNewData:function(source,data){
        appTrafficApi.disconnectSource(source)
        var out = String(data.stdout || "")
        var cut = out.indexOf("__RATES__")
        var rows = root.parseAppConnections(cut >= 0 ? out.substring(0, cut) : out)
        if (rows === null) {
            // Keep the last good list on screen
            root.appTrafficStatus = "Could not read connections · " + Qt.formatTime(new Date(), "HH:mm:ss")
            root.appTrafficLoading = false
            return
        }
        var rates = root.parseAppRates(cut >= 0 ? out.substring(cut) : "")
        root.appRatesState = rates.state
        root.appProcs = rows
        root.appRatesNow = rates
        root.rebuildApps()
        var connected = {}
        var apps = 0
        for (var i = 0; i < rows.length; ++i) if (!connected[rows[i].display]) { connected[rows[i].display] = true; apps++ }
        root.appTrafficStatus = (apps ? apps + " connected now" : "No connections now") + " · " + Qt.formatTime(new Date(), "HH:mm:ss")
        root.appTrafficLoading = false
    } }
    Plasma5Support.DataSource { id: dependencyApi; engine:"executable"; onNewData:function(source,data){dependencyApi.disconnectSource(source);var out=String(data.stdout||"").trim();root.missingDependencies=out.replace(/^\s+|\s+$/g,"").replace(/\n+/g," ");var pkgs=root.missingDependencies.trim().split(/\s+/).filter(function(x){return x});root.installCommand=pkgs.length?"sudo apt install "+pkgs.join(" "):"";root.dependenciesLoading=false} }
    Plasma5Support.DataSource {
        id: scanApi; engine: "executable"
        onNewData: function(source, data) {
            scanApi.disconnectSource(source)
            root.scanLoading = false
            var r = root.parseScan(data.stdout, root.scanRunCidr)
            if (r.error) { root.scanStatus = r.error; return }
            root.scanHosts = r.hosts
            root.scanStatus = r.hosts.length + " device" + (r.hosts.length === 1 ? "" : "s") + " · " + Qt.formatTime(new Date(), "HH:mm:ss")
            var ips = []
            for (var i = 0; i < r.hosts.length; ++i) ips.push(r.hosts[i].ip)
            if (ips.length) scanNamesApi.connectSource("sh " + root.codePath("netscan.sh") + " names " + ips.join(" "))
        }
    }
    Plasma5Support.DataSource {
        id: scanNamesApi; engine: "executable"
        onNewData: function(source, data) {
            scanNamesApi.disconnectSource(source)
            var names = {}
            var lines = String(data.stdout || "").split("\n")
            for (var i = 0; i < lines.length; ++i) {
                var m = lines[i].trim().match(/^(\d+\.\d+\.\d+\.\d+)\s+(\S+)$/)
                // systemd-resolved answers "_gateway" for the router: a placeholder, not its name
                if (m && m[2].charAt(0) !== "_") names[m[1]] = m[2]
            }
            root.scanNames = names
        }
    }
    Plasma5Support.DataSource {
        id: portScanApi; engine: "executable"
        onNewData: function(source, data) {
            portScanApi.disconnectSource(source)
            portScanWatchdog.stop()
            var ip = root.portScanIp
            root.portScanIp = ""
            root.portScanSource = ""
            if (!ip) return
            var r = root.parsePortScan(data.stdout)
            if (r.error) { root.setPortScan(ip, {state: "error", error: r.error}); return }
            if (!r.done) { root.setPortScan(ip, {state: "error", error: "Scan did not finish"}); return }
            root.setPortScan(ip, {state: "done", scanned: r.scanned, ports: r.ports, error: "", secs: r.secs})
        }
    }
    // portscan.sh stops itself after 170 s; this only frees the Scan buttons if the process never returns
    Timer {
        id: portScanWatchdog
        interval: 200000
        repeat: false
        onTriggered: {
            if (root.portScanSource !== "") portScanApi.disconnectSource(root.portScanSource)
            var ip = root.portScanIp
            root.portScanIp = ""
            root.portScanSource = ""
            if (ip) root.setPortScan(ip, {state: "error", error: "Scan did not finish"})
        }
    }
    Plasma5Support.DataSource { id: monitorApi; engine:"executable"; onNewData:function(source,data){
        monitorApi.disconnectSource(source)
        var lines=String(data.stdout||"").split("\n")
        var states={}
        var via={}
        for(var i=0;i<lines.length;++i){
            var line=lines[i].trim(); if(!line) continue
            var parts=line.split("\t"); if(parts.length<2) continue
            states[parts[0]]=parts[1]
            via[parts[0]]=parts[2]||""
        }
        var list=root.watchedDevices.slice(0)
        for(var j=0;j<list.length;++j){
            var item=list[j]; var next=states[item.ip]||"DOWN"; var old=item.status||"Unknown"
            item.status=next; item.via=next==="UP"?(via[item.ip]||""):""; item.lastCheck=Qt.formatTime(new Date(),"HH:mm:ss")
            if(old!=="Unknown" && old!==next){
                var title="Network device status changed"
                var body=item.ip+" is now "+(next==="UP"?"online":"offline")
                monitorNotifyApi.connectSource("sh "+root.codePath("notify.sh")+" '"+title+"' '"+body.replace(/'/g," ")+"' "+root.codePath("../icon.png"))
            }
        }
        root.watchedDevices=list
        saveWatchedDevices()
        root.monitorLoading=false
    } }
    Plasma5Support.DataSource { id: monitorNotifyApi; engine:"executable"; onNewData:function(source,data){monitorNotifyApi.disconnectSource(source)} }

    Timer { interval:5000
 repeat:true
 running:true
 onTriggered:root.refreshTraffic() }
    // Apps: refreshed on open, by its Refresh button and every 10 min while visible (no fast polling)
    Timer { interval:600000
 repeat:true
 running:true
 onTriggered:root.refreshAppTraffic() }
    Connections {
        target: featurePanel
        function onVisibleChanged() { root.refreshAppTraffic(); root.autoRunDiagnostics() }
    }
    Timer { interval:600000
 repeat:true
 running:true
 onTriggered: { if(!root.loading&&!root.localLoading)root.refreshAll(); root.monitorWatchedDevices() } }
    Timer { interval:30000
 repeat:true
 running:true
 onTriggered:{ root.refreshNetwork(); root.monitorWatchedDevices() } }
    Component.onCompleted: { bootIdApi.connectSource("cat /proc/sys/kernel/random/boot_id"); root.loadWatchedDevices(); root.refreshAll(); root.refreshTraffic(); root.refreshAppTraffic(); root.checkDependencies(); root.monitorWatchedDevices() }

    compactRepresentation: Item {
        implicitWidth: 180
 implicitHeight: 32
        RowLayout { anchors.fill:parent
 spacing:6
            Image { source:Qt.resolvedUrl("../images/cat.jpg")
 sourceSize.width:24
sourceSize.height:24
Layout.preferredWidth:24
Layout.preferredHeight:24 }
            Text { Layout.fillWidth:true
text:root.publicIp==="—"?"My IP & Geo":root.publicIp
color:root.themeText
font.pixelSize:11
verticalAlignment:Text.AlignVCenter }
            Text { text:root.internetStatus==="Online"?"●":"○"
color:root.internetStatus==="Online"?root.themePositive:root.themeSecondary
font.pixelSize:13 }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: root.alpha(root.themeBackground, 0.98)
        border.width: 1
        border.color: "#ff3030"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                spacing: 10

                Image {
                    source: Qt.resolvedUrl("../images/cat.jpg")
                    sourceSize.width: 64
                    sourceSize.height: 64
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "My IP & Geo"
                        color: root.themeText
                        font.pixelSize: 19
                        font.bold: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 5
                    color: root.alpha(root.themeText, 0.035)
                    Text {
                        anchors.fill: parent
                        text: "Public IP"
                        color: root.themeText
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: root.tab === 0 ? "#ff3030" : "transparent"
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.tab = 0 }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 5
                    color: root.alpha(root.themeText, 0.035)
                    Text {
                        anchors.fill: parent
                        text: "Local IPs"
                        color: root.themeText
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: root.tab === 1 ? "#ff3030" : "transparent"
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.tab = 1 }
                }
            }

            Rectangle {
                id: mainContentFrame
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 220
                radius: 13
                color: root.alpha(root.themeText, 0.035)
                border.width: 1
                border.color: root.alpha(root.themeText, 0.12)
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 12

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6
                        visible: root.tab === 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            TextEdit {
                                text: root.publicIp
                                color: root.themeText
                                font.pixelSize: 25
                                font.bold: true
                                readOnly: true
                                selectByMouse: true
                                selectByKeyboard: true
                                cursorVisible: false
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.flag(root.countryCode)
                                font.pixelSize: 22
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.alpha(root.themeText, 0.08)
                        }

                        TextEdit {
                            Layout.fillWidth: true
                            text: "Country: " + root.country
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: "Location: " + root.city + (root.region !== "—" ? ", " + root.region : "")
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: "Coordinates: " + root.latitude + ", " + root.longitude
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: "Provider: " + root.provider
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: "ASN: " + root.asn
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: "Time zone: " + root.timezone
                            color: root.themeText
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                            Layout.preferredHeight: Math.max(18, contentHeight)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.errorText !== "" ? root.errorText : "Updated: " + root.updated + (root.ipSource !== "" ? " · " + root.ipSource : "") + " · Auto-refresh: 10 min"
                            color: root.errorText !== "" ? root.themeNegative : root.themeSecondary
                            font.pixelSize: 10
                        }
                        // Takes the free height of a stretched widget, the rows above stay together
                        Item { Layout.fillHeight: true }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6
                        visible: root.tab === 1

                        Flickable {
                            id: localFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: Math.max(height, localTable.height)
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height

                            Column {
                                id: localTable
                                width: localFlick.width
                                spacing: 6

                                Repeater {
                                    model: root.localItems
                                    delegate: Rectangle {
                                        id: localRow
                                        readonly property var netItem: modelData
                                        readonly property var addrRows: root.ifaceAddrRows(netItem)
                                        width: localTable.width
                                        height: localCard.implicitHeight + 20
                                        radius: 9
                                        color: root.alpha(root.themeText, 0.045)
                                        border.width: 1
                                        border.color: root.alpha(root.themeText, 0.16)
                                        clip: true

                                        Column {
                                            id: localCard
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 10
                                            spacing: 6

                                            // Interface name and connection type
                                            Item {
                                                width: parent.width
                                                implicitHeight: Math.max(ifaceName.implicitHeight, typeBadge.height)
                                                TextEdit {
                                                    id: ifaceName
                                                    anchors.left: parent.left
                                                    anchors.right: typeBadge.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: localRow.netItem.iface
                                                    color: root.themeText
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    readOnly: true; selectByMouse: true; selectByKeyboard: true; cursorVisible: false
                                                    wrapMode: TextEdit.NoWrap
                                                }
                                                Rectangle {
                                                    id: typeBadge
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    radius: 4
                                                    color: root.alpha(root.themeLink, 0.14)
                                                    width: typeLabel.implicitWidth + 12
                                                    height: typeLabel.implicitHeight + 6
                                                    Text {
                                                        id: typeLabel
                                                        anchors.centerIn: parent
                                                        text: (localRow.netItem.ipv4.length && localRow.netItem.ipv6.length) ? "IPv4 + IPv6" : (localRow.netItem.ipv4.length ? "IPv4" : "IPv6")
                                                        color: root.themeLink
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                            TextEdit {
                                                width: parent.width
                                                visible: localRow.netItem.mac && localRow.netItem.mac !== "\u2014"
                                                text: "MAC  " + localRow.netItem.mac
                                                color: root.themeSecondary
                                                font.pixelSize: 10
                                                readOnly: true; selectByMouse: true; selectByKeyboard: true; cursorVisible: false
                                                wrapMode: TextEdit.NoWrap
                                            }

                                            Rectangle { width: parent.width; height: 1; color: root.alpha(root.themeText, 0.10) }

                                            // Every address on its own line: an "IPv4"/"IPv6" header then one row per address
                                            Repeater {
                                                model: localRow.addrRows
                                                delegate: Item {
                                                    width: localCard.width
                                                    implicitHeight: modelData.header !== undefined ? addrHeader.implicitHeight + 2 : Math.max(addrValue.implicitHeight, maskText.implicitHeight)
                                                    Text {
                                                        id: addrHeader
                                                        visible: modelData.header !== undefined
                                                        anchors.left: parent.left
                                                        anchors.bottom: parent.bottom
                                                        text: modelData.header || ""
                                                        color: root.themeSecondary
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                    TextEdit {
                                                        id: addrValue
                                                        visible: modelData.header === undefined
                                                        anchors.left: parent.left
                                                        anchors.right: maskText.left
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.addr || ""
                                                        color: root.themeText
                                                        font.pixelSize: modelData.fam === 6 ? 11 : 12
                                                        readOnly: true; selectByMouse: true; selectByKeyboard: true; cursorVisible: false
                                                        wrapMode: TextEdit.NoWrap
                                                    }
                                                    Text {
                                                        id: maskText
                                                        visible: modelData.header === undefined && !!modelData.mask
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.mask ? "mask " + modelData.mask : ""
                                                        color: root.themeSecondary
                                                        font.pixelSize: 10
                                                    }
                                                }
                                            }

                                            Rectangle { width: parent.width; height: 1; color: root.alpha(root.themeText, 0.10) }

                                            // Gateway and DNS for this interface
                                            Row {
                                                width: parent.width
                                                spacing: 8
                                                Text { text: "Gateway"; color: root.themeSecondary; font.pixelSize: 10; width: 62; anchors.verticalCenter: parent.verticalCenter }
                                                TextEdit {
                                                    width: parent.width - 70
                                                    text: root.gatewayFor(localRow.netItem.iface)
                                                    color: root.themeText
                                                    font.pixelSize: 11
                                                    readOnly: true; selectByMouse: true; selectByKeyboard: true; cursorVisible: false
                                                    wrapMode: TextEdit.NoWrap
                                                }
                                            }
                                            Row {
                                                width: parent.width
                                                spacing: 8
                                                Text { text: "DNS"; color: root.themeSecondary; font.pixelSize: 10; width: 62; anchors.verticalCenter: parent.verticalCenter }
                                                TextEdit {
                                                    width: parent.width - 70
                                                    text: root.dnsFor(localRow.netItem.iface)
                                                    color: root.themeText
                                                    font.pixelSize: 11
                                                    readOnly: true; selectByMouse: true; selectByKeyboard: true; cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.localItems.length === 0
                                    text: root.localLoading ? "Loading local addresses…" : "No local addresses found"
                                    color: root.themeSecondary
                                    font.pixelSize: 11
                                }
                            }
                        }

                        RowLayout {
                            visible: root.missingDependencies !== ""
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Missing: " + root.missingDependencies
                                color: root.themeNegative
                                font.pixelSize: 10
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
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
                        }
                    }
                }
            }

            Rectangle {
                id: trafficBar
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 12
                color: root.alpha(root.themeText, 0.035)
                border.width: 1
                border.color: root.alpha(root.themeText, 0.10)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Image {
                            source: Qt.resolvedUrl("../images/arrow-down.svg")
                            sourceSize.width: 28
                            sourceSize.height: 34
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 34
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: "Received"; color: root.themeSecondary; font.pixelSize: 9 }
                            Text { text: root.trafficReceived; color: root.themeText; font.pixelSize: 13; font.bold: true }
                        }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 30; color: root.alpha(root.themeText, 0.12) }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Image {
                            source: Qt.resolvedUrl("../images/arrow-up.svg")
                            sourceSize.width: 28
                            sourceSize.height: 34
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 34
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: "Sent"; color: root.themeSecondary; font.pixelSize: 9 }
                            Text { text: root.trafficSent; color: root.themeText; font.pixelSize: 13; font.bold: true }
                        }
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 30; color: root.alpha(root.themeText, 0.12) }

                    ColumnLayout {
                        Layout.preferredWidth: 122
                        spacing: 1
                        RowLayout {
                            spacing: 5
                            Image { source: Qt.resolvedUrl("../images/clock.svg"); sourceSize.width: 18; sourceSize.height: 18; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                            Text { text: "Uptime: " + root.systemUptime; color: root.themeText; font.pixelSize: 13; Layout.fillWidth: true }
                        }
                        RowLayout {
                            spacing: 5
                            Image { source: Qt.resolvedUrl("../images/github.svg"); sourceSize.width: 18; sourceSize.height: 18; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                            Text { text: "GitHub"; color: root.themeLink; font.pixelSize: 13; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("https://github.com/f1devbin") } }
                            Text { text: "· v6.1.48"; color: root.themeSecondary; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // Header actions are outside the ColumnLayout so they do not consume layout space.
    Row {
        id: headerActions
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.rightMargin: 14
        spacing: 4
        z: 20
        Item {
            id: vpnIndicatorItem
            width: root.vpnActive ? 22 : 0
            height: 30
            visible: root.vpnActive
            Canvas {
                id: vpnIndicator
                anchors.centerIn: parent
                width: 20
                height: 22
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#35d07f"
                    ctx.beginPath()
                    ctx.moveTo(10, 1)
                    ctx.lineTo(18, 4)
                    ctx.lineTo(17, 11)
                    ctx.quadraticCurveTo(16, 17, 10, 21)
                    ctx.quadraticCurveTo(4, 17, 3, 11)
                    ctx.lineTo(2, 4)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = root.themeSurface
                    ctx.lineWidth = 1.5
                    ctx.beginPath()
                    ctx.moveTo(7, 10.5)
                    ctx.lineTo(9.2, 12.5)
                    ctx.lineTo(13.2, 8.5)
                    ctx.stroke()
                }
            }
        }
        Item {
            width: 22
            height: 30
            Canvas {
                id: internetIndicator
                anchors.centerIn: parent
                width: 20
                height: 22
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = root.internetQuality === "offline" ? "#ff4040" : "#35d07f"
                    ctx.beginPath()
                    ctx.arc(10, 11, 6, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }
            Connections { target: root; function onInternetQualityChanged() { internetIndicator.requestPaint() } }
        }
        Controls.Button {
            id: toolsMenuButton
            width:30
            height:30
            onClicked: featurePanel.visible = true
            background: Rectangle {
                radius:5
                color: toolsMenuButton.down ? root.alpha(root.themeHighlight, .20)
                    : (toolsMenuButton.hovered ? root.alpha(root.themeHighlight, .12)
                    : root.alpha(root.themeBackground, .92))
                border.width:1
                border.color:"#ff3030"
            }
            contentItem: Item {
                anchors.fill:parent
                Rectangle { width:14; height:1; radius:1; color:root.themeText; anchors.horizontalCenter:parent.horizontalCenter; anchors.verticalCenter:parent.verticalCenter; anchors.verticalCenterOffset:-5 }
                Rectangle { width:14; height:1; radius:1; color:root.themeText; anchors.horizontalCenter:parent.horizontalCenter; anchors.verticalCenter:parent.verticalCenter }
                Rectangle { width:14; height:1; radius:1; color:root.themeText; anchors.horizontalCenter:parent.horizontalCenter; anchors.verticalCenter:parent.verticalCenter; anchors.verticalCenterOffset:5 }
            }
        }
        Controls.Button {
            id: headerRefreshButton
            width:30
            height:30
            text:root.loading||root.localLoading?"…":"↻"
            enabled:!root.loading&&!root.localLoading
            onClicked:root.refreshAll()
            background:Rectangle {
                radius:5
                color:headerRefreshButton.down?root.alpha(root.themeHighlight,.20):(headerRefreshButton.hovered?root.alpha(root.themeHighlight,.12):root.alpha(root.themeBackground,.92))
                border.width:1
                border.color:"#ff3030"
            }
            contentItem:Text {
                text:headerRefreshButton.text
                color:root.themeText
                font.pixelSize:14
                horizontalAlignment:Text.AlignHCenter
                verticalAlignment:Text.AlignVCenter
            }
        }
    }

    Rectangle {
        id: featurePanel
        visible: false
        anchors.fill: parent
        anchors.margins: 12
        radius: 14
        z: 100
        color: root.alpha(root.themeBackground, 1)
        border.width: 1
        border.color: "#ff3030"

        Component.onCompleted: root.updateScanDefault()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "Network tools"
                    color: root.themeText
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }
                Controls.Button {
                    text: "×"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: featurePanel.visible = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Controls.Button {
                    text: "Scanner"
                    Layout.fillWidth: true
                    onClicked: root.toolsTab = 0
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 0 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 0 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Controls.Button {
                    text: "Diagnostics"
                    Layout.fillWidth: true
                    onClicked: { root.toolsTab = 1; root.autoRunDiagnostics() }
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 1 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 1 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Controls.Button {
                    text: "Speed"
                    Layout.fillWidth: true
                    onClicked: root.toolsTab = 3
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 3 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 3 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Controls.Button {
                    text: "Apps"
                    Layout.fillWidth: true
                    onClicked: { root.toolsTab = 4; root.refreshAppTraffic() }
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 4 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 4 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Controls.Button {
                    text: "Monitor"
                    Layout.fillWidth: true
                    onClicked: root.toolsTab = 5
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 5 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 5 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6
                    visible: root.toolsTab === 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Network Scanner"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                        Text { text: root.scanLoading ? "Scanning…" : root.scanStatus; color: root.scanLoading ? root.themeHighlight : root.themeSecondary; font.pixelSize: 9 }
                    }
                    Text {
                        text: "Finds every device on the network, including ones that ignore ping (they still answer ARP). A scan takes about 10 seconds. Press the magnifier next to a device to scan its open ports."
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
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: scanHostColumn.height
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: scanHostColumn
                            width: parent.width
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

                                            // Port range and Scan in one row (default: the whole range 1-65535)
                                            Row {
                                                spacing: 8
                                                Controls.TextField {
                                                    id: rangeField
                                                    width: 132
                                                    text: hostRow.prange
                                                    placeholderText: "e.g. 8000-9000"
                                                    font.pixelSize: 11
                                                    selectByMouse: true
                                                    onEditingFinished: root.setPortRange(hostRow.ipKey, text.trim())
                                                    onAccepted: { root.setPortRange(hostRow.ipKey, text.trim()); root.runPortScan(hostRow.ipKey) }
                                                }
                                                Controls.Button {
                                                    width: 108
                                                    height: rangeField.height
                                                    text: hostRow.pstate === "running" ? "Scanning\u2026" : "Scan ports"
                                                    enabled: root.portScanIp === ""
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
                                                        running: hostRow.pstate === "running"
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

                ColumnLayout {
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
                            // the style's own scroll bar width: Breeze's is wider than 10 px and covered the values
                            width: parent.width - diagScroll.width - 4
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
                                        DiagIcon { x: 2; y: 2; size: 18; status: diagStep.step.status }
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

                ColumnLayout {
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

                ColumnLayout {
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
                            : "Counted while Plasma runs (from login), updated every 2 minutes" + (root.appUsageUpdated !== "" ? ", last at " + root.appUsageUpdated : "")
                              + ". \"now\" is a 3-second sample. Source: KDE System Monitor helper."
                        color: root.themeSecondary
                        font.pixelSize: 9
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Controls.Button {
                        text: root.appTrafficLoading ? "Reading…" : "Refresh"
                        enabled: !root.appTrafficLoading
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        onClicked: root.refreshAppTraffic()
                    }
                }

                ColumnLayout {
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
                                var normalized = text.replace(/,/g, ".")
                                if (normalized !== text) text = normalized
                            }
                        }
                        Controls.Button {
                            text: "Add"
                            enabled: monitorIpField.text.trim() !== ""
                            onClicked: { root.addWatchedDevice(monitorIpField.text, "—"); monitorIpField.clear() }
                        }
                    }
                    Text {
                        text: root.watchedDevices.length ? "Status is checked every 30 seconds." : "Add an IP or use Watch from Network Scanner."
                        color: root.themeSecondary
                        font.pixelSize: 10
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
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
            }
        }
    }


}
