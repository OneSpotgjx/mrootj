#!/data/data/com.termux/files/usr/bin/bash
# 安卓Fastboot工具箱（锁定单设备版，优化依赖安装）
# 核心流程：安装依赖 → 检查设备状态 → 帮助进入fastboot → 选设备 → 选VID → 解锁 → 选分区 → 备份 → 刷入 → 重启
# 特性：选定第一台设备后全程锁定；仅在依赖缺失时执行安装，避免重复

# 常量定义
BACKUP_DIR="$HOME/fastboot_backup"
# 全局变量（锁定第一台设备）
TARGET_DEVICE=""
SELECTED_VID=""
SELECTED_PARTITION=""
DEVICE_STATE=""  # 设备状态：recovery, fastboot, normal, unauthorized, offline

# 1. 安装依赖（仅在缺失时执行，避免重复安装）
install_deps() {
    echo -e "\033[32m=== 步骤1：安装必要依赖 ===\033[0m"
    
    # 检测核心工具是否已安装
    local deps_missing=()
    
    if ! command -v fastboot >/dev/null 2>&1; then
        deps_missing+=("android-tools")
        echo "❌ fastboot 未安装"
    else
        echo "✅ fastboot 已安装"
    fi
    
    if ! command -v adb >/dev/null 2>&1; then
        deps_missing+=("android-tools")
        echo "❌ adb 未安装"
    else
        echo "✅ adb 已安装"
    fi
    
    if ! command -v termux-usb >/dev/null 2>&1; then
        deps_missing+=("termux-api")
        echo "❌ termux-usb 未安装"
    else
        echo "✅ termux-usb 已安装"
    fi
    
    # 去重并安装缺失的依赖
    deps_missing=($(echo "${deps_missing[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    if [ ${#deps_missing[@]} -gt 0 ]; then
        echo -e "\n📦 安装缺失的依赖包..."
        pkg update -y && pkg upgrade -y
        pkg install -y "${deps_missing[@]}"
        
        # 验证安装结果
        if command -v fastboot >/dev/null 2>&1 && command -v adb >/dev/null 2>&1 && command -v termux-usb >/dev/null 2>&1; then
            echo "✅ 所有依赖安装完成"
        else
            echo "❌ 依赖安装失败，请手动运行：pkg install android-tools termux-api"
            exit 1
        fi
    else
        echo "✅ 所有依赖已就绪"
    fi
    
    # 请求USB权限
    echo -e "\n🔐 请求USB访问权限..."
    if termux-usb -r >/dev/null 2>&1; then
        echo "✅ 请在手机上弹出的窗口中授权USB访问"
        sleep 3  # 给用户时间点击授权
    else
        echo "⚠️  USB权限请求失败，请手动授权"
        echo "请在Termux弹出的对话框中授权USB访问"
        echo "或进入手机设置 → 应用 → Termux → 权限 → 开启USB权限"
    fi
    
    # 确保备份目录存在
    mkdir -p "$BACKUP_DIR"
    echo -e "\n📁 备份目录: $BACKUP_DIR"
}

# 2. 检测设备状态并帮助进入fastboot模式
check_device_and_help() {
    echo -e "\n\033[32m=== 步骤2：检查设备状态 ===\033[0m"
    
    # 首先检查fastboot设备
    echo -e "\n🔍 检测fastboot设备..."
    fastboot_devices=$(fastboot devices 2>/dev/null | grep -v "List of devices attached")
    
    if [ -n "$fastboot_devices" ]; then
        echo "✅ 已检测到设备处于fastboot模式"
        echo "连接的fastboot设备:"
        echo "$fastboot_devices"
        return 0
    fi
    
    # 如果没有fastboot设备，检查ADB设备
    echo -e "\n🔍 检测ADB设备..."
    adb_devices=$(adb devices 2>/dev/null | tail -n +2 | grep -v "List of devices attached")
    
    if [ -n "$adb_devices" ]; then
        echo "⚠️  设备处于Android系统模式（未在fastboot模式）"
        echo "连接的ADB设备:"
        echo "$adb_devices"
        
        # 解析设备状态
        device_line=$(echo "$adb_devices" | head -1)
        if echo "$device_line" | grep -q "unauthorized"; then
            DEVICE_STATE="unauthorized"
            echo "❌ 设备未授权ADB调试"
            show_authorization_help
            return 1
        elif echo "$device_line" | grep -q "offline"; then
            DEVICE_STATE="offline"
            echo "❌ 设备处于离线状态"
            show_offline_help
            return 1
        else
            DEVICE_STATE="normal"
            echo "✅ 设备已连接并授权ADB调试"
            show_fastboot_help
            return 1
        fi
    else
        echo "❌ 未检测到任何连接的Android设备"
        show_no_device_help
        return 1
    fi
}

# 显示ADB授权帮助
show_authorization_help() {
    echo -e "\n📱 如何授权ADB调试："
    echo "1. 确保手机上已开启「开发者选项」"
    echo "   （设置 → 关于手机 → 连续点击版本号7次）"
    echo "2. 返回设置 → 系统 → 开发者选项"
    echo "3. 开启「USB调试」开关"
    echo "4. 连接USB后，手机上会弹出授权对话框"
    echo "5. 勾选「始终允许此计算机」并点击「确定」"
    echo "6. 等待5秒，然后按回车键继续..."
    read -p ""
    
    # 重新检测
    echo -e "\n🔄 重新检测设备..."
    check_device_and_help
}

# 显示离线设备帮助
show_offline_help() {
    echo -e "\n🔌 设备离线解决方法："
    echo "1. 重新拔插USB线"
    echo "2. 在手机上切换USB连接模式："
    echo "   - 从通知栏选择「文件传输」或「MTP」模式"
    echo "   - 不要选择「仅充电」模式"
    echo "3. 重新运行此脚本"
    exit 1
}

# 显示无设备连接帮助
show_no_device_help() {
    echo -e "\n🔍 未检测到设备可能的原因："
    echo "1. USB线连接问题："
    echo "   - 使用原装或支持数据传输的USB线"
    echo "   - 尝试更换USB端口"
    echo "   - 确保双C线支持数据传输（非仅充电）"
    echo "2. 手机设置问题："
    echo "   - 打开「开发者选项」（关于手机 → 连续点击版本号）"
    echo "   - 开启「USB调试」"
    echo "   - 开启「OEM解锁」（如果还没解锁BL）"
    echo "3. Termux权限问题："
    echo "   - 确保Termux有USB访问权限"
    echo "   - 重启Termux重新授权"
    echo "4. 硬件问题："
    echo "   - 确保操作手机支持USB OTG功能"
    echo "   - 尝试用电脑连接测试线缆"
    
    echo -e "\n💡 尝试以下命令检查连接："
    echo "1. 重新请求USB权限: termux-usb -r"
    echo "2. 列出USB设备: termux-usb -l"
    echo "3. 检查ADB设备: adb devices"
    echo "4. 检查fastboot设备: fastboot devices"
    
    echo -e "\n是否要重新检测设备？(y/n)"
    read -p "选择: " retry_choice
    if [ "$retry_choice" = "y" ]; then
        echo -e "\n🔄 重新检测设备..."
        check_device_and_help
    else
        echo "退出脚本"
        exit 1
    fi
}

# 显示进入fastboot帮助
show_fastboot_help() {
    echo -e "\n⚡ 如何进入fastboot模式："
    echo ""
    echo "方法1：通过ADB命令进入（推荐）"
    echo "   在手机已连接并授权的情况下，运行："
    echo "   adb reboot bootloader"
    echo ""
    echo "方法2：物理按键组合（通用方法）"
    echo "   1. 完全关机（长按电源键 → 关机）"
    echo "   2. 同时按住「音量下键 + 电源键」"
    echo "   3. 看到fastboot界面后松开"
    echo ""
    echo "方法3：一加专用方法"
    echo "   1. 关机"
    echo "   2. 同时按住「音量上键 + 音量下键 + 电源键」"
    echo "   3. 看到fastboot界面后松开"
    
    echo -e "\n🔧 选择进入fastboot的方法："
    echo "1. 使用ADB命令自动进入fastboot"
    echo "2. 手动按键进入（按上述方法操作）"
    echo "3. 查看详细的按键进入指南"
    echo "4. 退出脚本"
    
    read -p "请输入选项 (1-4): " fastboot_method
    
    case $fastboot_method in
        1)
            echo -e "\n正在通过ADB重启到fastboot模式..."
            adb reboot bootloader
            echo "✅ 已发送重启命令，请等待设备进入fastboot模式"
            echo "⏳ 等待15秒让设备切换模式..."
            sleep 15
            
            # 检查是否成功进入fastboot
            echo -e "\n检查fastboot设备..."
            fastboot_devices=$(fastboot devices 2>/dev/null | grep -v "List of devices attached")
            if [ -n "$fastboot_devices" ]; then
                echo "✅ 成功进入fastboot模式！"
                echo "检测到的设备："
                echo "$fastboot_devices"
            else
                echo "❌ 仍未检测到fastboot设备"
                echo "请手动按键进入fastboot模式"
                show_fastboot_help
            fi
            ;;
        2)
            echo -e "\n请按照上述方法手动进入fastboot模式"
            echo "完成后按回车键继续..."
            read -p ""
            
            # 检查是否成功
            fastboot_devices=$(fastboot devices 2>/dev/null | grep -v "List of devices attached")
            if [ -n "$fastboot_devices" ]; then
                echo "✅ 成功进入fastboot模式！"
            else
                echo "❌ 未检测到fastboot设备"
                echo "是否要重新尝试？(y/n)"
                read -p "选择: " retry_choice
                if [ "$retry_choice" = "y" ]; then
                    show_fastboot_help
                else
                    echo "退出脚本"
                    exit 1
                fi
            fi
            ;;
        3)
            show_detailed_fastboot_guide
            echo -e "\n按回车键返回..."
            read -p ""
            show_fastboot_help
            ;;
        4)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "❌ 无效选择，返回"
            show_fastboot_help
            ;;
    esac
}

# 显示详细的fastboot指南
show_detailed_fastboot_guide() {
    echo -e "\n📖 详细的fastboot模式进入指南"
    echo "========================================"
    echo ""
    echo "💡 什么是fastboot模式？"
    echo "   fastboot是Android设备的刷机模式，用于刷写系统镜像、解锁BL等操作"
    echo ""
    echo "📱 通用进入方法："
    echo "   1. 确保手机已完全关机"
    echo "   2. 同时按住「音量下键 + 电源键」"
    echo "   3. 保持按住直到看到fastboot界面（通常是安卓机器人或品牌logo）"
    echo "   4. 松开按键"
    echo ""
    echo "🎯 一加手机专用方法："
    echo "   方法A：音量上下键 + 电源键"
    echo "   方法B：关机后连接电脑，执行：adb reboot bootloader"
    echo ""
    echo "⚡ 其他品牌参考："
    echo "   - 小米/Redmi：音量下键 + 电源键"
    echo "   - 三星：音量下键 + Bixby键 + 电源键"
    echo "   - 华为：音量下键 + 电源键（连接电脑）"
    echo "   - OPPO/真我：音量上下键 + 电源键"
    echo ""
    echo "🔍 如何判断已进入fastboot："
    echo "   ✓ 屏幕显示fastboot字样或安卓机器人"
    echo "   ✓ 屏幕可能显示「Start」或其他fastboot菜单"
    echo "   ✓ 通常屏幕不会显示完整的系统界面"
    echo ""
    echo "⚠️  常见问题："
    echo "   Q: 按键没反应怎么办？"
    echo "   A: 确保手机完全关机，可以长按电源键10秒强制关机后再试"
    echo ""
    echo "   Q: 进入的是Recovery模式怎么办？"
    echo "   A: 尝试「音量上键 + 电源键」进入Recovery后，选择「Reboot to bootloader」"
    echo ""
    echo "   Q: 屏幕一直黑屏？"
    echo "   A: 可能是电池没电，充电后再试"
}

# 3. 检测设备+强制锁定第一台（用户输入1即可选中，全程绑定）
select_first_device() {
    echo -e "\n\033[32m=== 步骤3：检测设备并锁定第一台 ===\033[0m"
    echo "⚠️  被控机需进入fastboot模式，OTG已连接，Termux已获取USB权限"

    # 全量检测设备
    DEVICES=$(fastboot devices | grep -v "List of devices attached")
    if [ -z "$DEVICES" ]; then
        echo "❌ 未检测到任何fastboot设备！"
        echo "请确保："
        echo "1. 设备已进入fastboot模式"
        echo "2. USB线连接正常"
        echo "3. Termux已获得USB权限"
        echo ""
        echo "是否要重新检测设备状态？(y/n)"
        read -p "选择: " retry_choice
        if [ "$retry_choice" = "y" ]; then
            check_device_and_help
            # 重新检测fastboot设备
            DEVICES=$(fastboot devices | grep -v "List of devices attached")
            if [ -z "$DEVICES" ]; then
                echo "❌ 仍无fastboot设备，退出"
                exit 1
            fi
        else
            echo "退出脚本"
            exit 1
        fi
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

# 4. 选择VID（适配不同品牌）
select_vid() {
    echo -e "\n\033[32m=== 步骤4：选择设备USB供应商ID（VID）===\033[0m"
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

# 5. 输入解锁命令（仅针对锁定设备）- 修改版
input_unlock_cmd() {
    echo -e "\n\033[32m=== 步骤5：解锁 $TARGET_DEVICE ===\033[0m"
    echo "💡 选择解锁方式："
    echo "1. 标准解锁 (fastboot flashing unlock) - 适用于大多数一加/OPPO设备"
    echo "2. 老机型解锁 (fastboot oem unlock)"
    echo "3. 自定义解锁命令"
    echo "⚠️  解锁会清除设备所有数据！"
    
    read -p "选择解锁方式 (1/2/3): " unlock_type
    
    case $unlock_type in
        1)
            echo "执行标准解锁命令..."
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE flashing unlock
            ;;
        2)
            echo "执行老机型解锁命令..."
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE oem unlock
            ;;
        3)
            read -p "输入完整解锁命令：" unlock_cmd
            # 移除eval，直接执行命令
            $unlock_cmd
            ;;
        *)
            echo "❌ 无效选择，退出"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✅ 解锁完成！请重启设备并重新进入fastboot模式"
        echo "⏳ 等待设备重启..."
        sleep 5
        
        # 提示用户如何重新进入fastboot
        echo -e "\n📱 解锁后需要重新进入fastboot模式："
        echo "方法1：使用ADB命令"
        echo "   在设备重启进入系统后，运行：adb reboot bootloader"
        echo ""
        echo "方法2：手动按键"
        echo "   完全关机 → 按住音量下键 + 电源键"
        echo ""
        read -p "已重启并进入fastboot？（y=继续，n=退出）：" rst_confirm
        [ "$rst_confirm" != "y" ] && echo "退出" && exit 1
    else
        echo "❌ 解锁失败，请检查设备和连接"
        exit 1
    fi
}

# 6. 选择分区（boot/init_boot）
select_partition() {
    echo -e "\n\033[32m=== 步骤6：选择分区类型 ===\033[0m"
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

# 7. 选择是否备份原厂分区（仅针对锁定设备）- 改进版
backup_partition() {
    echo -e "\n\033[32m=== 步骤7：备份原厂 $SELECTED_PARTITION 分区 ===\033[0m"
    read -p "是否备份？（y=备份，n=跳过）：" backup_choice
    [ "$backup_choice" != "y" ] && echo "✅ 跳过备份"; return

    backup_file="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}_$(date +%Y%m%d_%H%M%S).img"
    
    # 尝试获取当前slot
    slot=$(fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null | grep -o "[ab]" | head -1)
    
    if [ -n "$slot" ]; then
        echo "检测到A/B分区，当前slot: $slot"
        partition_name="${SELECTED_PARTITION}${slot}"
    else
        echo "未检测到A/B分区，使用基本分区名"
        partition_name="$SELECTED_PARTITION"
    fi
    
    echo "备份到：$backup_file"
    echo "正在备份 $partition_name 分区..."
    
    # 尝试fastboot dump备份（适用于支持此命令的设备）
    if fastboot -i $SELECTED_VID -s $TARGET_DEVICE dump $partition_name $backup_file 2>/dev/null; then
        echo "✅ 备份完成！文件: $backup_file"
        echo "文件大小: $(du -h "$backup_file" | cut -f1)"
    else
        echo "⚠️  fastboot dump失败，尝试通过recovery备份..."
        echo "请手动进入TWRP/OrangeFox等recovery备份boot分区"
        echo "或跳过备份继续操作"
        read -p "是否继续？（y=继续，n=退出）" continue_choice
        [ "$continue_choice" != "y" ] && echo "退出" && exit 1
    fi
}

# 8. 刷入镜像+重启（仅针对锁定设备）
flash_and_reboot() {
    echo -e "\n\033[32m=== 步骤8：刷入镜像并重启 $TARGET_DEVICE ===\033[0m"
    read -p "输入修补后镜像完整路径：" img_path
    [ ! -f "$img_path" ] && echo "❌ 文件不存在，退出"; exit 1

    echo "开始刷入 $SELECTED_PARTITION 分区..."
    fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION $img_path
    if [ $? -eq 0 ]; then
        echo "✅ 刷入成功！正在重启设备..."
        fastboot -i $SELECTED_VID -s $TARGET_DEVICE reboot
        echo "✅ 所有操作完成！设备重启中"
        echo "⏳ 首次启动可能需要较长时间，请耐心等待"
    else
        echo "❌ 刷入失败，请排查BL解锁/镜像匹配/OTG连接"
        exit 1
    fi
}

# 主流程（全程锁定第一台设备）
main() {
    clear
    echo "========================================"
    echo "   安卓Fastboot工具箱 v2.0"
    echo "   支持设备状态检测和fastboot引导"
    echo "========================================"
    echo ""
    
    # 步骤1：安装依赖（必须先安装，才能检测设备）
    install_deps
    
    # 步骤2：检查设备状态并帮助进入fastboot
    check_device_and_help
    
    # 步骤3：选择设备
    select_first_device
    
    # 步骤4：选择VID
    select_vid
    
    # 步骤5：解锁
    input_unlock_cmd
    
    # 步骤6：选择分区
    select_partition
    
    # 步骤7：备份
    backup_partition
    
    # 步骤8：刷入镜像
    flash_and_reboot
}

# 异常处理
trap 'echo -e "\n❌ 脚本被中断，操作未完成"; exit 1' INT TERM

main