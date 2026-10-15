#!/bin/bash
# v6.1.55: drives.sh picks external volumes from lsblk -P and adds df usage for mounted ones
S=${1:?drives.sh}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/lsblk" <<'L'
#!/bin/bash
cat "$FAKE/lsblk"
L
cat > "$T/bin/df" <<'D'
#!/bin/bash
# df -P -B1 -- <path>
p=${@: -1}
echo "Filesystem 1-blocks Used Available Capacity Mounted on"
case "$p" in
  "/media/max/My Disk") echo "/dev/sdc1 500000000000 120000000000 380000000000 24% /media/max/My Disk" ;;
  /media/max/KINGSTON) echo "/dev/sdb1 31000000000 1000000000 30000000000 4% /media/max/KINGSTON" ;;
  /media/max/secret) echo "/dev/mapper/luks-1 999000000 500000000 499000000 50% /media/max/secret" ;;
  *) exit 1 ;;
esac
D
chmod +x "$T/bin/"*
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok  - $1"; else echo "FAIL- $1:"; echo " got: $2" | cat -A; echo "want: $3" | cat -A; fail=1; fi; }
run() { FAKE=$T PATH="$T/bin:$PATH" bash "$S" 7; }
H='NAME="%s" KNAME="%s" PKNAME="%s" TYPE="%s" SIZE="%s" RM="%s" HOTPLUG="%s" TRAN="%s" FSTYPE="%s" LABEL="%s" MOUNTPOINT="%s" MODEL="%s"\n'
{
  printf "$H" nvme0n1 nvme0n1 "" disk 512110190592 0 0 nvme "" "" "" "Samsung SSD 980"
  printf "$H" nvme0n1p1 nvme0n1p1 nvme0n1 part 536870912 0 0 "" vfat "" /boot/efi ""
  printf "$H" nvme0n1p2 nvme0n1p2 nvme0n1 part 511571394560 0 0 "" ext4 "" / ""
  printf "$H" sda sda "" disk 1000204886016 0 1 sata "" "" "" "WDC WD10"
  printf "$H" sda1 sda1 sda part 1000204886016 0 1 "" ext4 Data /mnt/data ""
  printf "$H" sdb sdb "" disk 31004295168 1 1 usb "" "" "" "DataTraveler 3.0"
  printf "$H" sdb1 sdb1 sdb part 31003246592 1 1 "" vfat KINGSTON /media/max/KINGSTON ""
  printf "$H" sdc sdc "" disk 500107862016 0 1 usb "" "" "" "Elements"
  printf "$H" sdc1 sdc1 sdc part 1024 0 1 "" "" "" "" ""
  printf "$H" sdc5 sdc5 sdc part 500106813440 0 1 "" ntfs 'My\x20Disk' '/media/max/My\x20Disk' ""
  printf "$H" sdc6 sdc6 sdc part 1000000000 0 1 "" crypto_LUKS "" "" ""
  printf "$H" luks-1 dm-0 sdc6 crypt 999000000 0 0 "" ext4 secret /media/max/secret ""
  printf "$H" sdd sdd "" disk 0 1 1 usb "" "" "" "Card Reader"
  printf "$H" sde sde "" disk 8053063680 1 1 usb exfat CAMERA "" "Flash"
  printf "$H" loop0 loop0 "" loop 4096 0 0 "" squashfs "" /snap/x/1 ""
} > "$T/lsblk"
out=$(run)
want=$(printf 'sdb1\t31003246592\tKINGSTON\tvfat\t/media/max/KINGSTON\tusb\tDataTraveler 3.0\t1000000000\t30000000000
sdc5\t500106813440\tMy\\x20Disk\tntfs\t/media/max/My\\x20Disk\tusb\tElements\t120000000000\t380000000000
sdc6\t1000000000\t\text4\t/media/max/secret\tusb\tElements\t500000000\t499000000
sde\t8053063680\tCAMERA\texfat\t\tusb\tFlash\t-1\t-1')
check "external volumes only, system/SATA/loop/extended/empty reader skipped, LUKS via mapping, escaped path" "$out" "$want"

# a USB stick holding / is the system disk (live system): skipped
printf "$H" sdf sdf "" disk 16000000000 1 1 usb "" "" "" "Live" > "$T/lsblk"
printf "$H" sdf1 sdf1 sdf part 15000000000 1 1 "" ext4 "" / "" >> "$T/lsblk"
check "a removable disk with / is skipped" "$(run)" ""

: > "$T/lsblk"
check "no block devices: empty output" "$(run)" ""
exit $fail
