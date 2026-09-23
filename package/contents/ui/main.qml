import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt.labs.settings
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
    property bool diagnosticsLoading: false
    property bool speedLoading: false
    property bool appTrafficLoading: false
    property var appTraffic: []
    property var appExpanded: ({})
    property string appTrafficStatus: "Ready"
    property string appRatesState: ""
    property bool dependenciesLoading: false
    property string missingDependencies: ""
    property string installCommand: ""
    property string scanCidr: ""
    property bool scanCidrUserEdited: false
    property bool scanLoading: false
    property string scanStatus: ""
    property var scanHosts: []
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

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    property color themeBackground: themeBackgroundRaw
    property color themeText: contrastText(themeBackgroundRaw, themeTextRaw)
    property color themeLink: contrastText(themeBackgroundRaw, themeLinkRaw)
    property color themeSecondary: contrastText(themeBackgroundRaw, themeSecondaryRaw)
    property color themePositive: contrastText(themeBackgroundRaw, themePositiveRaw)
    property color themeNegative: contrastText(themeBackgroundRaw, themeNegativeRaw)
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
    property var localItems: []
    property var gatewayMap: ({})
    property var dnsMap: ({})

    property string internetStatus: "—"
    property string gatewayStatus: "—"
    property string dnsStatus: "—"
    property string ipv4Status: "—"
    property string ipv6Status: "—"
    property string latency: "—"
    property string networkUpdated: "—"
    property string internetQuality: "unknown"
    property bool vpnActive: false
    property int networkChecksDone: 0
    property string diagnosticsText: ""
    property string speedDownload: "—"
    property string speedUpload: "—"
    property string speedLatency: "—"
    property string speedStatus: "Ready"
    property string speedUpdated: "—"
    property string trafficReceived: "—"
    property string trafficSent: "—"
    property string trafficUpdated: "—"
    property var ipHistory: []
    property string diagnosticsSummary: ""

    Settings {
        id: appSettings
        property string watchedDevicesJson: "[]"
        property string ipHistoryJson: "[]"
    }

    Plasmoid.icon: "/icon.png"

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

    function updateScanDefault() {
        var item = activeInterface()
        if (!item || !item.ipv4.length || !item.ipv4Prefix.length) return
        var cidr = ipv4Network(item.ipv4[0], item.ipv4Prefix[0])
        if (cidr && !root.scanCidrUserEdited) root.scanCidr = cidr
    }

    function checkDependencies() {
        if (dependenciesLoading) return
        dependenciesLoading = true
        dependencyApi.connectSource("sh -c 'command -v curl >/dev/null 2>&1 || echo curl; command -v ip >/dev/null 2>&1 || echo iproute2; command -v ping >/dev/null 2>&1 || echo iputils-ping; command -v resolvectl >/dev/null 2>&1 || echo systemd-resolved; command -v nmap >/dev/null 2>&1 || echo nmap; command -v notify-send >/dev/null 2>&1 || echo libnotify-bin'")
    }

    function runNetworkScan() {
        if (scanLoading || !scanCidr) return
        scanLoading = true
        scanStatus = "Scanning…"
        scanHosts = []
        var safeCidr = scanCidr.replace(/[^0-9a-fA-F:./]/g, "")
        scanApi.connectSource("sh -c 'echo __LO__; ip -4 -o addr show dev lo 2>/dev/null | tr -s \" \" | cut -d\" \" -f4; echo __NEIGH__; nmap -sn -PR -n --host-timeout 2s " + safeCidr + " 2>/dev/null; echo __NEIGH2__; ip neigh show'")
    }

    function saveWatchedDevices() {
        appSettings.watchedDevicesJson = JSON.stringify(root.watchedDevices)
    }

    function saveIpHistory() {
        appSettings.ipHistoryJson = JSON.stringify(root.ipHistory)
    }

    function loadIpHistory() {
        try {
            var parsed = JSON.parse(appSettings.ipHistoryJson || "[]")
            root.ipHistory = Array.isArray(parsed) ? parsed.slice(0, 30) : []
        } catch (e) {
            root.ipHistory = []
        }
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
        var command = "sh -c 'for ip in " + ips.join(" ") + "; do if ping -c 1 -W 1 \"$ip\" >/dev/null 2>&1; then printf \"%s\\tUP\\n\" \"$ip\"; else printf \"%s\\tDOWN\\n\" \"$ip\"; fi; done'"
        monitorApi.connectSource(command)
    }

    function refreshAll() {
        uptimeApi.disconnectSource("cut -d' ' -f1 /proc/uptime")
        uptimeApi.connectSource("cut -d' ' -f1 /proc/uptime")
        if (!loading) {
            loading = true
            publicApi.connectSource("curl -4 -fsSL --max-time 12 'https://ipwho.is/?lang=en'")
        }
        if (!localLoading) {
            localLoading = true
            localApi.connectSource("ip -j addr show")
            routeApi.connectSource("ip -j route show default")
            dnsApi.connectSource("resolvectl --no-pager dns")
        }
        refreshNetwork()
    }

    function refreshNetwork() {
        if (networkLoading) return
        networkLoading = true
        networkChecksDone = 0
        gatewayCheckApi.connectSource("sh -c 'gw=$(ip route show default | awk '\''/default/ {print $3; exit}'\''); if [ -n \"$gw\" ]; then ping -4 -c 1 -W 1 \"$gw\" >/dev/null 2>&1 && echo OK || echo FAIL; else echo NONE; fi'")
        dnsCheckApi.connectSource("getent hosts example.com >/dev/null 2>&1 && echo OK || echo FAIL")
        internetCheckApi.connectSource("sh -c 'nm_conn=$(nmcli -t -f CONNECTIVITY networking connectivity check 2>/dev/null | head -n 1); has_route=0; ip -4 route show default 2>/dev/null | grep -q . && has_route=1; ip -6 route show default 2>/dev/null | grep -q . && has_route=1; if [ \"$has_route\" -eq 0 ] && [ \"$nm_conn\" != \"full\" ]; then echo OFFLINE; exit; fi; t=\"\"; for url in \"https://www.google.com/generate_204\" \"https://www.gstatic.com/generate_204\" \"https://www.msftconnecttest.com/connecttest.txt\" \"https://www.cloudflare.com/cdn-cgi/trace\"; do x=$(curl -fsS --connect-timeout 3 --max-time 5 -o /dev/null -w \"%{time_total}\" \"$url\" 2>/dev/null); if [ -n \"$x\" ]; then t=\"$x\"; break; fi; done; if [ -z \"$t\" ] && [ \"$nm_conn\" != \"full\" ]; then echo OFFLINE; exit; fi; vpn=0; if command -v nmcli >/dev/null 2>&1; then while IFS=: read -r dev type; do case \"$type\" in vpn|ovpn|wireguard|tun|tap|ppp|ipsec|l2tp) if [ -n \"$dev\" ] && [ \"$(cat /sys/class/net/$dev/operstate 2>/dev/null)\" = \"up\" ] && ip -br addr show dev \"$dev\" 2>/dev/null | grep -Eq \"[[:space:]][0-9A-Fa-f:.]+/[0-9]+\"; then vpn=1; break; fi ;; esac; done <<EOF\n$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null)\nEOF\nfi; if [ \"$vpn\" -eq 1 ]; then echo \"VPN $t\"; else echo \"ONLINE $t\"; fi'")
        ipv4CheckApi.connectSource("ip -4 route get 1.1.1.1 >/dev/null 2>&1 && echo OK || echo FAIL")
        ipv6CheckApi.connectSource("sh -c 'curl -6 -fsS --max-time 5 -o /dev/null https://www.cloudflare.com && echo OK || echo FAIL'")
    }

    function networkCheckDone() {
        networkChecksDone += 1
        if (networkChecksDone >= 5) {
            networkLoading = false
            networkUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
        }
    }

    function runDiagnostics() {
        if (diagnosticsLoading) return
        diagnosticsLoading = true
        diagnosticsApi.connectSource("sh -c 'iface=$(ip route show default | sed -n \"1s/.*dev \\([^ ]*\\).*/\\1/p\"); gw=$(ip route show default | sed -n \"1s/default via \\([^ ]*\\).*/\\1/p\"); echo Interface: ${iface:-NONE}; echo Gateway: ${gw:-NONE}; if getent hosts example.com >/dev/null 2>&1; then echo DNS: OK; else echo DNS: FAIL; fi; if curl -4 -fsS --max-time 5 -o /dev/null https://www.google.com/generate_204 >/dev/null 2>&1; then echo Internet: OK; else echo Internet: FAIL; fi; if ip -4 route get 1.1.1.1 >/dev/null 2>&1; then echo IPv4: OK; else echo IPv4: FAIL; fi; if curl -6 -fsS --max-time 5 -o /dev/null https://www.google.com >/dev/null 2>&1; then echo IPv6: OK; else echo IPv6: UNAVAILABLE; fi; vpn=INACTIVE; for dev in $(ip -o link show | cut -d: -f2 | cut -d@ -f1); do case \"$dev\" in tun*|tap*|ppp*|wg*|warp*) if [ \"$(cat /sys/class/net/$dev/operstate 2>/dev/null)\" = \"up\" ] && ip -br addr show dev \"$dev\" 2>/dev/null | grep -Eq \"[[:space:]][0-9A-Fa-f:.]+/[0-9]+\"; then vpn=ACTIVE; break; fi ;; esac; done; echo VPN: $vpn; curl -4 -fsS --max-time 5 -o /dev/null -w \"Latency: %{time_total}s\n\" https://www.google.com/generate_204 2>/dev/null || echo Latency: UNAVAILABLE;'")
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
            return (Number(a.port) || 0) - (Number(b.port) || 0)
        }
        for (var r = 0; r < rows.length; ++r) {
            rows[r].connections = rows[r].connections.sort(byEndpoint).slice(0, 30)
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

    function appDisplayName(name) {
        var n = String(name || "").trim()
        if (n === "chrome") return "Chromium"
        if (n === "telegram-deskto") return "Telegram Desktop"
        if (n === "warp-taskbar") return "Cloudflare WARP"
        if (n === "syncthing") return "Syncthing"
        if (n === "wechat") return "WeChat"
        return n || "Unknown"
    }

    function runSpeedTest() {
        if (speedLoading) return
        speedLoading = true
        speedStatus = "Testing…"
        speedApi.connectSource("sh -c 'curl -4 -fsS -o /dev/null -w \"LATENCY %{time_total}\n\" --max-time 10 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null; curl -4 -L -fsS -o /dev/null -w \"DOWNLOAD %{speed_download}\n\" --max-time 25 https://speed.cloudflare.com/__down?bytes=25000000 2>/dev/null; dd if=/dev/zero bs=1M count=10 2>/dev/null | curl -4 -fsS -o /dev/null -w \"UPLOAD %{speed_upload}\n\" --max-time 25 -X POST --data-binary @- https://speed.cloudflare.com/__up 2>/dev/null'")
    }

    function formatMbps(bytesPerSecond) {
        var n = Number(bytesPerSecond)
        if (!isFinite(n) || n <= 0) return "—"
        return (n * 8 / 1000000).toFixed(1) + " Mbps"
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
            try {
                var d = JSON.parse(data.stdout || "")
                if (!d.success) { root.errorText = "API error: " + (d.message || "unknown"); return }
                root.errorText = ""
                var oldIp = root.publicIp
                root.publicIp = d.ip || "—"; root.country = d.country || "—"; root.countryCode = d.country_code || ""
                root.city = d.city || "—"; root.region = d.region || "—"
                root.latitude = d.latitude !== undefined ? Number(d.latitude).toFixed(5) : "—"
                root.longitude = d.longitude !== undefined ? Number(d.longitude).toFixed(5) : "—"
                root.provider = d.connection && d.connection.isp ? d.connection.isp : "—"
                root.asn = d.connection && d.connection.asn ? "AS" + d.connection.asn : "—"
                root.timezone = d.timezone && d.timezone.id ? d.timezone.id : "—"
                root.updated = Qt.formatTime(new Date(), "HH:mm:ss")
                if (root.publicIp !== "—" && root.publicIp !== oldIp) {
                    var h = root.ipHistory.slice(0)
                    if (h.length === 0 || h[0].ip !== root.publicIp) {
                        h.unshift({ip: root.publicIp, time: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")})
                        if (h.length > 30) h.pop()
                        root.ipHistory = h
                        root.saveIpHistory()
                    }
                }
            } catch (e) { root.errorText = "API error: invalid response" }
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

    Plasma5Support.DataSource { id: gatewayCheckApi; engine:"executable"; onNewData:function(source,data){gatewayCheckApi.disconnectSource(source);root.gatewayStatus=String(data.stdout||"").trim();root.networkCheckDone()} }
    Plasma5Support.DataSource { id: dnsCheckApi; engine:"executable"; onNewData:function(source,data){dnsCheckApi.disconnectSource(source);root.dnsStatus=String(data.stdout||"").trim();root.networkCheckDone()} }
    Plasma5Support.DataSource { id: internetCheckApi; engine:"executable"; onNewData:function(source,data){internetCheckApi.disconnectSource(source);var out=String(data.stdout||"").trim();var parts=out.split(/\s+/);var state=parts.length?parts[0]:"OFFLINE";var t=parts.length>1?parseFloat(parts[1]):NaN;root.internetStatus=state==="VPN"||state==="ONLINE"?"Online":"Offline";root.internetQuality=state==="ONLINE"||state==="VPN"?"online":"offline";root.vpnActive=state==="VPN";if(isFinite(t))root.latency=Math.round(t*1000)+" ms";root.networkUpdated=Qt.formatTime(new Date(),"HH:mm:ss");root.networkCheckDone()} }
    Plasma5Support.DataSource { id: ipv4CheckApi; engine:"executable"; onNewData:function(source,data){ipv4CheckApi.disconnectSource(source);root.ipv4Status=String(data.stdout||"").trim();root.networkCheckDone()} }
    Plasma5Support.DataSource { id: ipv6CheckApi; engine:"executable"; onNewData:function(source,data){ipv6CheckApi.disconnectSource(source);root.ipv6Status=String(data.stdout||"").trim();if(root.ipv6Status==="FAIL")root.ipv6Status="UNAVAILABLE";root.networkCheckDone()} }
    Plasma5Support.DataSource { id: diagnosticsApi; engine:"executable"; onNewData:function(source,data){diagnosticsApi.disconnectSource(source);root.diagnosticsText=String(data.stdout||"").trim();root.diagnosticsLoading=false} }
    Plasma5Support.DataSource { id: latencyApi; engine:"executable"; onNewData:function(source,data){latencyApi.disconnectSource(source);var s=String(data.stdout||"").trim();if(s)root.latency=s} }
    Plasma5Support.DataSource { id: speedApi; engine:"executable"; onNewData:function(source,data){speedApi.disconnectSource(source);var lines=String(data.stdout||"").trim().split("\n");var ok=false;var errors=0;for(var i=0;i<lines.length;++i){var line=lines[i].trim();if(line.indexOf("LATENCY ")===0){var lv=Number(line.substring(8))*1000;if(isFinite(lv)&&lv>0){root.speedLatency=Math.round(lv)+" ms";ok=true}else{errors++}}else if(line.indexOf("DOWNLOAD ")===0){var dv=line.substring(9);if(Number(dv)>0){root.speedDownload=root.formatMbps(dv);ok=true}else{errors++}}else if(line.indexOf("UPLOAD ")===0){var uv=line.substring(7);if(Number(uv)>0){root.speedUpload=root.formatMbps(uv);ok=true}else{errors++}}else if(line.indexOf("_ERROR")!==-1){errors++}}root.speedLoading=false;root.speedUpdated=Qt.formatTime(new Date(),"HH:mm:ss");root.speedStatus=ok?(errors?"Completed with limited results":"Test completed"):"Test failed"} }
    Plasma5Support.DataSource { id: trafficApi; engine:"executable"; onNewData:function(source,data){trafficApi.disconnectSource(source);var p=String(data.stdout||"").trim().split(/\s+/);if(p.length>=2){root.trafficReceived=root.formatBytes(p[0]);root.trafficSent=root.formatBytes(p[1]);root.trafficUpdated=Qt.formatTime(new Date(),"HH:mm:ss")}} }
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
        for (var r = 0; r < rows.length; ++r) {
            var rate = rates.rates[rows[r].pid]
            rows[r].rx = rates.state === "ok" ? (rate ? rate.rx : 0) : -1
            rows[r].tx = rates.state === "ok" ? (rate ? rate.tx : 0) : -1
        }
        var shown = rows.slice(0, 12)
        var present = {}
        for (var i = 0; i < shown.length; ++i) present[shown[i].process + "|" + shown[i].pid] = true
        var kept = {}
        var pruned = false
        for (var k in root.appExpanded) {
            if (!root.appExpanded.hasOwnProperty(k)) continue
            if (present[k]) kept[k] = true
            else pruned = true
        }
        if (pruned) root.appExpanded = kept
        // Replace the model in one step, and only when the data really changed
        if (JSON.stringify(shown) !== JSON.stringify(root.appTraffic)) root.appTraffic = shown
        root.appTrafficStatus = rows.length ? (rows.length + " active app" + (rows.length === 1 ? "" : "s") + " · " + Qt.formatTime(new Date(), "HH:mm:ss")) : "No active connections"
        root.appTrafficLoading = false
    } }
    Plasma5Support.DataSource { id: dependencyApi; engine:"executable"; onNewData:function(source,data){dependencyApi.disconnectSource(source);var out=String(data.stdout||"").trim();root.missingDependencies=out.replace(/^\s+|\s+$/g,"").replace(/\n+/g," ");var pkgs=root.missingDependencies.trim().split(/\s+/).filter(function(x){return x});root.installCommand=pkgs.length?"sudo apt install "+pkgs.join(" "):"";root.dependenciesLoading=false} }
    Plasma5Support.DataSource { id: scanApi; engine:"executable"; onNewData:function(source,data){scanApi.disconnectSource(source);var lines=String(data.stdout||"").split("\n");var hosts=[];var neighbors={};var loIps={};var currentIp="";var currentMac="—";var inLo=false;var inNeighbors=false;function pushCurrent(){if(currentIp&&!loIps[currentIp])hosts.push({ip:currentIp,mac:currentMac||"—"})}for(var i=0;i<lines.length;++i){var line=lines[i].trim();if(line==="__LO__"){inLo=true;inNeighbors=false;continue}if(line==="__NEIGH__"){inLo=false;inNeighbors=false;continue}if(line==="__NEIGH2__"){pushCurrent();currentIp="";currentMac="—";inLo=false;inNeighbors=true;continue}if(inLo){var lm=line.match(/^([0-9A-Fa-f:.]+)\/\d+$/);if(lm)loIps[lm[1]]=true;continue}if(inNeighbors){var nm=line.match(/^([0-9A-Fa-f:.]+)\s+dev\s+\S+\s+lladdr\s+([0-9A-Fa-f:]{17})/);if(nm)neighbors[nm[1]]=nm[2].toUpperCase();continue}var m=line.match(/^Nmap scan report for (.+)$/);if(m){pushCurrent();var report=m[1].trim();var ipMatch=report.match(/\(([0-9A-Fa-f:.]+)\)$/);currentIp=ipMatch?ipMatch[1]:report;currentMac="—";continue}var mm=line.match(/^MAC Address:\s+([0-9A-Fa-f:]{17})/);if(mm)currentMac=mm[1].toUpperCase()}pushCurrent();for(var h=0;h<hosts.length;++h){if((!hosts[h].mac||hosts[h].mac==="—")&&neighbors[hosts[h].ip])hosts[h].mac=neighbors[hosts[h].ip]}root.scanHosts=hosts;root.scanStatus=hosts.length?(hosts.length+" active host"+(hosts.length===1?"":"s")):"No active hosts found";root.scanLoading=false} }
    Plasma5Support.DataSource { id: monitorApi; engine:"executable"; onNewData:function(source,data){
        monitorApi.disconnectSource(source)
        var lines=String(data.stdout||"").split("\n")
        var states={}
        for(var i=0;i<lines.length;++i){
            var line=lines[i].trim(); if(!line) continue
            var parts=line.split("\t"); if(parts.length<2) continue
            states[parts[0]]=parts[1]
        }
        var list=root.watchedDevices.slice(0)
        for(var j=0;j<list.length;++j){
            var item=list[j]; var next=states[item.ip]||"DOWN"; var old=item.status||"Unknown"
            item.status=next; item.lastCheck=Qt.formatTime(new Date(),"HH:mm:ss")
            if(old!=="Unknown" && old!==next){
                var title="Network device status changed"
                var body=item.ip+" is now "+(next==="UP"?"online":"offline")
                monitorNotifyApi.connectSource("notify-send -a 'My IP & Geo' -u normal '"+title+"' '"+body.replace(/'/g," ")+"'")
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
        function onVisibleChanged() { root.refreshAppTraffic() }
    }
    Timer { interval:600000
 repeat:true
 running:true
 onTriggered: { if(!root.loading&&!root.localLoading)root.refreshAll(); root.monitorWatchedDevices() } }
    Timer { interval:30000
 repeat:true
 running:true
 onTriggered:{ root.refreshNetwork(); root.monitorWatchedDevices() } }
    Component.onCompleted: { root.loadWatchedDevices(); root.loadIpHistory(); root.refreshAll(); root.refreshTraffic(); root.refreshAppTraffic(); root.checkDependencies(); root.monitorWatchedDevices() }

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
                            text: root.errorText !== "" ? root.errorText : "Updated: " + root.updated + " · Auto-refresh: 10 min"
                            color: root.errorText !== "" ? root.themeNegative : root.themeSecondary
                            font.pixelSize: 9
                        }
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
                                        width: localTable.width
                                        height: Math.max(72, Math.max(localLeftColumn.implicitHeight, localRightColumn.implicitHeight) + 20)
                                        radius: 9
                                        color: root.alpha(root.themeText, 0.045)
                                        border.width: 1
                                        border.color: root.alpha(root.themeText, 0.16)
                                        clip: true

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 10
                                            anchors.bottomMargin: 10
                                            spacing: 12

                                            Column {
                                                id: localLeftColumn
                                                width: parent.width * 0.38
                                                spacing: 3

                                                TextEdit {
                                                    width: parent.width
                                                    text: modelData.iface
                                                    color: root.themeText
                                                    font.bold: true
                                                    font.pixelSize: 12
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                                Text {
                                                    text: (modelData.ipv4.length && modelData.ipv6.length) ? "IPv4 + IPv6" : (modelData.ipv4.length ? "IPv4" : "IPv6")
                                                    color: root.themeSecondary
                                                    font.pixelSize: 9
                                                }
                                                TextEdit {
                                                    width: parent.width
                                                    text: "MAC: " + (modelData.mac || "—")
                                                    color: root.themeSecondary
                                                    font.pixelSize: 9
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                            }

                                            Column {
                                                id: localRightColumn
                                                width: parent.width * 0.62 - 12
                                                spacing: 2

                                                TextEdit {
                                                    width: parent.width
                                                    text: "IPv4: " + (modelData.ipv4.length ? modelData.ipv4.map(function(v,k) { return v + " /" + modelData.ipv4Prefix[k] + " · " + root.maskFor(modelData.ipv4Prefix[k], "IPv4") }).join(", ") : "—")
                                                    color: root.themeText
                                                    font.pixelSize: 10
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                                TextEdit {
                                                    width: parent.width
                                                    text: "IPv6: " + (modelData.ipv6.length ? modelData.ipv6.map(function(v,k) { return v + " /" + modelData.ipv6Prefix[k] }).join(", ") : "—")
                                                    color: root.themeText
                                                    font.pixelSize: 10
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                                TextEdit {
                                                    width: parent.width
                                                    text: "Gateway: " + root.gatewayFor(modelData.iface)
                                                    color: root.themeText
                                                    font.pixelSize: 10
                                                    readOnly: true
                                                    selectByMouse: true
                                                    selectByKeyboard: true
                                                    cursorVisible: false
                                                    wrapMode: TextEdit.Wrap
                                                }
                                                TextEdit {
                                                    width: parent.width
                                                    text: "DNS: " + root.dnsFor(modelData.iface)
                                                    color: root.themeText
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
                                font.pixelSize: 9
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                        }
                        TextEdit {
                            visible: root.installCommand !== ""
                            Layout.fillWidth: true
                            text: root.installCommand
                            color: root.themeNegative
                            font.pixelSize: 9
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
                            Text { text: "Received"; color: root.themeSecondary; font.pixelSize: 8 }
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
                            Text { text: "Sent"; color: root.themeSecondary; font.pixelSize: 8 }
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
                            Text { text: "· v6.1.36"; color: root.themeSecondary; font.pixelSize: 9 }
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
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, 470)
        height: Math.min(parent.height - 24, 560)
        radius: 14
        z: 100
        color: root.alpha(root.themeBackground, .99)
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
                    onClicked: root.toolsTab = 1
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 1 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 1 ? root.themeHighlight : root.alpha(root.themeText, .10)
                    }
                    contentItem: Text { text: parent.text; color: root.themeText; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Controls.Button {
                    text: "IP History"
                    Layout.fillWidth: true
                    onClicked: root.toolsTab = 2
                    background: Rectangle {
                        radius: 5
                        color: root.toolsTab === 2 ? root.alpha(root.themeHighlight, .16) : root.alpha(root.themeBackground, .80)
                        border.width: 1
                        border.color: root.toolsTab === 2 ? root.themeHighlight : root.alpha(root.themeText, .10)
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

                    Text {
                        text: root.scanCidr !== "" ? "Default network: " + root.scanCidr : "Network will be detected from Local IPs"
                        color: root.themeSecondary
                        font.pixelSize: 9
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
                            placeholderText: "Network / CIDR"
                            font.pixelSize: 10
                            selectByMouse: true
                            onEditingFinished: {
                                root.scanCidr = text.trim()
                                root.scanCidrUserEdited = true
                            }
                        }
                        Controls.Button {
                            text: root.scanLoading ? "…" : "Scan"
                            enabled: !root.scanLoading && root.scanCidr !== "" && root.missingDependencies.indexOf("nmap") === -1
                            onClicked: root.runNetworkScan()
                        }
                    }
                    RowLayout {
                        visible: root.missingDependencies !== ""
                        Layout.fillWidth: true
                        spacing: 5
                        Text {
                            text: "Missing: " + root.missingDependencies
                            color: root.themeNegative
                            font.pixelSize: 9
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
                        font.pixelSize: 9
                        readOnly: true
                        selectByMouse: true
                        selectByKeyboard: true
                        cursorVisible: false
                        wrapMode: TextEdit.Wrap
                        Layout.preferredHeight: Math.max(18, contentHeight)
                    }
                    Text {
                        visible: root.scanStatus !== ""
                        text: root.scanStatus
                        color: root.themeSecondary
                        font.pixelSize: 9
                        Layout.fillWidth: true
                    }

                    // Scanner results use a fixed three-column grid so the
                    // headers and every cell stay aligned. Status is shown
                    // by the dot next to the IP; there is no separate status column.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: root.alpha(root.themeText, .035)
                        border.width: 1
                        border.color: root.alpha(root.themeText, .12)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 5
                            spacing: 6

                            Text {
                                Layout.preferredWidth: 145
                                text: "IP address"
                                color: root.themeText
                                font.pixelSize: 9
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                Layout.preferredWidth: 150
                                text: "MAC address"
                                color: root.themeText
                                font.pixelSize: 9
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Action"
                                color: root.themeText
                                font.pixelSize: 9
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
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
                            spacing: 2

                            Repeater {
                                model: root.scanHosts
                                delegate: Rectangle {
                                    width: scanHostColumn.width
                                    height: 32
                                    radius: 4
                                    color: root.alpha(root.themePositive, .055)
                                    border.width: 1
                                    border.color: root.alpha(root.themeText, .10)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 5
                                        spacing: 6

                                        RowLayout {
                                            Layout.preferredWidth: 145
                                            spacing: 6

                                            Rectangle {
                                                Layout.preferredWidth: 8
                                                Layout.preferredHeight: 8
                                                radius: 4
                                                color: root.themePositive
                                            }

                                            TextEdit {
                                                Layout.fillWidth: true
                                                text: modelData.ip
                                                color: root.themeText
                                                font.pixelSize: 10
                                                verticalAlignment: Text.AlignVCenter
                                                readOnly: true
                                                selectByMouse: true
                                                selectByKeyboard: true
                                                cursorVisible: false
                                            }
                                        }

                                        TextEdit {
                                            Layout.preferredWidth: 150
                                            text: modelData.mac
                                            color: root.themeSecondary
                                            font.pixelSize: 9
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: true
                                            selectByMouse: true
                                            selectByKeyboard: true
                                            cursorVisible: false
                                        }

                                        Controls.Button {
                                            text: {
                                                var watching = false
                                                for (var wi = 0; wi < root.watchedDevices.length; ++wi) {
                                                    if (root.watchedDevices[wi].ip === modelData.ip) { watching = true; break }
                                                }
                                                return watching ? "−" : "+"
                                            }
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 26
                                            onClicked: root.toggleWatchedDevice(modelData.ip, modelData.mac)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6
                    visible: root.toolsTab === 1
                    Controls.Button {
                        text: root.diagnosticsLoading ? "Running…" : "Run diagnostics"
                        enabled: !root.diagnosticsLoading
                        Layout.fillWidth: true
                        onClicked: root.runDiagnostics()
                    }
                    Controls.Button {
                        text: "Refresh network"
                        enabled: !root.networkLoading
                        Layout.fillWidth: true
                        onClicked: root.refreshNetwork()
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: diagnosticsTextItem.contentHeight
                        interactive: contentHeight > height
                        TextEdit {
                            id: diagnosticsTextItem
                            width: parent.width
                            text: root.diagnosticsText !== "" ? root.diagnosticsText : "No diagnostics run yet."
                            color: root.themeText
                            font.pixelSize: 10
                            readOnly: true
                            selectByMouse: true
                            selectByKeyboard: true
                            cursorVisible: false
                            wrapMode: TextEdit.Wrap
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6
                    visible: root.toolsTab === 2
                    Text {
                        text: root.ipHistory.length ? "Recent public IP addresses" : "No IP changes recorded yet."
                        color: root.themeSecondary
                        font.pixelSize: 9
                        Layout.fillWidth: true
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: historyColumn.height
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: historyColumn
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: root.ipHistory
                                delegate: Rectangle {
                                    width: historyColumn.width
                                    height: 34
                                    radius: 6
                                    color: root.alpha(root.themeText, .045)
                                    border.width: 1
                                    border.color: root.alpha(root.themeText, .08)
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        TextEdit {
                                            text: modelData.ip
                                            color: root.themeText
                                            font.pixelSize: 10
                                            readOnly: true
                                            selectByMouse: true
                                            selectByKeyboard: true
                                            cursorVisible: false
                                            Layout.fillWidth: true
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        Text {
                                            text: modelData.time
                                            color: root.themeSecondary
                                            font.pixelSize: 8
                                            Layout.preferredWidth: 110
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.toolsTab === 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Network Speed"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                        Text { text: root.speedStatus; color: root.speedLoading ? root.themeHighlight : root.themeSecondary; font.pixelSize: 9 }
                    }
                    Text { text: "Cloudflare network test"; color: root.themeSecondary; font.pixelSize: 9; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 88; radius: 10
                            color: root.alpha(root.themeText, .045); border.width: 1; border.color: root.alpha(root.themeText, .09)
                            ColumnLayout { anchors.centerIn: parent; spacing: 2
                                Text { text: "↓"; color: root.themeHighlight; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                Text { text: root.speedDownload === "—" ? "—" : root.speedDownload.replace(" Mbps", ""); color: root.themeText; font.pixelSize: 20; font.bold: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                Text { text: "Mbps  ·  Download"; color: root.themeSecondary; font.pixelSize: 8; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 88; radius: 10
                            color: root.alpha(root.themeText, .045); border.width: 1; border.color: root.alpha(root.themeText, .09)
                            ColumnLayout { anchors.centerIn: parent; spacing: 2
                                Text { text: "↑"; color: root.themeHighlight; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                Text { text: root.speedUpload === "—" ? "—" : root.speedUpload.replace(" Mbps", ""); color: root.themeText; font.pixelSize: 20; font.bold: true; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                Text { text: "Mbps  ·  Upload"; color: root.themeSecondary; font.pixelSize: 8; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 58; radius: 10
                        color: root.alpha(root.themeText, .035); border.width: 1; border.color: root.alpha(root.themeText, .08)
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            Text { text: "◉"; color: root.themeHighlight; font.pixelSize: 16 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 0
                                Text { text: "Latency"; color: root.themeSecondary; font.pixelSize: 8 }
                                Text { text: root.speedLatency; color: root.themeText; font.pixelSize: 16; font.bold: true }
                            }
                            Text { text: root.speedUpdated === "—" ? "" : root.speedUpdated; color: root.themeSecondary; font.pixelSize: 8 }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Controls.Button {
                        text: root.speedLoading ? "Testing…" : "Run speed test"
                        enabled: !root.speedLoading
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        onClicked: root.runSpeedTest()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 7
                    visible: root.toolsTab === 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Network Apps"; color: root.themeText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                        Text { text: root.appTrafficLoading ? "Reading…" : root.appTrafficStatus; color: root.appTrafficLoading ? root.themeHighlight : root.themeSecondary; font.pixelSize: 8 }
                    }
                    Text {
                        text: "Applications with active network connections · TCP and UDP"
                        color: root.themeSecondary
                        font.pixelSize: 9
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: root.alpha(root.themeText, .035)
                        border.width: 1
                        border.color: root.alpha(root.themeText, .08)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: "Application"; color: root.themeSecondary; font.pixelSize: 8; Layout.fillWidth: true }
                            Text { text: "TCP"; color: root.themeSecondary; font.pixelSize: 8; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                            Text { text: "UDP"; color: root.themeSecondary; font.pixelSize: 8; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                            Text { text: "Total"; color: root.themeSecondary; font.pixelSize: 8; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                        }
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: appTrafficColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: appTrafficColumn
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: root.appTraffic
                                delegate: Rectangle {
                                    id: appRow
                                    // Expanded state lives in root.appExpanded (key process|pid), so it survives model updates
                                    readonly property string appKey: modelData ? String(modelData.process) + "|" + String(modelData.pid) : ""
                                    readonly property bool expanded: root.appExpanded[appKey] === true
                                    width: appTrafficColumn.width
                                    height: appRowContent.implicitHeight + (expanded ? 6 : 0)
                                    radius: 6
                                    color: root.alpha(root.themeText, .045)
                                    border.width: 1
                                    border.color: root.alpha(root.themeText, .07)
                                    Column {
                                        id: appRowContent
                                        width: parent.width
                                        spacing: 4
                                        Item {
                                            width: parent.width
                                            height: 34
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.rightMargin: 8
                                                Text { text: appRow.expanded ? "⌄" : "›"; color: root.themeSecondary; font.pixelSize: 14; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: modelData.display; color: root.themeText; font.pixelSize: 9; elide: Text.ElideRight; Layout.fillWidth: true }
                                                    Row {
                                                        visible: modelData.rx >= 0
                                                        spacing: 3
                                                        Image { source: Qt.resolvedUrl("../images/arrow-down.svg"); sourceSize.width: 8; sourceSize.height: 10; anchors.verticalCenter: parent.verticalCenter }
                                                        Text { text: root.formatBytes(modelData.rx) + "/s"; color: root.themeText; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                                                        Item { width: 6; height: 1 }
                                                        Image { source: Qt.resolvedUrl("../images/arrow-up.svg"); sourceSize.width: 8; sourceSize.height: 10; anchors.verticalCenter: parent.verticalCenter }
                                                        Text { text: root.formatBytes(modelData.tx) + "/s"; color: root.themeText; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                                                    }
                                                }
                                                Text { text: "PID " + modelData.pid; color: root.themeSecondary; font.pixelSize: 8; Layout.preferredWidth: 62; horizontalAlignment: Text.AlignRight }
                                                Text { text: modelData.tcp; color: root.themeText; font.pixelSize: 8; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                                                Text { text: modelData.udp; color: root.themeText; font.pixelSize: 8; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
                                                Text { text: modelData.total; color: root.themeText; font.pixelSize: 8; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleAppExpanded(appRow.appKey)
                                            }
                                        }
                                        Rectangle { visible: appRow.expanded; width: parent.width - 16; x: 8; height: 1; color: root.alpha(root.themeText, .08) }
                                        Column {
                                            visible: appRow.expanded
                                            width: parent.width - 16
                                            x: 8
                                            spacing: 2
                                            Row {
                                                width: parent.width; height: 18
                                                Text { text: "Protocol"; color: root.themeSecondary; font.pixelSize: 7; width: 52 }
                                                Text { text: "Remote address"; color: root.themeSecondary; font.pixelSize: 7; width: parent.width - 52 - 72 - 86 }
                                                Text { text: "Port"; color: root.themeSecondary; font.pixelSize: 7; width: 72; horizontalAlignment: Text.AlignRight }
                                                Text { text: "Activity"; color: root.themeSecondary; font.pixelSize: 7; width: 86; horizontalAlignment: Text.AlignRight }
                                            }
                                            Repeater {
                                                model: modelData.connections
                                                delegate: Row {
                                                    width: parent.width; height: 22
                                                    Text { text: modelData.protocol; color: root.themeText; font.pixelSize: 8; width: 52 }
                                                    Text { text: modelData.address; color: root.themeText; font.pixelSize: 8; elide: Text.ElideMiddle; width: Math.max(70, parent.width - 52 - 72 - 86) }
                                                    Text { text: modelData.port; color: root.themeText; font.pixelSize: 8; width: 72; horizontalAlignment: Text.AlignRight }
                                                    Text { text: modelData.state; color: root.themePositive; font.pixelSize: 8; width: 86; horizontalAlignment: Text.AlignRight }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        text: root.appRatesState === "ok" ? "Traffic: average download/upload over 3 s from the KDE System Monitor helper. Connections: Linux socket information."
                            : root.appRatesState === "missing" ? "Traffic unavailable: KDE System Monitor helper (ksgrd_network_helper) not found."
                            : root.appRatesState === "failed" ? "Traffic unavailable: KDE System Monitor helper could not start packet capture."
                            : root.appRatesState === "nodata" ? "Traffic: no samples received from the KDE System Monitor helper."
                            : "Connections: Linux socket information. Traffic: KDE System Monitor helper."
                        color: root.themeSecondary
                        font.pixelSize: 8
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
                        font.pixelSize: 9
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
                                                text: (modelData.mac && modelData.mac !== "—" ? modelData.mac + " · " : "") + "checked " + modelData.lastCheck
                                                color: root.themeSecondary
                                                font.pixelSize: 8
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
