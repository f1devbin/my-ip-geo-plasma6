#!/bin/bash
# My IP & Geo - hardware inventory for the Hardware tab.
# Runs as a normal user: sysfs, /proc, udev's database and lsblk; lspci only names PCI devices
# when it is installed. No dmidecode (it needs root): the memory modules come from the
# properties udev keeps for the DMI device (systemd 248 and newer).
#
#   hardware.sh [run-id]        the run-id only makes every command string unique
#
# Output: one record per line, fields separated by tabs, the first field is the record type.
#   SYS     vendor  product  version  chassis
#   BOARD   vendor  name  version
#   BIOS    vendor  version  date  UEFI|BIOS
#   OS      name  kernel  architecture
#   CPU     model  sockets  cores  threads  max-MHz  L2  L3
#   MEM     total-bytes  slots  max-capacity-bytes  detail(yes|no)
#   DIMM    locator  size-bytes(0 = empty)  type  speed-MT/s  manufacturer  part-number  form-factor
#   GPU     name  driver
#   DISPLAY connector  resolution
#   DISK    name  size-bytes  kind  transport  model  removable(0|1)
#   NET     interface  kind  name  driver  speed-Mbit/s
#   BAT     name  manufacturer  model  technology  design-Wh  full-Wh  cycles  status  percent
#   AUDIO   name
#   TEMP    cpu  degrees-C
#   HEALTH  disk-name  degrees-C  ok|failing  power-on-hours  bad-sectors     (empty = not known)
# Disk health comes from udisks (udisksctl, no root): what the drive's own SMART self-assessment says.
# Serial numbers and MAC addresses are left out on purpose.

export LC_ALL=C
DMI=${MYIPGEO_DMI:-/sys/class/dmi/id}
SYS=${MYIPGEO_SYSFS:-/sys}

rd() { local v=""; [ -r "$1" ] && IFS= read -r v < "$1" 2>/dev/null; printf '%s' "$v" | tr '\t' ' ' | sed 's/^ *//; s/ *$//'; }
have() { command -v "$1" >/dev/null 2>&1; }
# Placeholder strings firmware vendors leave in DMI fields
clean() { case "$1" in "To Be Filled By O.E.M."|"To be filled by O.E.M."|"Default string"|"System Product Name"|"System manufacturer"|"Not Specified"|"Not Applicable"|"None"|"Unknown"|"INVALID"|"0000"|"O.E.M.") ;; *) printf '%s' "$1" ;; esac; }
dmi() { clean "$(rd "$DMI/$1")"; }
rec() { local IFS=$'\t'; printf '%s\n' "$*"; }
# "Class" "Vendor" "Device" ... of lspci -mm for one slot -> "Vendor Device"
pci_name() {
    have lspci || return
    timeout 3 lspci -mm -s "$1" 2>/dev/null | head -n 1 | awk -F'"' '{ v = $4; d = $6; sub(/ Corporation$| Corp\.$|, Inc\.$| Inc\.$| Co\., Ltd\.$/, "", v); print v " " d }'
}

chassis() {
    case "$(rd "$DMI/chassis_type")" in
        3|4|6|7|15|16|35) echo Desktop ;; 8|9|10|14) echo Laptop ;; 30) echo Tablet ;; 31|32) echo Convertible ;;
        11) echo Handheld ;; 13) echo All-in-one ;; 17|23|28|29) echo Server ;; *) echo "" ;;
    esac
}

rec SYS "$(dmi sys_vendor)" "$(dmi product_name)" "$(dmi product_version)" "$(chassis)"
rec BOARD "$(dmi board_vendor)" "$(dmi board_name)" "$(dmi board_version)"
rec BIOS "$(dmi bios_vendor)" "$(dmi bios_version)" "$(dmi bios_date)" "$([ -d "$SYS/firmware/efi" ] && echo UEFI || echo BIOS)"

os=$(sed -n 's/^PRETTY_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/os-release 2>/dev/null | head -n 1)
rec OS "$os" "$(uname -r)" "$(uname -m)"

# CPU: model, sockets, physical cores, threads; highest frequency and cache sizes from sysfs
cpu=$(awk -F': *' '
    /^model name/ && model == "" { model = $2 }
    /^Hardware/ && model == "" { model = $2 }
    /^processor/ { threads++ }
    /^physical id/ { pid = $2; sockets[pid] = 1 }
    /^core id/ { cores[pid "/" $2] = 1 }
    END { s = 0; for (k in sockets) s++; c = 0; for (k in cores) c++
          if (s == 0) s = 1; if (c == 0) c = threads
          printf "%s\t%d\t%d\t%d", model, s, c, threads }' /proc/cpuinfo 2>/dev/null)
mhz=""; khz=$(rd "$SYS/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"); [ -n "$khz" ] && mhz=$((khz / 1000))
l2=""; l3=""
for c in "$SYS"/devices/system/cpu/cpu0/cache/index*; do
    [ -d "$c" ] || continue
    case "$(rd "$c/level")" in 2) l2=$(rd "$c/size") ;; 3) l3=$(rd "$c/size") ;; esac
done
printf 'CPU\t%s\t%s\t%s\t%s\n' "$cpu" "$mhz" "$l2" "$l3"

# Memory: total from the kernel, modules from udev's DMI properties
total=$(awk '/^MemTotal:/ { printf "%.0f", $2 * 1024 }' /proc/meminfo 2>/dev/null)
props=""
have udevadm && props=$(timeout 5 udevadm info -q property -p "${MYIPGEO_DMI_DEV:-/sys/devices/virtual/dmi/id}" 2>/dev/null | grep '^MEMORY_')
if [ -n "$props" ]; then
    printf '%s\n' "$props" | awk -F= -v total="$total" '
        function val(k) { return (k in p) ? p[k] : "" }
        { key = $1; sub(/^[^=]*=/, ""); gsub(/\t/, " "); p[key] = $0
          if (match(key, /^MEMORY_DEVICE_[0-9]+_/)) { n = substr(key, 15); sub(/_.*/, "", n); if (n + 0 >= count) count = n + 1 } }
        END {
            slots = val("MEMORY_ARRAY_NUM_DEVICES"); if (slots == "" || slots + 0 < count) slots = count
            printf "MEM\t%s\t%s\t%s\tyes\n", total, slots, val("MEMORY_ARRAY_MAX_CAPACITY")
            for (i = 0; i < count; i++) {
                d = "MEMORY_DEVICE_" i "_"
                size = val(d "SIZE"); if (val(d "PRESENT") == "0" || size == "") size = 0
                speed = val(d "CONFIGURED_SPEED_MTS"); if (speed == "") speed = val(d "SPEED_MTS")
                loc = val(d "LOCATOR"); if (loc == "") loc = "Slot " (i + 1)
                printf "DIMM\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", loc, size, val(d "TYPE"), speed, val(d "MANUFACTURER"), val(d "PART_NUMBER"), val(d "FORM_FACTOR")
            }
        }'
else
    rec MEM "$total" "" "" no
fi

# Graphics adapters and connected displays
for card in "$SYS"/class/drm/card[0-9]*; do
    [ -e "$card" ] || continue
    name=${card##*/}
    case "$name" in
        *-*)
            [ "$(rd "$card/status")" = connected ] || continue
            mode=""; [ -r "$card/modes" ] && IFS= read -r mode < "$card/modes"
            rec DISPLAY "${name#card[0-9]*-}" "$mode" ;;
        *)
            slot=$(readlink -f "$card/device" 2>/dev/null); slot=${slot##*/}
            gpu=$(pci_name "$slot")
            if [ -z "$gpu" ]; then
                case "$(rd "$card/device/vendor")" in 0x8086) gpu="Intel graphics" ;; 0x10de) gpu="NVIDIA graphics" ;; 0x1002) gpu="AMD graphics" ;; *) gpu="Graphics adapter" ;; esac
            fi
            drv=$(readlink -f "$card/device/driver" 2>/dev/null)
            rec GPU "$gpu" "${drv##*/}" ;;
    esac
done

# Disks (whole devices): size, kind, model
disks=""
if have lsblk; then
    disks=$(timeout 5 lsblk -d -P -b -o NAME,SIZE,ROTA,TRAN,MODEL,TYPE,RM 2>/dev/null | awk '
        function field(line, key,    v) {
            if (match(line, "(^| )" key "=\"[^\"]*\"")) { v = substr(line, RSTART, RLENGTH); sub("^ ?" key "=\"", "", v); sub("\"$", "", v); return v }
            return ""
        }
        {
            if (field($0, "TYPE") != "disk") next
            name = field($0, "NAME"); size = field($0, "SIZE") + 0
            if (size == 0 || name ~ /^(zram|loop|ram|fd)/) next
            tran = field($0, "TRAN"); rota = field($0, "ROTA")
            if (tran == "nvme") kind = "NVMe SSD"
            else if (tran == "virtio") kind = "Virtual disk"
            else if (tran == "usb") kind = (rota == "1") ? "USB HDD" : "USB drive"
            else if (name ~ /^mmcblk/) kind = "eMMC / SD card"
            else kind = (rota == "1") ? "HDD" : "SSD"
            model = field($0, "MODEL"); gsub(/\\x20/, " ", model); gsub(/\t/, " ", model); sub(/ +$/, "", model)
            printf "DISK\t%s\t%.0f\t%s\t%s\t%s\t%s\n", name, size, kind, tran, model, field($0, "RM")
        }')
    [ -n "$disks" ] && printf '%s\n' "$disks"
fi

# Temperatures from hwmon (millidegrees): the CPU package, and disks that report one (NVMe, drivetemp)
mdeg() { local v; v=$(rd "$1"); case "$v" in ''|*[!0-9-]*) return ;; esac; echo $(( (v + 500) / 1000 )); }
cputemp=""
declare -A dtemp
for h in "$SYS"/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    case "$(rd "$h/name")" in
        coretemp|k10temp|zenpower|cpu_thermal)
            [ -n "$cputemp" ] && continue
            for l in "$h"/temp*_label; do
                [ -r "$l" ] || continue
                case "$(rd "$l")" in "Package id 0"|Tctl|Tdie) cputemp=$(mdeg "${l%_label}_input"); break ;; esac
            done
            [ -n "$cputemp" ] || cputemp=$(mdeg "$h/temp1_input") ;;
        nvme)
            for b in "$h"/device/nvme*n*; do [ -e "$b" ] && dtemp[${b##*/}]=$(mdeg "$h/temp1_input"); done ;;
        drivetemp)
            for b in "$h"/device/block/*; do [ -e "$b" ] && dtemp[${b##*/}]=$(mdeg "$h/temp1_input"); done ;;
    esac
done
if [ -z "$cputemp" ]; then
    for z in "$SYS"/class/thermal/thermal_zone*; do
        [ "$(rd "$z/type")" = x86_pkg_temp ] && { cputemp=$(mdeg "$z/temp"); break; }
    done
fi
[ -n "$cputemp" ] && rec TEMP cpu "$cputemp"

# Disk health: the drive's SMART self-assessment as udisks last read it
printf '%s\n' "$disks" | while IFS=$'\t' read -r _ name _; do
    [ -n "$name" ] || continue
    temp=${dtemp[$name]:-}; state=""; hours=""; bad=""
    if have udisksctl; then
        id=$(timeout 4 udisksctl info -b "/dev/$name" 2>/dev/null | sed -n "s|^ *Drive: *'.*/\\([^/']*\\)'.*|\\1|p" | head -n 1)
        if [ -n "$id" ]; then
            info=$(timeout 4 udisksctl info -d "$id" 2>/dev/null | awk -F': *' '
                { key = $1; gsub(/^ +/, "", key); v[key] = $2 }
                END {
                    if (v["SmartUpdated"] + 0 == 0) exit
                    state = "ok"
                    if (v["SmartFailing"] == "true" || (("SmartCriticalWarning" in v) && v["SmartCriticalWarning"] != "")) state = "failing"
                    hours = ""; if (v["SmartPowerOnHours"] + 0 > 0) hours = v["SmartPowerOnHours"] + 0; else if (v["SmartPowerOnSeconds"] + 0 > 0) hours = int(v["SmartPowerOnSeconds"] / 3600)
                    temp = ""; if (v["SmartTemperature"] + 0 > 200) temp = int(v["SmartTemperature"] - 273.15 + 0.5)
                    bad = ("SmartNumBadSectors" in v && v["SmartNumBadSectors"] + 0 >= 0) ? v["SmartNumBadSectors"] + 0 : ""
                    printf "%s|%s|%s|%s", state, hours, temp, bad
                }')
            if [ -n "$info" ]; then
                IFS='|' read -r state hours t bad <<< "$info"
                [ -n "$temp" ] || temp=$t
            fi
        fi
    fi
    [ -n "$temp$state" ] && rec HEALTH "$name" "$temp" "$state" "$hours" "$bad"
done

# Physical network adapters
for n in "$SYS"/class/net/*; do
    [ -e "$n/device" ] || continue
    # USB modems often have no DEVTYPE in their uevent: the name (wwan*, wwp*) and driver tell
    if [ -d "$n/wireless" ] || [ -d "$n/phy80211" ]; then kind="Wi-Fi"
    elif grep -qs '^DEVTYPE=wwan' "$n/uevent"; then kind="Mobile broadband"
    else
        case "${n##*/}:$(readlink -f "$n/device/driver" 2>/dev/null)" in
            ww*|*/cdc_mbim|*/qmi_wwan|*/mhi_net|*/ipheth) kind="Mobile broadband" ;;
            *) kind="Ethernet" ;;
        esac
    fi
    dev=$(readlink -f "$n/device" 2>/dev/null)
    case "$dev" in
        */usb*) kind="$kind (USB)"; p=$dev; nm=""
                while [ "$p" != / ] && [ -z "$nm" ]; do [ -r "$p/product" ] && nm="$(rd "$p/manufacturer") $(rd "$p/product")"; p=${p%/*}; [ -n "$p" ] || p=/; done ;;
        *) nm=$(pci_name "${dev##*/}") ;;
    esac
    drv=$(readlink -f "$n/device/driver" 2>/dev/null)
    speed=$(cat "$n/speed" 2>/dev/null); case "$speed" in ''|-1|*[!0-9]*) speed="" ;; esac
    rec NET "${n##*/}" "$kind" "$nm" "${drv##*/}" "$speed"
done

# Batteries: capacity in Wh (energy_* in uWh, or charge_* in uAh with the design voltage)
for b in "$SYS"/class/power_supply/*; do
    [ "$(rd "$b/type")" = Battery ] || continue
    [ "$(rd "$b/scope")" = Device ] && continue      # mouse or keyboard battery
    design=$(rd "$b/energy_full_design"); full=$(rd "$b/energy_full")
    if [ -z "$design" ]; then
        v=$(rd "$b/voltage_min_design"); cd=$(rd "$b/charge_full_design"); cf=$(rd "$b/charge_full")
        [ -n "$v" ] && [ -n "$cd" ] && design=$(awk -v c="$cd" -v v="$v" 'BEGIN { printf "%.0f", c * v / 1000000 }')
        [ -n "$v" ] && [ -n "$cf" ] && full=$(awk -v c="$cf" -v v="$v" 'BEGIN { printf "%.0f", c * v / 1000000 }')
    fi
    wh() { [ -n "$1" ] && awk -v e="$1" 'BEGIN { printf "%.1f", e / 1000000 }'; }
    rec BAT "${b##*/}" "$(clean "$(rd "$b/manufacturer")")" "$(clean "$(rd "$b/model_name")")" "$(clean "$(rd "$b/technology")")" \
        "$(wh "$design")" "$(wh "$full")" "$(rd "$b/cycle_count")" "$(rd "$b/status")" "$(rd "$b/capacity")"
done

# Sound cards: " 0 [PCH            ]: HDA-Intel - HDA Intel PCH"
[ -r "${MYIPGEO_ASOUND:-/proc/asound/cards}" ] && sed -n 's/^ *[0-9][0-9]* \[[^]]*\]: [^ ]* - \(.*\)$/\1/p' "${MYIPGEO_ASOUND:-/proc/asound/cards}" | tr '\t' ' ' | awk '!seen[$0]++ { print "AUDIO\t" $0 }'
exit 0
