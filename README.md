# My IP & Geo

Version 6.1.39

Compact KDE Plasma 6 widget for public IP/geolocation, local network information and network tools.

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
- Scanner
- Diagnostics
- Speed
- Network Apps
- Monitor

## Package
- ID: `com.f1devbin.myipgeo`
- Plasma 6 / Qt 6
- License: MIT
