#!/bin/bash
# hardware.sh against a fake sysfs, udev database, lsblk and lspci (a laptop with one free memory slot)
S=${1:?hardware.sh}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/dmi" "$T/sys/firmware/efi" "$T/sys/devices/system/cpu/cpu0/cpufreq" "$T/sys/class/drm" "$T/sys/class/net" "$T/sys/class/power_supply/BAT0" "$T/sys/class/power_supply/hidpp_battery_0"
put() { printf '%s\n' "$2" > "$1"; }
put "$T/dmi/sys_vendor" LENOVO; put "$T/dmi/product_name" 20N2000KRT; put "$T/dmi/product_version" "ThinkPad T490"; put "$T/dmi/chassis_type" 10
put "$T/dmi/board_vendor" LENOVO; put "$T/dmi/board_name" 20N2000KRT; put "$T/dmi/board_version" "Not Specified"
put "$T/dmi/bios_vendor" LENOVO; put "$T/dmi/bios_version" "N2IET97W (1.75 )"; put "$T/dmi/bios_date" 02/21/2024
put "$T/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq" 3900000
for i in 2:256K 3:6144K; do mkdir -p "$T/sys/devices/system/cpu/cpu0/cache/index${i%%:*}"; put "$T/sys/devices/system/cpu/cpu0/cache/index${i%%:*}/level" "${i%%:*}"; put "$T/sys/devices/system/cpu/cpu0/cache/index${i%%:*}/size" "${i##*:}"; done
# graphics: one card, an internal panel and a disconnected HDMI output
mkdir -p "$T/pci/0000:00:02.0/driver_i915" "$T/sys/class/drm/card1-eDP-1" "$T/sys/class/drm/card1-HDMI-A-1" "$T/drivers/i915" "$T/drivers/iwlwifi" "$T/drivers/e1000e"
ln -s "$T/drivers/i915" "$T/pci/0000:00:02.0/driver"; put "$T/pci/0000:00:02.0/vendor" 0x8086
mkdir -p "$T/sys/class/drm/card1"; ln -s "$T/pci/0000:00:02.0" "$T/sys/class/drm/card1/device"
put "$T/sys/class/drm/card1-eDP-1/status" connected; printf '1920x1080\n1280x720\n' > "$T/sys/class/drm/card1-eDP-1/modes"
put "$T/sys/class/drm/card1-HDMI-A-1/status" disconnected
# network: Wi-Fi and Ethernet on PCI, a tunnel without a device
for n in wlp0s20f3:0000:00:14.3:iwlwifi enp0s31f6:0000:00:1f.6:e1000e; do
    IFS=: read -r ifc a b c drv <<< "$n"; slot="$a:$b:$c"
    mkdir -p "$T/pci/$slot" "$T/sys/class/net/$ifc"; ln -s "$T/drivers/$drv" "$T/pci/$slot/driver"; ln -s "$T/pci/$slot" "$T/sys/class/net/$ifc/device"
done
mkdir -p "$T/sys/class/net/wlp0s20f3/wireless" "$T/sys/class/net/tun0"; put "$T/sys/class/net/enp0s31f6/speed" 1000
# battery (uWh) and a mouse battery that must be skipped
B="$T/sys/class/power_supply/BAT0"; put "$B/type" Battery; put "$B/manufacturer" SMP; put "$B/model_name" 02DL008; put "$B/technology" Li-poly
put "$B/energy_full_design" 50450000; put "$B/energy_full" 41230000; put "$B/cycle_count" 312; put "$B/status" Discharging; put "$B/capacity" 76
M="$T/sys/class/power_supply/hidpp_battery_0"; put "$M/type" Battery; put "$M/scope" Device
cat > "$T/bin/udevadm" <<'U'
#!/bin/bash
cat <<'P'
DEVPATH=/devices/virtual/dmi/id
MEMORY_ARRAY_LOCATION=System Board Or Motherboard
MEMORY_ARRAY_MAX_CAPACITY=68719476736
MEMORY_ARRAY_NUM_DEVICES=2
MEMORY_DEVICE_0_TOTAL_WIDTH=64
MEMORY_DEVICE_0_SIZE=8589934592
MEMORY_DEVICE_0_FORM_FACTOR=SODIMM
MEMORY_DEVICE_0_LOCATOR=ChannelA-DIMM0
MEMORY_DEVICE_0_TYPE=DDR4
MEMORY_DEVICE_0_SPEED_MTS=2667
MEMORY_DEVICE_0_MANUFACTURER=Samsung
MEMORY_DEVICE_0_SERIAL_NUMBER=12345678
MEMORY_DEVICE_0_PART_NUMBER=M471A1K43DB1-CTD
MEMORY_DEVICE_0_CONFIGURED_SPEED_MTS=2400
MEMORY_DEVICE_1_PRESENT=0
MEMORY_DEVICE_1_FORM_FACTOR=SODIMM
MEMORY_DEVICE_1_LOCATOR=ChannelB-DIMM0
MEMORY_DEVICE_1_TYPE=Unknown
P
U
cat > "$T/bin/lsblk" <<'L'
#!/bin/bash
cat <<'P'
NAME="loop0" SIZE="4096" ROTA="0" TRAN="" MODEL="" TYPE="loop" RM="0"
NAME="sda" SIZE="512110190592" ROTA="0" TRAN="sata" MODEL="KINGSTON OM8P0S3512Q-A0" TYPE="disk" RM="0"
NAME="nvme0n1" SIZE="1000204886016" ROTA="0" TRAN="nvme" MODEL="Samsung\x20SSD 980" TYPE="disk" RM="0"
NAME="sdb" SIZE="8053063680" ROTA="1" TRAN="usb" MODEL="ProductCode" TYPE="disk" RM="1"
NAME="sdc" SIZE="0" ROTA="1" TRAN="usb" MODEL="Card Reader" TYPE="disk" RM="1"
NAME="zram0" SIZE="4294967296" ROTA="0" TRAN="" MODEL="" TYPE="disk" RM="0"
P
L
cat > "$T/bin/lspci" <<'L'
#!/bin/bash
case "$*" in
  *00:02.0) echo '00:02.0 "VGA compatible controller" "Intel Corporation" "WhiskeyLake-U GT2 [UHD Graphics 620]" -r02 "Lenovo" "Device 2279"' ;;
  *00:14.3) echo '00:14.3 "Network controller" "Intel Corporation" "Cannon Point-LP CNVi [Wireless-AC]" -r30 "Intel Corporation" "Device 0034"' ;;
  *00:1f.6) echo '00:1f.6 "Ethernet controller" "Intel Corporation" "Ethernet Connection (6) I219-V" -r30 "Lenovo" "Device 2279"' ;;
esac
L
# mobile broadband modem on USB
mkdir -p "$T/usb/1-6/1-6:1.0" "$T/sys/class/net/wwp0s20f0u7" "$T/drivers/cdc_mbim"
put "$T/usb/1-6/manufacturer" FIBOCOM; put "$T/usb/1-6/product" L830-EB-00
ln -s "$T/drivers/cdc_mbim" "$T/usb/1-6/1-6:1.0/driver"; ln -s "$T/usb/1-6/1-6:1.0" "$T/sys/class/net/wwp0s20f0u7/device"
printf 'DEVTYPE=wwan\nINTERFACE=wwp0s20f0u7\n' > "$T/sys/class/net/wwp0s20f0u7/uevent"
# temperatures: CPU package, NVMe disk
H="$T/sys/class/hwmon"; mkdir -p "$H/hwmon3" "$H/hwmon1/device/nvme0n1"
put "$H/hwmon3/name" coretemp; put "$H/hwmon3/temp1_label" "Package id 0"; put "$H/hwmon3/temp1_input" 52000; put "$H/hwmon3/temp2_label" "Core 0"; put "$H/hwmon3/temp2_input" 49000
put "$H/hwmon1/name" nvme; put "$H/hwmon1/temp1_input" 38850
printf ' 0 [PCH            ]: HDA-Intel - HDA Intel PCH\n                      HDA Intel PCH at 0xea238000 irq 144\n 1 [sofhdadsp      ]: sof-hda-dsp - sof-hda-dsp\n' > "$T/asound"
cat > "$T/bin/udisksctl" <<'U'
#!/bin/bash
case "$*" in
  "info -b /dev/sda") printf "/org/freedesktop/UDisks2/block_devices/sda:\n  org.freedesktop.UDisks2.Block:\n    Drive:                      '/org/freedesktop/UDisks2/drives/KINGSTON_OM8P0S3512Q_A0_50026B7'\n    Size:                       512110190592\n" ;;
  "info -d KINGSTON_OM8P0S3512Q_A0_50026B7") cat <<'P'
/org/freedesktop/UDisks2/drives/KINGSTON_OM8P0S3512Q_A0_50026B7:
  org.freedesktop.UDisks2.Drive:
    Model:                      KINGSTON OM8P0S3512Q-A0
    Serial:                     50026B7
  org.freedesktop.UDisks2.Drive.Ata:
    SmartEnabled:               true
    SmartFailing:               false
    SmartNumBadSectors:         0
    SmartPowerOnSeconds:        15552000
    SmartSupported:             true
    SmartTemperature:           307.15
    SmartUpdated:               1790000000
P
  ;;
  "info -b /dev/sdb") printf "  org.freedesktop.UDisks2.Block:\n    Drive:                      '/org/freedesktop/UDisks2/drives/Flash'\n" ;;
  "info -d Flash") printf "  org.freedesktop.UDisks2.Drive:\n    Model:                      Flash\n" ;;
  *) exit 1 ;;
esac
U
chmod +x "$T/bin/"*
export MYIPGEO_ASOUND="$T/asound"
fail=0
out=$(PATH="$T/bin:$PATH" MYIPGEO_DMI="$T/dmi" MYIPGEO_SYSFS="$T/sys" bash "$S" 1)
has() { if printf '%s\n' "$out" | grep -qxF -- "$2"; then echo "ok  - $1"; else echo "FAIL- $1: no line [$2]"; fail=1; fi; }
tab() { local IFS=$'\t'; printf '%s' "$*"; }
has "system: vendor, product, version, laptop" "$(tab SYS LENOVO 20N2000KRT 'ThinkPad T490' Laptop)"
has "board: placeholder version dropped" "$(tab BOARD LENOVO 20N2000KRT '')"
has "firmware: UEFI" "$(tab BIOS LENOVO 'N2IET97W (1.75 )' 02/21/2024 UEFI)"
has "memory: slots and maximum from udev" "$(tab MEM "$(awk '/^MemTotal:/ { printf "%.0f", $2 * 1024 }' /proc/meminfo)" 2 68719476736 yes)"
has "memory module: configured speed, no serial number" "$(tab DIMM ChannelA-DIMM0 8589934592 DDR4 2400 Samsung M471A1K43DB1-CTD SODIMM)"
has "memory: empty slot" "$(tab DIMM ChannelB-DIMM0 0 Unknown '' '' '' SODIMM)"
has "graphics adapter named by lspci, with its driver" "$(tab GPU 'Intel WhiskeyLake-U GT2 [UHD Graphics 620]' i915)"
has "connected display with its first mode" "$(tab DISPLAY eDP-1 1920x1080)"
has "SATA SSD" "$(tab DISK sda 512110190592 SSD sata 'KINGSTON OM8P0S3512Q-A0' 0)"
has "NVMe SSD, escaped space in the model" "$(tab DISK nvme0n1 1000204886016 'NVMe SSD' nvme 'Samsung SSD 980' 0)"
has "USB drive" "$(tab DISK sdb 8053063680 'USB HDD' usb ProductCode 1)"
has "Wi-Fi adapter" "$(tab NET wlp0s20f3 Wi-Fi 'Intel Cannon Point-LP CNVi [Wireless-AC]' iwlwifi '')"
has "Ethernet adapter with link speed" "$(tab NET enp0s31f6 Ethernet 'Intel Ethernet Connection (6) I219-V' e1000e 1000)"
has "battery in Wh" "$(tab BAT BAT0 SMP 02DL008 Li-poly 50.5 41.2 312 Discharging 76)"
has "mobile broadband modem named from USB" "$(tab NET wwp0s20f0u7 'Mobile broadband (USB)' 'FIBOCOM L830-EB-00' cdc_mbim '')"
has "CPU temperature: the package sensor" "$(tab TEMP cpu 52)"
has "SATA disk health from udisks: state, hours, temperature, bad sectors" "$(tab HEALTH sda 34 ok 4320 0)"
has "NVMe disk temperature from hwmon, no udisks data" "$(tab HEALTH nvme0n1 39 '' '' '')"
has "sound card with a dash in the driver name" "$(tab AUDIO 'HDA Intel PCH')"
has "second sound card" "$(tab AUDIO 'sof-hda-dsp')"
n() { printf '%s\n' "$out" | grep -c "$1"; }
[ "$(n '^DISK')" = 3 ] && echo "ok  - loop, zram and the empty card reader are not disks" || { echo "FAIL- disks: $(n '^DISK')"; fail=1; }
[ "$(n '^DISPLAY')" = 1 ] && [ "$(n '^NET')" = 3 ] && [ "$(n '^HEALTH')" = 2 ] && [ "$(n '^BAT')" = 1 ] && echo "ok  - disconnected output, tunnel and mouse battery skipped" || { echo "FAIL- counts"; fail=1; }
[ "$(n '12345678')" = 0 ] && [ "$(n '50026B7')" = 0 ] && echo "ok  - no serial numbers in the output" || { echo "FAIL- serial number leaked"; fail=1; }
# without udev's DMI data only the total is reported
rm "$T/bin/udevadm"; printf '#!/bin/bash\nexit 1\n' > "$T/bin/udevadm"; chmod +x "$T/bin/udevadm"
out=$(PATH="$T/bin:$PATH" MYIPGEO_DMI="$T/dmi" MYIPGEO_SYSFS="$T/sys" bash "$S" 1)
printf '%s\n' "$out" | grep -q "^MEM	[0-9]*			no$" && [ "$(n '^DIMM')" = 0 ] && echo "ok  - no module data: total only" || { echo "FAIL- fallback"; fail=1; }
[ $fail = 0 ] || printf '%s\n' "$out" | cat -A
exit $fail
