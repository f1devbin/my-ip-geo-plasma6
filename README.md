# My IP & Geo

Version 6.1.29

Compact KDE Plasma 6 widget for public IP/geolocation, local network information and network tools.

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
- IP History
- Speed
- Network Apps
- Monitor

## Package
- ID: `com.f1devbin.myipgeo`
- Plasma 6 / Qt 6
- License: MIT


## v6.1.30
- Network Apps now expands per-application connection details: PID, TCP/UDP/total counts, protocol, remote address, port, and connection activity/state.
- No root access, sudo, capabilities, or additional packages required.


## v6.1.32
- Network Apps keeps only information available through ordinary user-accessible Linux socket information.
- Per-application RX/TX byte totals are intentionally not shown because they are not reliably available to an unprivileged user for all processes and protocols.
- Fixed TCP/UDP remote endpoint parsing in the expanded application details.
- Expanded details now show the actual socket state when Linux reports one.
- No sudo, root access, capabilities, NetHogs, or additional packages are required.
