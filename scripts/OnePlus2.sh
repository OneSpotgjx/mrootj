#!/data/data/com.termux/files/usr/bin/bash

set -e

# ========= 基本配置 =========
SELECTED_VID=0x2a70   # OnePlus VID
FASTBOOT="fastboot -i $SELECTED_VID"
ADB="adb"

# ========= 输出函数 =========
info() { echo "[*] $1"; }
ok() { echo "[✓] $1"; }
err() { echo "[✗] $1"; exit 1; }

# ========= 检测 fastboot =========
check_fastboot() {
    command -v fastboot >/dev/null 2>&1 || err "未找到 fastboot"
}

# ========= 获取设备 =========
get_device() {
    TARGET_DEVICE=$($FASTBOOT devices | awk '{print $1}' | head -n1)
    [ -z "$TARGET_DEVICE" ] && err "未检测到 fastboot 设备"
    ok "检测到设备：$TARGET_DEVICE"
}

# ========= 获取当前 slot =========
get_slot() {
    SLOT=$($FASTBOOT -s $TARGET_DEVICE getvar current-slot 2>&1 | grep -o '_[ab]')
    SLOT=${SLOT#_}
    [ -z "$SLOT" ] && err "无法获取当前 slot"
    ok "当前 Slot：$SLOT"
}

# ========= 刷入镜像 =========
flash_image() {
    read -rp "请输入镜像完整路径（如 /storage/emulated/0/init_boot.img）: " IMG
    [ ! -f "$IMG" ] && err "镜像文件不存在"

    get_slot

    read -rp "刷入 init_boot 还是 boot？[init/boot]: " TYPE
    case "$TYPE" in
        init) PARTITION="init_boot_$SLOT" ;;
        boot) PARTITION="boot_$SLOT" ;;
        *) err "输入错误" ;;
    esac

    info "刷入分区：$PARTITION"
    $FASTBOOT -s $TARGET_DEVICE flash "$PARTITION" "$IMG"
    ok "刷入完成"
}

# ========= 解锁 Bootloader =========
unlock_bl() {
    info "即将解锁 Bootloader（会清空数据）"
    read -rp "确认解锁？输入 YES: " CONFIRM
    [ "$CONFIRM" != "YES" ] && err "已取消"

    $FASTBOOT flashing unlock
    ok "已发送解锁指令，请在手机上确认"
}

# ========= 菜单 =========
menu() {
    clear
    echo "======== OnePlus Fastboot Tool ========"
    echo "1. 解锁 Bootloader"
    echo "2. 刷入 init_boot / boot"
    echo "0. 退出"
    echo "======================================"
    read -rp "请选择: " CHOICE

    case "$CHOICE" in
        1) unlock_bl ;;
        2) flash_image ;;
        0) exit 0 ;;
        *) err "无效选择" ;;
    esac
}

# ========= 主入口 =========
check_fastboot
get_device
while true; do
    menu
done
