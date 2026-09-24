# My IP & Geo

Version 6.1.45

Compact KDE Plasma 6 widget for public IP/geolocation, local network information and network tools.

## Requirements
- KDE Plasma 6 (tested on Kubuntu 26.04). Nothing to install and no root rights: the widget uses `curl`, `ip`, `ping`, `ss` and standard shell tools, all present on Kubuntu by default.
- Used when present, never required: `iw` or NetworkManager (Wi-Fi details), `resolvectl` (DNS servers), `notify-send` (notifications, D-Bus is used otherwise), KDE System Monitor's `ksgrd_network_helper` (per-application traffic).

## v6.1.45
- Port scanner in the Network Scanner. Click a device in the scan results to open it, then scan its open TCP ports: "Common" (about 55 well-known service ports, a couple of seconds), "1–1024" (all well-known ports) or a custom range (e.g. 8000-9000, capped at 2048 ports). Open ports are shown as chips with the service name (22 ssh, 443 https, 8080 http-alt …), with a "N open · M checked" summary.
- No root, nmap, netcat or extra packages: it is a plain unprivileged TCP connect through bash's built-in /dev/tcp, run in parallel with a short per-port timeout. It only checks whether a port accepts a connection and sends no data. The host is validated as a bare IP address. Script: `contents/code/portscan.sh`.

## v6.1.44
- Local IPs redesigned for readability. Each address is on its own line instead of a single comma-separated line that wrapped (an interface with several networks — e.g. 10.0.8.15/21 plus three 192.168.x.15/24 — was one long block). The redundant duplicate prefix is gone: an address now reads "10.0.8.15/21" with the subnet mask "255.255.248.0" to the right, not "10.0.8.15 /21 · 255.255.248.0 (/21)".
- Each interface card has a header with the name and an "IPv4 / IPv6 / IPv4 + IPv6" badge, then the addresses grouped under an "IPv4" / "IPv6" label (with the count when there is more than one), then Gateway and DNS on their own labelled lines. Every value stays selectable for copying.

## v6.1.43
- Network Apps opens with the traffic leaders. One row per application: processes with the same name (three `curl`, Firefox's content processes, `warp-svc` + `warp-taskbar`) are one row with their speeds and connections added up; the expanded row lists the PIDs.
- Ranking by traffic in a period: Last hour, 24 hours (default) or Since boot; the choice is remembered. With equal traffic the application that is busy right now comes first, then the one that was active last. Each row shows its place, the total, a bar relative to the leader (blue received, red sent), ↓/↑ for the period and the current speed ("now", green) or the last activity ("last active 14:05"). Applications that are connected now but moved nothing in the period are listed below without a place ("No traffic in the last hour · last active 09:00"). A line above the list shows the period total and the number of applications. Up to 30 rows (was 20).
- Traffic is also kept per clock hour for the last 25 hours, so "Last hour" and "24 hours" survive Plasma restarts and reboots; "Since boot" starts from zero after a reboot as before. Hourly counting starts with this version: until a full period is counted, the line above the list says since when ("Last 24 hours (counted since 09:05)"). Activity means at least 2 KB in a 2-minute chunk, keep-alive packets do not count.

## v6.1.42
- A stretched widget uses its space: the Tools panel fills the whole widget (it was limited to 470×560 and the main view showed around it), the Public IP rows stay together at the top instead of spreading over the height, and the speed gauge is centred in a tall panel.
- VPN name: a plain tunnel is named after the VPN application that runs (RiseupVPN, CalyxVPN, Mullvad, NordVPN, ExpressVPN, Windscribe, Proton VPN, Amnezia VPN, OpenConnect …), for example "RiseupVPN · tun0".
- Websites: the same request also runs over IPv4 only. When the normal request connects much later, the time lost on failed IPv6 attempts is shown ("failed IPv6 attempts +200 ms") with a hint what to do.
- IPv6: only a global address counts as IPv6 from the network; a local-only (ULA) address is "Not provided" instead of a warning.
- DNS: the servers of the interface that carries the traffic (for example the VPN's own DNS) are listed first.
- Wi-Fi: the signal percentage is the one NetworkManager shows in the system tray; the live dBm value and the channel are shown next to it.
- Scanner and route: systemd-resolved's placeholder name `_gateway` is no longer shown as the router's name.

## v6.1.41
- VPN detection fixed for OpenVPN on current kernels: with data channel offload (the kernel `ovpn` driver) the interface is still called `tun0` but is not a tun device, so v6.1.40 showed "VPN Off" while RiseupVPN was connected. Any tunnel without a link layer is recognised now, and the interface that carries the internet traffic always counts. The VPN tile names the VPN (NetworkManager connection name, OpenVPN, WireGuard, Cloudflare WARP, Tailscale …). PPPoE as the only connection is not taken for a VPN. The header shield uses the same check.
- IPv6 behind a VPN: IPv6 blocked by the VPN is normal leak protection and shown as "Blocked by VPN" without a warning; IPv6 that leaves around the VPN is a warning ("IPv6 bypasses the VPN": websites can see the real address).
- Readability: secondary text is now close to the main text colour instead of the theme's dark grey; the smallest text grew from 7–8 px to 9 px, 9 px text to 10 px.
- Public IP: when ipwho.is does not answer, ipapi.co and then Cloudflare's trace page (address and country code) are used. The source is shown next to the update time; when every service fails, a plain message replaces "API error: invalid response" and the last data stays. Script: `contents/code/publicip.sh`.
- Local IPs: the loopback interface `lo` is no longer listed.
- Monitor: all devices are checked at the same time. A device that ignores ping but answers ARP (phones, Windows with a firewall) counts as online and is marked "ignores ping, answers ARP", so it no longer produces false "offline" notifications. Script: `contents/code/monitor.sh`.

## v6.1.40
- Diagnostics redesigned. It checks the whole chain — connection → router → DNS → internet → websites — and names the first broken link with a plain hint (for example "DNS does not work … Cloudflare DNS 1.1.1.1 works: set it as DNS server"), or shows "Everything works" with the connection quality (latency, jitter, packet loss). Warnings: weak Wi-Fi, packet loss, high or unstable latency, slow DNS, DNS answering for names that do not exist, broken IPv6, unsynchronized clock.
- Steps show real measurements. Connection: adapter, Wi-Fi network, band, signal (dBm and %), link rate, or Ethernet speed. Router: 5 pings and loss; a router that ignores ping but answers ARP counts as reachable. DNS: servers in use and the time of an uncached lookup; when DNS fails, DNS over HTTPS to 1.1.1.1 tells a DNS problem from a missing internet connection. Internet: 10 pings each to 1.1.1.1 and 8.8.8.8, TCP connect when ping is blocked. Websites: HTTPS request to Cloudflare with DNS, connect, TLS and reply times; a sign-in page (captive portal) is detected.
- Tiles: public IP (country, Cloudflare location, WARP), IPv6, VPN (name and whether internet traffic goes through it), path MTU. Route to 1.1.1.1: every router with its name and round-trip time.
- All checks run in parallel when the tab is opened (if the last run is older than 5 minutes) and with Run again; results appear as they arrive, about 2–3 s on a working network. Script: `contents/code/netdiag.sh`.
- Header indicators fixed. The internet dot turned red only without a default route: `curl -w` prints a time for failed requests too, so a dead internet behind a working router still showed green; now only a successful request counts. The VPN shield never lit for WireGuard, Cloudflare WARP or OpenVPN (tun): their interfaces report operstate `unknown`; now the UP/LOWER_UP flags plus an address decide.
- Less background work: every 30 s only the internet/VPN check runs. Before, a router ping, a DNS lookup, an IPv4 route check, an IPv6 request and a forced NetworkManager connectivity check ran too, and their results were not shown anywhere.
- No extra packages: settings moved from `Qt.labs.settings` (package qml6-module-qt-labs-settings, not installed on Kubuntu by default and deprecated) to `QtCore` Settings, which comes with Plasma; watched devices and app traffic totals are kept (same settings file). DNS servers in Local IPs come from resolvectl, NetworkManager or /etc/resolv.conf; Monitor notifications use notify-send or the desktop notification service over D-Bus (`contents/code/notify.sh`). The "Missing" hint lists only curl, iproute2 and iputils-ping.

## v6.1.39
- Network Apps: expanded details no longer repeat identical rows. Several connections to the same remote address and port (they differ only by the local port, which is not shown) are listed once with a blue `×N` after the address. TCP / UDP / Total still count every connection.

## v6.1.38
- Network Apps: every application shows its traffic since boot (↓ received / ↑ sent) next to the current speed. The KDE System Monitor helper runs in the background in back-to-back 2-minute chunks (the first one takes 20 s), totals are kept per application and saved with the boot id: they survive Plasma restarts and start from zero after a reboot. Counting starts when Plasma starts (at login); without root there is no way to see traffic from before that. Each restart of the helper misses one to two seconds, so totals can be 1–2% low. CPU cost measured at 100 Mbit/s: under 1% of one core.
- Network Apps: applications are ordered by traffic since boot; applications that used the network earlier but have no connections now are listed as "not connected" with their totals (up to 20 rows).
- Tools panel is fully opaque: at 99% the main view showed through, so text from the widget behind overlapped the Scanner list.
- IP History removed (tab, recording and the stored list).

## v6.1.37
- Network Scanner rebuilt, nmap is no longer needed. Every address is pinged once; to send the ping the kernel resolves the address with ARP, so devices that ignore ping (phones, Windows with a firewall) are found too. Cached ARP entries are re-checked, so devices that have left the network are not listed.
- Scanner rows show `Router` / `This device` and the reverse DNS name when the router provides one. Green dot: answers ping; amber dot: found via ARP only (Monitor uses ping and may show such a device offline).
- Previous scan results stay on screen until the new scan finishes; a progress bar runs during the scan (about 10 s for a /24). The default network comes from the Wi-Fi/Ethernet interface, not from a VPN tunnel; networks larger than /22 default to the /24 around this device; ranges up to 1024 addresses can be scanned.
- Speed Test redesigned: a gauge shows the live speed during the test, then Ping/Jitter, Download and Upload tiles and the Cloudflare server location.
- Speed Test method (Cloudflare endpoints, curl only): latency is the median time to first byte of 12 empty requests minus the server time from `Server-Timing`, jitter is the mean difference between consecutive samples; download uses 4 parallel streams for up to 8 s; upload uses 4 streams for up to 8 s and counts completed requests only.
- Scripts live in `contents/code/` (`netscan.sh`, `speedtest.sh`).

## v6.1.36
- Network Apps: each application shows its current download/upload speed (↓/↑) under its name.
- Speed is measured per process by KDE System Monitor's own helper `ksgrd_network_helper` (package `libksysguard-bin`, installed with Kubuntu's `plasma-systemmonitor`; the package itself grants it `cap_net_raw`). The widget only runs it; no sudo, setcap or extra packages. TCP and UDP (including QUIC), IPv4 and IPv6; only the current user's processes are attributed.
- The sample runs for 3 seconds on Apps/Tools open, on the Apps Refresh button and every 10 minutes while Apps is visible; it never runs in the background.
- If the helper is missing or cannot capture, speeds are hidden and the note under the list says why; connections keep working as before.

## v6.1.35
- Network Apps: expanded details show real data instead of `—` and `0`. `ss` omits the State column when the filter selects a single state (`state established` for TCP, connected sockets only for UDP), so fixed field positions pointed at the wrong fields. Endpoints are now located by content; IPv4, bracketed IPv6, IPv4-mapped IPv6, `%interface` scopes and wildcards are handled.
- Network Apps: expanded rows stay open across refreshes. State is kept per `process|PID`, several rows can be open at once; state of applications that disappear is dropped.
- Network Apps: removed the 3-second auto-refresh. The list refreshes when Apps or the Tools panel is opened, with the Apps Refresh button, and every 10 minutes while visible.
- Network Apps: new results replace the list in one step and only when they changed; if `ss` fails, the previous list stays on screen.
- Network Apps: connections are sorted by protocol, address and port, so an open list does not reshuffle between refreshes; row height follows its content, so long lists no longer overlap the next application.
- Network Apps: numeric columns aligned with the TCP / UDP / Total header.
- Footer version label matches the package version again.

## v6.1.34
- Network Apps: expanded row key moved from the delegate to the widget root (one row at a time); remote endpoint read from a different field index. Superseded by 6.1.35.

## v6.1.33
- Network Apps: attempted fix for row clicks/expansion. Superseded by 6.1.35.

## v6.1.32
- Network Apps keeps only information available through ordinary user-accessible Linux socket information.
- Per-application RX/TX byte totals are intentionally not shown because they are not reliably available to an unprivileged user for all processes and protocols.
- Fixed TCP/UDP remote endpoint parsing in the expanded application details.
- Expanded details now show the actual socket state when Linux reports one.
- No sudo, root access, capabilities, NetHogs, or additional packages are required.

## v6.1.30
- Network Apps now expands per-application connection details: PID, TCP/UDP/total counts, protocol, remote address, port, and connection activity/state.
- No root access, sudo, capabilities, or additional packages required.

## v6.1.29
- Reworked the Apps tool into **Network Apps**.
- Removed the NetHogs dependency and all root/capability requirements.
- Shows applications with active TCP/UDP network connections using the standard Linux `ss` socket information available to the user.
- Aggregates connections by process and displays TCP, UDP and total connection counts.
- Keeps the Apps tool fully self-contained: no extra package, `sudo`, capabilities or helper service is required.

## v6.1.28
- Added App Traffic tool using NetHogs for live per-process RX/TX bandwidth.
- Added automatic refresh every 3 seconds while the Apps tool is open.
- Added NetHogs dependency detection.
- Diagnostics now reports VPN state and measured latency in addition to interface, gateway, DNS, Internet, IPv4 and IPv6.
- Diagnostics uses Google connectivity probes, matching the main network check.
- Corrected the footer version to 6.1.28.

## v6.1.26
- Public IP History is now persistent across widget restarts and Plasma restarts.
- Keeps up to 30 recent public IP entries.
- History records only when the public IP changes; normal refreshes do not create duplicates.
- Timestamps use a stable `yyyy-MM-dd HH:mm:ss` format.
- No visual changes to the approved Tools layout.

## v6.1.25
- Corrected the displayed widget version in the footer.
- Fixed Diagnostics command execution and latency measurement in Plasma 6.
- No UI changes.
- Technical cleanup only: updated the footer version text to match the package version.
- No visual or functional changes.

## v6.1.21
- Increased the **Uptime** and **GitHub** text to match the traffic value text size.
- No other visual or functional changes.

## v6.1.20
- Redesigned the Speed Test screen with compact Download, Upload and Latency cards.
- Speed Test keeps previous results visible while a new test runs.
- Local IP rows now grow with their actual content and remain inside a scrollable area.
- Added a persistent Traffic bar below the Public IP / Local IPs tabs.
- Traffic shows received and sent bytes from non-loopback interfaces, using Linux network counters and displayed as since boot.
- Uses Cloudflare for latency, 25 MB download and 10 MB upload measurements.
- Scanner excludes IPv4 addresses assigned to the `lo` interface.
- Main widget layout aligned to the approved visual template.
- Network status indicator now refreshes independently every 30 seconds (instead of relying only on the 10-minute full refresh).
- Traffic is fixed at the bottom of the main view; network content uses the space above it.
- Traffic footer is a compact persistent bar with matching arrow, clock and GitHub icons; the previous red outline was removed.
- Uptime, GitHub and widget version are shown in the right side of the traffic footer.
- Reworked network status detection around NetworkManager connectivity state plus independent HTTPS reachability checks; Google/gstatic are followed by Microsoft connectivity test and Cloudflare fallback. A red state is shown only when there is no usable default route and NetworkManager is not reporting full connectivity, or when all external probes fail.
- VPN indicator is now separate from the Internet indicator and appears only while a VPN is actually active.
- VPN detection does not depend on interface names; it uses NetworkManager connection/device types plus an active, UP VPN interface with an assigned address.
- Internet indicator remains an independent green/red circle and no longer changes into a shield.
- Public IP details no longer force the update line to the bottom of the content area.

## v6.1.13
- Network Scanner results are presented as a fixed three-column table.
- Columns: **IP address**, **MAC address**, **Action**.
- IP and MAC cells stay aligned between the header and every row.
- Device status is represented by the indicator next to the IP; there is no separate status column.
- Scanner action uses `+` to add a device to Monitor and `−` to remove it.
- Tools continues to use the stable in-widget panel mechanism.

## Tools
- Scanner (device discovery + per-device TCP port scan)
- Diagnostics
- Speed
- Network Apps
- Monitor

## Package
- ID: `com.f1devbin.myipgeo`
- Plasma 6 / Qt 6
- License: MIT
