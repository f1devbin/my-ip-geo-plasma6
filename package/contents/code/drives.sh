#!/bin/bash
# My IP & Geo - external drives for the drives block.
# Standard tools only (lsblk, df), runs as a normal user.
#
#   drives.sh [run-id]     the run-id only makes every command string unique
#
# lsblk and df are time-limited: a dying USB drive must not hang the run.
#
# One line per volume, tab-separated:
#   name size label fstype mountpoint transport model used avail
# Volumes are the partitions of removable/hotplug/USB disks (or the disk itself when it has
# no partitions). Disks holding /, /boot, /home, /usr, /var or swap are the system disk and
# are skipped. Text fields keep lsblk's \xNN escapes; main.qml decodes them.
# A LUKS partition shows the filesystem and mount point of its opened mapping.

export LC_ALL=C
command -v lsblk >/dev/null 2>&1 || { echo "__NOLSBLK__"; exit 0; }

# \037 between the two steps: tabs are whitespace for read and would merge empty fields
list_volumes() {
    timeout 5 lsblk -P -b -o NAME,KNAME,PKNAME,TYPE,SIZE,RM,HOTPLUG,TRAN,FSTYPE,LABEL,MOUNTPOINT,MODEL 2>/dev/null | awk '
    function field(line, key,    m, v) {
        # key="value": lsblk -P hex-escapes quotes and other unsafe characters inside values
        if (match(line, "(^| )" key "=\"[^\"]*\"")) {
            v = substr(line, RSTART, RLENGTH)
            sub("^ ?" key "=\"", "", v); sub("\"$", "", v)
            return v
        }
        return ""
    }
    {
        n++
        k = field($0, "KNAME"); kname[n] = k
        pk[n] = field($0, "PKNAME"); type[n] = field($0, "TYPE"); size[n] = field($0, "SIZE")
        rm[n] = field($0, "RM"); hp[n] = field($0, "HOTPLUG"); tran[n] = field($0, "TRAN")
        fs[n] = field($0, "FSTYPE"); label[n] = field($0, "LABEL"); mp[n] = field($0, "MOUNTPOINT")
        model[n] = field($0, "MODEL")
        idx[k] = n
    }
    function diskof(i,    d, guard) {
        d = i
        while (pk[d] != "" && (pk[d] in idx) && guard++ < 8) d = idx[pk[d]]
        return d
    }
    END {
        # system disks: anything below them mounted where the OS lives
        for (i = 1; i <= n; i++)
            if (mp[i] ~ /^\/$|^\/(boot|home|usr|var)(\/|$)|^\[SWAP\]$/) sys[kname[diskof(i)]] = 1
        for (i = 1; i <= n; i++) {
            if (type[i] == "part" && pk[i] in idx) parts[pk[i]]++
            if (type[i] == "crypt" || type[i] == "lvm") { if (pk[i] in idx) child[pk[i]] = i }
        }
        for (i = 1; i <= n; i++) {
            d = diskof(i)
            if (type[d] != "disk" || (kname[d] in sys)) continue
            if (!(rm[d] == "1" || tran[d] == "usb" || (hp[d] == "1" && tran[d] != "sata" && tran[d] != "nvme"))) continue
            if (type[i] == "part") { if (size[i] + 0 < 1048576) continue }      # extended partition entry
            else if (type[i] == "disk") { if (kname[i] in parts) continue; if (size[i] + 0 == 0) continue }  # empty card reader
            else continue
            f = fs[i]; m = mp[i]
            if (kname[i] in child) { c = child[kname[i]]; if (m == "") m = mp[c]; if (fs[c] != "") f = fs[c] }
            t = tran[d] != "" ? tran[d] : (rm[d] == "1" ? "removable" : "hotplug")
            printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\n", kname[i], size[i], label[i], f, m, t, model[d]
        }
    }'
}

list_volumes | while IFS=$'\037' read -r name size label fstype mnt tran model; do
    used=-1; avail=-1
    if [ -n "$mnt" ]; then
        # df needs the real path: undo lsblk's \xNN escapes
        path=$(printf '%b' "$mnt")
        set -- $(timeout 3 df -P -B1 -- "$path" 2>/dev/null | awk 'NR == 2 { print $3, $4 }')
        [ $# -eq 2 ] && { used=$1; avail=$2; }
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$size" "$label" "$fstype" "$mnt" "$tran" "$model" "$used" "$avail"
done
