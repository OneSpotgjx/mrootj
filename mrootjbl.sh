#!/data/data/com.termux/files/usr/bin/bash
# 安卓Fastboot工具箱（锁定单设备版，优化依赖安装）
# 核心流程：安装依赖（仅首次） → 选第一台设备 → 选VID → 解锁 → 选分区 → 备份 → 刷入 → 重启
# 特性：选定第一台设备后全程锁定；仅在依赖缺失时执行安装，避免重复

# 常量定义
BACKUP_DIR="$HOME/fastboot_backup"
# 全局变量（锁定第一台设备）
TARGET_DEVICE=""
SELECTED_VID=""
SELECTED_PARTITION=""

# 1. 安装依赖（仅在缺失时执行，避免重复安装）
install_deps() {
    echo -e "\033[32m=== 步骤1：检查并安装必要依赖（仅首次运行安装）===\033[0m"
    # 检测核心工具是否已安装
    local deps_ok=1
    if ! command -v fastboot >/dev/null 2>&1; then deps_ok=0; fi
    if ! command -v termux-usb >/dev/null 2>&1; then deps_ok=0; fi
    if ! command -v lsusb >/dev/null 2>&1; then deps_ok=0; fi

    if [ $deps_ok -eq 0 ]; then
        # 依赖缺失，执行安装
        pkg update -y && pkg upgrade -y && pkg install android-tools termux-api usbutils -y
        echo "✅ 依赖安装完成"
    else
        echo "✅ 依赖已就绪，跳过重复安装"
    fi
    # 确保备份目录存在（无论是否安装依赖）
    mkdir -p $BACKUP_DIR
    echo "备份目录：$BACKUP_DIR"
    echo -e "\n当前USB设备列表："
    lsusb
}

# 2. 检测设备+强制锁定第一台（用户输入1即可选中，全程绑定）
select_first_device() {
    echo -e "\n\033[32m=== 步骤2：检测设备并锁定第一台 ===\033[0m"
    echo "⚠️  被控机需进入fastboot模式，OTG已连接，Termux已获取USB权限"

    # 全量检测设备
    DEVICES=$(fastboot devices | grep -v "List of devices attached")
    if [ -z "$DEVICES" ]; then
        echo "❌ 未检测到任何fastboot设备！"
        exit 1
    fi

    # 列出设备并标注序号，强调第一台选项
    echo -e "\n✅ 检测到以下设备："
    echo "$DEVICES" | awk '{print NR ". " $0}'
    readarray -t DEVICE_ARRAY <<< "$DEVICES"

    # 引导用户选第一台，也支持选其他，但选定后锁定
    read -p "请输入设备序号（输入1直接选中第一台，选定后全程锁定）：" device_index
    if ! [[ "$device_index" =~ ^[0-9]+$ ]] || [ "$device_index" -lt 1 ] || [ "$device_index" -gt "${#DEVICE_ARRAY[@]}" ]; then
        echo "❌ 无效序号，退出"
        exit 1
    fi

    # 绑定选中的设备（永久锁定）
    selected_line="${DEVICE_ARRAY[$((device_index-1))]}"
    TARGET_DEVICE=$(echo "$selected_line" | awk '{print $1}')
    echo -e "\033[32m✅ 已锁定目标设备：$TARGET_DEVICE\033[0m"
    echo "⚠️  后续所有操作仅针对此设备，无二次选择"
}

# 3. 选择VID（适配不同品牌）
select_vid() {
    echo -e "\n\033[32m=== 步骤3：选择设备USB供应商ID（VID）===\033[0m"
    echo "💡 常见VID推荐："
    echo "1. 一加/OPPO/真我：0x2a70"
    echo "2. 小米/Redmi：0x2717"
    echo "3. 三星：0x04E8"
    echo "4. 华为：0x12D1"
    echo "0. 自定义VID（格式0xXXXX）"
    read -p "输入VID序号/0：" vid_choice

    case $vid_choice in
        1) SELECTED_VID="0x2a70" ;;
        2) SELECTED_VID="0x2717" ;;
        3) SELECTED_VID="0x04E8" ;;
        4) SELECTED_VID="0x12D1" ;;
        0)
            read -p "输入自定义VID：" custom_vid
            if ! [[ "$custom_vid" =~ ^0x[0-9A-Fa-f]{4}$ ]]; then
                echo "❌ 格式错误，退出"
                exit 1
            fi
            SELECTED_VID="$custom_vid"
            ;;
        *) echo "❌ 无效选择，退出"; exit 1 ;;
    esac

    # 验证锁定设备+VID的通信
    echo -e "\n验证 $SELECTED_VID + $TARGET_DEVICE 通信..."
    if fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar product >/dev/null 2>&1; then
        echo "✅ 通信验证成功！"
    else
        echo "❌ 通信失败，请重新选VID或检查连接"
        exit 1
    fi
}

# 4. 输入解锁命令（仅针对锁定设备）
input_unlock_cmd() {
    echo -e "\n\033[32m=== 步骤4：输入解锁命令（仅针对 $TARGET_DEVICE）===\033[0m"
    echo "💡 示例命令（已自动绑定设备+VID）："
    echo "新机型：fastboot -i $SELECTED_VID -s $TARGET_DEVICE flashing unlock"
    echo "老机型：fastboot -i $SELECTED_VID -s $TARGET_DEVICE oem unlock 你的解锁码"
    echo "⚠️  解锁会清除设备所有数据！"
    read -p "输入完整解锁命令：" unlock_cmd
    read -p "确认执行？（y=执行）：" confirm
    [ "$confirm" != "y" ] && echo "退出"; exit 1

    echo -e "\n执行命令：$unlock_cmd"
    eval $unlock_cmd
    echo "✅ 解锁完成！请重启设备并重新进入fastboot模式"
    read -p "已重启并进入fastboot？（y=继续）：" rst_confirm
    [ "$rst_confirm" != "y" ] && echo "退出"; exit 1
}

# 5. 选择分区（boot/init_boot）
select_partition() {
    echo -e "\n\033[32m=== 步骤5：选择分区类型 ===\033[0m"
    echo "1. 新机型（Android13+/ColorOS16+ → init_boot）"
    echo "2. 老机型（Android12及以下 → boot）"
    read -p "输入选项1/2：" part_choice
    case $part_choice in
        1) SELECTED_PARTITION="init_boot" ;;
        2) SELECTED_PARTITION="boot" ;;
        *) echo "❌ 无效选择，退出"; exit 1 ;;
    esac
    echo -e "✅ 选定分区：$SELECTED_PARTITION"
}

# 6. 选择是否备份原厂分区（仅针对锁定设备）
backup_partition() {
    echo -e "\n\033[32m=== 步骤6：备份原厂 $SELECTED_PARTITION 分区 ===\033[0m"
    read -p "是否备份？（y=备份，n=跳过）：" backup_choice
    [ "$backup_choice" != "y" ] && echo "✅ 跳过备份"; return

    backup_file="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}.img"
    slot=$(fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null | grep -o "[ab]")
    echo "备份到：$backup_file"
    fastboot -i $SELECTED_VID -s $TARGET_DEVICE dump ${SELECTED_PARTITION}${slot} $backup_file
    echo "✅ 备份完成！"
}

# 7. 刷入镜像+重启（仅针对锁定设备）
flash_and_reboot() {
    echo -e "\n\033[32m=== 步骤7：刷入镜像并重启 $TARGET_DEVICE ===\033[0m"
    read -p "输入修补后镜像完整路径：" img_path
    [ ! -f "$img_path" ] && echo "❌ 文件不存在，退出"; exit 1

    echo "开始刷入 $SELECTED_PARTITION 分区..."
    fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION $img_path
    if [ $? -eq 0 ]; then
        echo "✅ 刷入成功！正在重启设备..."
        fastboot -i $SELECTED_VID -s $TARGET_DEVICE reboot
        echo "✅ 所有操作完成！设备重启中"
    else
        echo "❌ 刷入失败，请排查BL解锁/镜像匹配/OTG连接"
        exit 1
    fi
}

# 主流程（全程锁定第一台设备）
main() {
    install_deps
    select_first_device
    select_vid
    input_unlock_cmd
    select_partition
    backup_partition
    flash_and_reboot
}

main
