#!/data/data/com.termux/files/usr/bin/bash
# ====================================================
# 一加Fastboot工具箱 v2.0 - 菜单版
# 作者: 复活nb666
# ====================================================
# === 自动配置“一加工具箱”快捷命令（只在第一次运行时执行） ===

TOOL_NAME="一加工具箱"
SCRIPT_PATH="$(realpath "$0")"
BASHRC="$HOME/.bashrc"
MARKER="# OnePlus Toolbox Alias"

if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    echo ""
    echo "🔧 正在为你配置快捷启动命令：$TOOL_NAME"

    {
        echo ""
        echo "$MARKER"
        echo "alias $TOOL_NAME='bash \"$SCRIPT_PATH\"'"
    } >> "$BASHRC"

    echo "✅ 已配置完成"
    echo "👉 以后重新打开 Termux 后，直接输入：$TOOL_NAME"
    echo "👉 当前终端请执行：source ~/.bashrc"
    echo ""
fi


# 常量定义
BACKUP_DIR="$HOME/fastboot_backup"
LOG_FILE="$HOME/fastboot_tool.log"
VERSION="2.0"

# 全局变量
TARGET_DEVICE=""
SELECTED_VID=""
SELECTED_PARTITION=""
DEVICE_STATE=""
CURRENT_SLOT=""  # 添加当前slot变量

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# 显示标题
show_header() {
    clear
    echo -e "${PURPLE}"
    echo "========================================"
    echo "    一加Fastboot工具箱 v$VERSION"
    echo "    作者: 复活nb666"
    echo "    启动时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo -e "${NC}"
    echo -e "${CYAN}笔底相思字生烫，眼底缝光凝霜${NC}"
    echo -e "${CYAN}爱如苍痕悄爬满，心似古井忽生澜${NC}"
    echo ""
}

# 显示菜单
show_menu() {
    echo -e "${GREEN}=== 主菜单 ===${NC}"
    echo ""
    echo "  1. 安装必要依赖"
    echo "  2. 检测设备状态"
    echo "  3. 帮助进入fastboot模式"
    echo "  4. 选择并锁定设备"
    echo "  5. 选择VID（设备品牌）"
    echo "  6. 解锁Bootloader"
    echo "  7. 选择分区类型"
    echo "  8. 备份原厂分区"
    echo "  9. 刷入镜像文件"
    echo "  10. 一键自动流程"
    echo "  11. 查看设备信息"
    echo "  12. 查看备份文件"
    echo "  13. 清理临时文件"
    echo "  14. 查看操作日志"
    echo "  0. 退出系统"
    echo ""
    echo -e "${YELLOW}当前状态:${NC}"
    if [ -n "$TARGET_DEVICE" ]; then
        echo -e "  📱 设备: ${GREEN}$TARGET_DEVICE${NC}"
    else
        echo -e "  📱 设备: ${RED}未选择${NC}"
    fi
    if [ -n "$SELECTED_VID" ]; then
        echo -e "  🔧 VID: ${GREEN}$SELECTED_VID${NC}"
    else
        echo -e "  🔧 VID: ${RED}未选择${NC}"
    fi
    if [ -n "$SELECTED_PARTITION" ]; then
        echo -e "  💾 分区: ${GREEN}$SELECTED_PARTITION${NC}"
    else
        echo -e "  💾 分区: ${RED}未选择${NC}"
    fi
    if [ -n "$CURRENT_SLOT" ]; then
        echo -e "  🔄 当前Slot: ${GREEN}$CURRENT_SLOT${NC}"
    fi
    echo ""
    echo -e "${BLUE}请输入您的选择 [0-14]:${NC} "
}

# 1. 安装依赖
install_deps() {
    log "=== 开始安装依赖 ==="
    echo -e "\n${GREEN}=== 步骤1：安装必要依赖 ===${NC}"
    
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
    
    deps_missing=($(echo "${deps_missing[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    if [ ${#deps_missing[@]} -gt 0 ]; then
        echo -e "\n📦 安装缺失的依赖包: ${deps_missing[*]}"
        echo "这可能需要几分钟时间，请耐心等待..."
        
        if pkg update -y && pkg upgrade -y && pkg install -y "${deps_missing[@]}"; then
            echo "✅ 所有依赖安装完成"
            log "依赖安装成功"
        else
            echo "❌ 依赖安装失败"
            log "依赖安装失败"
            return 1
        fi
    else
        echo "✅ 所有依赖已就绪"
    fi
    
    # 请求USB权限
    echo -e "\n🔐 请求USB访问权限..."
    if termux-usb -r >/dev/null 2>&1; then
        echo "✅ 请在手机上弹出的窗口中授权USB访问"
        sleep 3
        log "USB权限已请求"
    else
        echo "⚠️  USB权限请求失败，请手动授权"
        log "USB权限请求失败"
    fi
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    echo -e "\n📁 备份目录: $BACKUP_DIR"
    
    echo -e "\n✅ 依赖安装完成"
    read -p "按回车键继续..."
}

# 2. 检测设备状态
check_device_status() {
    log "=== 开始检测设备状态 ==="
    echo -e "\n${GREEN}=== 设备状态检测 ===${NC}"
    
    echo "🔍 检测fastboot设备..."
    fastboot_devices=$(fastboot devices 2>/dev/null | grep -v "List of devices attached")
    
    if [ -n "$fastboot_devices" ]; then
        echo "✅ 检测到设备处于fastboot模式"
        echo "$fastboot_devices"
        DEVICE_STATE="fastboot"
        
        # 检测当前slot（如果有选择设备）
        if [ -n "$TARGET_DEVICE" ] && [ -n "$SELECTED_VID" ]; then
            echo "🔍 检测A/B分区状态..."
            slot_info=$(fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null)
            if echo "$slot_info" | grep -q "current-slot: [ab]"; then
                CURRENT_SLOT=$(echo "$slot_info" | grep -o "[ab]" | head -1)
                echo "📊 当前slot: $CURRENT_SLOT"
                log "检测到当前slot: $CURRENT_SLOT"
            else
                echo "📊 未检测到A/B分区或设备不支持"
                CURRENT_SLOT=""
            fi
        fi
    else
        echo "🔍 检测ADB设备..."
        adb_devices=$(adb devices 2>/dev/null | tail -n +2 | grep -v "List of devices attached")
        
        if [ -n "$adb_devices" ]; then
            device_line=$(echo "$adb_devices" | head -1)
            if echo "$device_line" | grep -q "unauthorized"; then
                DEVICE_STATE="unauthorized"
                echo "❌ 设备未授权ADB调试"
            elif echo "$device_line" | grep -q "offline"; then
                DEVICE_STATE="offline"
                echo "❌ 设备处于离线状态"
            else
                DEVICE_STATE="normal"
                echo "✅ 设备已连接并授权ADB调试"
                echo "$adb_devices"
            fi
        else
            DEVICE_STATE="disconnected"
            echo "❌ 未检测到任何连接的Android设备"
        fi
    fi
    
    echo -e "\n📊 设备状态: $DEVICE_STATE"
    log "设备状态: $DEVICE_STATE"
    
    read -p "按回车键继续..."
}

# 3. 帮助进入fastboot模式
help_enter_fastboot() {
    log "=== 显示fastboot帮助 ==="
    echo -e "\n${GREEN}=== 进入fastboot模式帮助 ===${NC}"
    
    echo "方法1：通过ADB命令（推荐）"
    echo "  在手机已连接并授权的情况下，运行："
    echo "  adb reboot bootloader"
    echo ""
    echo "方法2：物理按键组合（通用方法）"
    echo "  1. 完全关机（长按电源键 → 关机）"
    echo "  2. 同时按住「音量下键 + 电源键」"
    echo "  3. 看到fastboot界面后松开"
    echo ""
    echo "方法3：一加专用方法"
    echo "  1. 关机"
    echo "  2. 同时按住「音量上键 + 音量下键 + 电源键」"
    echo "  3. 看到fastboot界面后松开"
    echo ""
    echo "方法4：通过Recovery进入"
    echo "  1. 进入Recovery模式（音量上+电源）"
    echo "  2. 选择「Advanced」→「Reboot to bootloader」"
    
    echo -e "\n是否要通过ADB自动进入fastboot？(y/n)"
    read -p "选择: " choice
    
    if [ "$choice" = "y" ]; then
        echo "正在通过ADB重启到fastboot模式..."
        adb reboot bootloader
        echo "✅ 已发送重启命令，请等待15秒..."
        sleep 15
        log "已发送ADB重启到fastboot命令"
    fi
    
    read -p "按回车键继续..."
}

# 4. 选择并锁定设备
select_and_lock_device() {
    log "=== 开始选择设备 ==="
    echo -e "\n${GREEN}=== 选择并锁定设备 ===${NC}"
    
    DEVICES=$(fastboot devices | grep -v "List of devices attached")
    if [ -z "$DEVICES" ]; then
        echo "❌ 未检测到任何fastboot设备！"
        echo "请确保设备已进入fastboot模式"
        log "未检测到fastboot设备"
        read -p "按回车键返回..."
        return 1
    fi
    
    echo -e "\n✅ 检测到以下设备："
    echo "$DEVICES" | awk '{print NR ". " $0}'
    readarray -t DEVICE_ARRAY <<< "$DEVICES"
    
    read -p "请输入设备序号（选定后全程锁定）：" device_index
    if ! [[ "$device_index" =~ ^[0-9]+$ ]] || [ "$device_index" -lt 1 ] || [ "$device_index" -gt "${#DEVICE_ARRAY[@]}" ]; then
        echo "❌ 无效序号"
        return 1
    fi
    
    selected_line="${DEVICE_ARRAY[$((device_index-1))]}"
    TARGET_DEVICE=$(echo "$selected_line" | awk '{print $1}')
    echo -e "\n✅ 已锁定目标设备：$TARGET_DEVICE"
    log "已选择设备: $TARGET_DEVICE"
    
    # 检测设备是否支持A/B分区
    if [ -n "$SELECTED_VID" ]; then
        echo "🔍 检测设备A/B分区信息..."
        slot_info=$(fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null)
        if echo "$slot_info" | grep -q "current-slot: [ab]"; then
            CURRENT_SLOT=$(echo "$slot_info" | grep -o "[ab]" | head -1)
            echo "✅ 设备支持A/B分区，当前slot: $CURRENT_SLOT"
        else
            echo "⚠️  设备可能不支持A/B分区或无法检测"
            CURRENT_SLOT=""
        fi
    fi
    
    read -p "按回车键继续..."
}

# 5. 选择VID
select_vid_menu() {
    log "=== 开始选择VID ==="
    echo -e "\n${GREEN}=== 选择设备USB供应商ID（VID）===${NC}"
    
    if [ -z "$TARGET_DEVICE" ]; then
        echo "❌ 请先选择设备！"
        read -p "按回车键返回..."
        return 1
    fi
    
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
                echo "❌ 格式错误"
                return 1
            fi
            SELECTED_VID="$custom_vid"
            ;;
        *) echo "❌ 无效选择"; return 1 ;;
    esac
    
    echo -e "\n验证 $SELECTED_VID + $TARGET_DEVICE 通信..."
    if fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar product >/dev/null 2>&1; then
        echo "✅ 通信验证成功！"
        log "VID选择成功: $SELECTED_VID"
        
        # 检测slot信息
        echo "🔍 检测设备A/B分区信息..."
        slot_info=$(fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null)
        if echo "$slot_info" | grep -q "current-slot: [ab]"; then
            CURRENT_SLOT=$(echo "$slot_info" | grep -o "[ab]" | head -1)
            echo "✅ 设备支持A/B分区，当前slot: $CURRENT_SLOT"
        else
            echo "⚠️  设备可能不支持A/B分区或无法检测"
            CURRENT_SLOT=""
        fi
    else
        echo "❌ 通信失败"
        SELECTED_VID=""
    fi
    
    read -p "按回车键继续..."
}

# 6. 解锁Bootloader
unlock_bootloader() {
    log "=== 开始解锁Bootloader ==="
    echo -e "\n${GREEN}=== 解锁Bootloader ===${NC}"
    
    if [ -z "$TARGET_DEVICE" ] || [ -z "$SELECTED_VID" ]; then
        echo "❌ 请先选择设备和VID！"
        read -p "按回车键返回..."
        return 1
    fi
    
    echo "⚠️  警告：解锁Bootloader会清除设备所有数据！"
    echo "⚠️  请确保已备份重要数据！"
    echo ""
    
    echo "选择解锁方式："
    echo "1. 标准解锁 (fastboot flashing unlock)"
    echo "2. 老机型解锁 (fastboot oem unlock)"
    echo "3. 自定义解锁命令"
    read -p "选择 (1/2/3): " unlock_type
    
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
            $unlock_cmd
            ;;
        *)
            echo "❌ 无效选择"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✅ 解锁完成！"
        echo "请重启设备并重新进入fastboot模式"
        log "Bootloader解锁成功"
    else
        echo "❌ 解锁失败"
        log "Bootloader解锁失败"
    fi
    
    read -p "按回车键继续..."
}

# 7. 选择分区类型
select_partition_menu() {
    log "=== 开始选择分区 ==="
    echo -e "\n${GREEN}=== 选择分区类型 ===${NC}"
    
    echo "1. 新机型（Android13+/ColorOS16+ → init_boot）"
    echo "2. 老机型（Android12及以下 → boot）"
    read -p "输入选项1/2：" part_choice
    
    case $part_choice in
        1) SELECTED_PARTITION="init_boot" ;;
        2) SELECTED_PARTITION="boot" ;;
        *) echo "❌ 无效选择"; return 1 ;;
    esac
    
    echo -e "✅ 选定分区：$SELECTED_PARTITION"
    log "选择分区: $SELECTED_PARTITION"
    
    read -p "按回车键继续..."
}

# 8. 备份原厂分区
backup_partition_menu() {
    log "=== 开始备份分区 ==="
    echo -e "\n${GREEN}=== 备份原厂分区 ===${NC}"
    
    if [ -z "$TARGET_DEVICE" ] || [ -z "$SELECTED_VID" ] || [ -z "$SELECTED_PARTITION" ]; then
        echo "❌ 请先选择设备、VID和分区类型！"
        read -p "按回车键返回..."
        return 1
    fi
    
    read -p "是否备份 $SELECTED_PARTITION 分区？(y/n): " backup_choice
    [ "$backup_choice" != "y" ] && echo "✅ 跳过备份" && return 0

    backup_file="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}_$(date +%Y%m%d_%H%M%S).img"
    
    # 检测slot并询问用户
    if [ -n "$CURRENT_SLOT" ]; then
        echo "📊 检测到A/B分区"
        echo "当前slot: $CURRENT_SLOT"
        echo ""
        echo "选择备份方式："
        echo "1. 备份当前slot ($CURRENT_SLOT)"
        echo "2. 备份a分区"
        echo "3. 备份b分区"
        echo "4. 备份所有slot"
        read -p "选择 (1/2/3/4): " backup_slot_choice
        
        case $backup_slot_choice in
            1)
                slot_to_backup="$CURRENT_SLOT"
                echo "备份当前slot ($CURRENT_SLOT)..."
                ;;
            2)
                slot_to_backup="a"
                echo "备份a分区..."
                ;;
            3)
                slot_to_backup="b"
                echo "备份b分区..."
                ;;
            4)
                echo "备份所有slot（a和b）..."
                # 备份a分区
                backup_file_a="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}_slot-a_$(date +%Y%m%d_%H%M%S).img"
                echo "备份a分区到: $backup_file_a"
                if fastboot -i $SELECTED_VID -s $TARGET_DEVICE dump "${SELECTED_PARTITION}a" "$backup_file_a" 2>/dev/null; then
                    echo "✅ a分区备份完成！"
                    log "a分区备份成功: $backup_file_a"
                else
                    echo "❌ a分区备份失败"
                fi
                
                # 备份b分区
                backup_file_b="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}_slot-b_$(date +%Y%m%d_%H%M%S).img"
                echo "备份b分区到: $backup_file_b"
                if fastboot -i $SELECTED_VID -s $TARGET_DEVICE dump "${SELECTED_PARTITION}b" "$backup_file_b" 2>/dev/null; then
                    echo "✅ b分区备份完成！"
                    log "b分区备份成功: $backup_file_b"
                else
                    echo "❌ b分区备份失败"
                fi
                
                echo "✅ 所有slot备份完成"
                read -p "按回车键继续..."
                return 0
                ;;
            *)
                echo "❌ 无效选择，默认备份当前slot"
                slot_to_backup="$CURRENT_SLOT"
                ;;
        esac
        
        partition_name="${SELECTED_PARTITION}${slot_to_backup}"
        backup_file="$BACKUP_DIR/backup_${SELECTED_PARTITION}_${TARGET_DEVICE}_slot-${slot_to_backup}_$(date +%Y%m%d_%H%M%S).img"
    else
        echo "未检测到A/B分区"
        partition_name="$SELECTED_PARTITION"
    fi
    
    echo "备份到：$backup_file"
    
    if fastboot -i $SELECTED_VID -s $TARGET_DEVICE dump $partition_name $backup_file 2>/dev/null; then
        echo "✅ 备份完成！文件: $backup_file"
        if [ -f "$backup_file" ]; then
            echo "文件大小: $(du -h "$backup_file" 2>/dev/null | cut -f1)"
        fi
        log "分区备份成功: $backup_file"
    else
        echo "❌ 备份失败"
        log "分区备份失败"
    fi
    
    read -p "按回车键继续..."
}

# 9. 刷入镜像文件（添加A/B分区支持）
flash_image() {
    log "=== 开始刷入镜像 ==="
    echo -e "\n${GREEN}=== 刷入镜像文件 ===${NC}"
    
    if [ -z "$TARGET_DEVICE" ] || [ -z "$SELECTED_VID" ] || [ -z "$SELECTED_PARTITION" ]; then
        echo "❌ 请先选择设备、VID和分区类型！"
        read -p "按回车键返回..."
        return 1
    fi
    
    # 检查设备是否支持A/B分区
    local has_ab_slots="false"
    if [ -n "$CURRENT_SLOT" ]; then
        has_ab_slots="true"
        echo "✅ 设备支持A/B分区"
        echo "📊 当前slot: $CURRENT_SLOT"
    else
        echo "⚠️  设备可能不支持A/B分区"
    fi
    
    echo ""
    echo "当前目录下的镜像文件："
    ls -la *.img *.bin 2>/dev/null | head -20 || echo "未找到.img或.bin文件"
    
    echo ""
    read -p "输入镜像完整路径：" img_path
    if [ ! -f "$img_path" ]; then
        echo "❌ 文件不存在: $img_path"
        read -p "按回车键返回..."
        return 1
    fi
    
    # 选择刷入方式
    echo ""
    echo "${YELLOW}=== 选择刷入方式 ===${NC}"
    if [ "$has_ab_slots" = "true" ]; then
        echo "1. 刷入当前活动slot ($CURRENT_SLOT)"
        echo "2. 刷入a分区"
        echo "3. 刷入b分区"
        echo "4. 刷入两个分区（a和b都刷入）"
        echo "5. 切换活动slot后刷入"
        echo "6. 传统方式刷入（不分slot）"
    else
        echo "1. 传统方式刷入"
        echo "2. 尝试刷入a分区"
        echo "3. 尝试刷入b分区"
    fi
    
    read -p "选择刷入方式: " flash_method
    
    local flash_cmd=""
    local reboot_after_flash="false"
    
    if [ "$has_ab_slots" = "true" ]; then
        case $flash_method in
            1)
                # 刷入当前slot
                partition_name="${SELECTED_PARTITION}${CURRENT_SLOT}"
                echo "刷入当前slot ($CURRENT_SLOT) -> $partition_name"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $partition_name \"$img_path\""
                ;;
            2)
                # 刷入a分区
                echo "刷入a分区"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}a \"$img_path\""
                ;;
            3)
                # 刷入b分区
                echo "刷入b分区"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}b \"$img_path\""
                ;;
            4)
                # 刷入两个分区
                echo "刷入两个分区（a和b）..."
                echo "第一步：刷入a分区"
                if fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}a "$img_path"; then
                    echo "✅ a分区刷入成功"
                else
                    echo "❌ a分区刷入失败"
                    read -p "按回车键继续..."
                    return 1
                fi
                
                echo "第二步：刷入b分区"
                if fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}b "$img_path"; then
                    echo "✅ b分区刷入成功"
                    echo "✅ 两个分区刷入完成！"
                    log "A/B分区镜像刷入成功: $img_path"
                    read -p "是否要重启设备？(y/n): " reboot_choice
                    if [ "$reboot_choice" = "y" ]; then
                        echo "重启设备..."
                        fastboot -i $SELECTED_VID -s $TARGET_DEVICE reboot
                        echo "✅ 设备重启中"
                    fi
                else
                    echo "❌ b分区刷入失败"
                    log "b分区刷入失败: $img_path"
                fi
                
                read -p "按回车键继续..."
                return 0
                ;;
            5)
                # 切换slot后刷入
                echo "当前slot: $CURRENT_SLOT"
                if [ "$CURRENT_SLOT" = "a" ]; then
                    target_slot="b"
                else
                    target_slot="a"
                fi
                
                echo "切换到 $target_slot 分区并刷入"
                echo "第一步：设置活动slot为 $target_slot"
                if fastboot -i $SELECTED_VID -s $TARGET_DEVICE --set-active="$target_slot" 2>/dev/null; then
                    echo "✅ 已设置活动slot为 $target_slot"
                else
                    echo "⚠️  无法设置活动slot，尝试继续刷入"
                fi
                
                echo "第二步：刷入 $target_slot 分区"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}${target_slot} \"$img_path\""
                reboot_after_flash="true"
                ;;
            6)
                # 传统方式
                echo "传统方式刷入（不分slot）"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION \"$img_path\""
                ;;
            *)
                echo "❌ 无效选择，使用传统方式刷入"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION \"$img_path\""
                ;;
        esac
    else
        # 不支持A/B分区的设备
        case $flash_method in
            1)
                echo "传统方式刷入"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION \"$img_path\""
                ;;
            2)
                echo "尝试刷入a分区"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}a \"$img_path\""
                ;;
            3)
                echo "尝试刷入b分区"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash ${SELECTED_PARTITION}b \"$img_path\""
                ;;
            *)
                echo "❌ 无效选择，使用传统方式刷入"
                flash_cmd="fastboot -i $SELECTED_VID -s $TARGET_DEVICE flash $SELECTED_PARTITION \"$img_path\""
                ;;
        esac
    fi
    
    echo ""
    
    echo ""
    read -p "确认刷入？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "❌ 取消刷入"
        return 0
    fi
    
    echo "开始刷入..."
    echo "执行命令: $flash_cmd"
eval "$flash_cmd"

    flash_result=$?
    
    if [ $flash_result -eq 0 ]; then
        echo "✅ 刷入成功！"
        log "镜像刷入成功: $img_path, 命令: $flash_cmd"
        
        if [ "$reboot_after_flash" = "true" ]; then
            echo "重启设备以使新slot生效..."
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE reboot
            echo "✅ 设备重启中"
        else
            read -p "是否要重启设备？(y/n): " reboot_choice
            if [ "$reboot_choice" = "y" ]; then
                echo "重启设备..."
                fastboot -i $SELECTED_VID -s $TARGET_DEVICE reboot
                echo "✅ 设备重启中"
            fi
        fi
    else
        echo "❌ 刷入失败"
        log "镜像刷入失败: $img_path, 命令: $flash_cmd"
    fi
    
    read -p "按回车键继续..."
    return $flash_result
}

# 10. 一键自动流程
auto_process() {
    log "=== 开始一键自动流程 ==="
    echo -e "\n${GREEN}=== 一键自动流程 ===${NC}"
    echo "这将按顺序执行："
    echo "1. 安装依赖"
    echo "2. 检测设备状态"
    echo "3. 选择设备"
    echo "4. 选择VID"
    echo "5. 解锁Bootloader"
    echo "6. 选择分区"
    echo "7. 备份分区"
    echo "8. 刷入镜像"
    echo ""
    read -p "是否继续？(y/n): " confirm
    [ "$confirm" != "y" ] && return 0
    
    # 保存当前状态
    local old_device="$TARGET_DEVICE"
    local old_vid="$SELECTED_VID"
    local old_partition="$SELECTED_PARTITION"
    local old_slot="$CURRENT_SLOT"
    
    # 重置状态
    TARGET_DEVICE=""
    SELECTED_VID=""
    SELECTED_PARTITION=""
    CURRENT_SLOT=""
    
    # 执行流程
    install_deps
    check_device_status
    select_and_lock_device
    select_vid_menu
    unlock_bootloader
    
    echo "请重启设备并重新进入fastboot模式后继续..."
    read -p "按回车键继续..."
    
    select_partition_menu
    backup_partition_menu
    
    echo "请准备好要刷入的镜像文件..."
    read -p "按回车键继续..."
    
    flash_image
    
    # 恢复状态
    TARGET_DEVICE="$old_device"
    SELECTED_VID="$old_vid"
    SELECTED_PARTITION="$old_partition"
    CURRENT_SLOT="$old_slot"
}

# 11. 查看设备信息
show_device_info() {
    echo -e "\n${GREEN}=== 设备信息 ===${NC}"
    
    if [ -z "$TARGET_DEVICE" ]; then
        echo "❌ 未选择设备"
    else
        echo "设备序列号: $TARGET_DEVICE"
        
        if [ -n "$SELECTED_VID" ]; then
            echo ""
            echo "🔍 获取设备详细信息..."
            echo "========================================"
            
            # 获取基础信息
            echo "📱 基础信息:"
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar version 2>/dev/null | head -5
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar product 2>/dev/null | head -5
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar variant 2>/dev/null | head -5
            
            # 获取slot信息
            echo ""
            echo "🔄 Slot信息:"
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar current-slot 2>/dev/null | head -5
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar slot-count 2>/dev/null | head -5
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar slot-suffixes 2>/dev/null | head -5
            
            # 获取解锁状态
            echo ""
            echo "🔓 解锁状态:"
            fastboot -i $SELECTED_VID -s $TARGET_DEVICE getvar unlocked 2>/dev/null | head -5
            
            echo "========================================"
        fi
    fi
    
    read -p "按回车键继续..."
}

# 12. 查看备份文件
show_backup_files() {
    echo -e "\n${GREEN}=== 备份文件列表 ===${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo "备份目录: $BACKUP_DIR"
        echo ""
        
        # 显示备份文件详情
        local backup_count=0
        for backup_file in "$BACKUP_DIR"/*.img; do
            [ -e "$backup_file" ] || continue
            backup_count=$((backup_count + 1))
            filename=$(basename "$backup_file")
            filesize=$(du -h "$backup_file" 2>/dev/null | cut -f1)
            filedate=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1) || filedate="未知"
            
            echo "📄 $filename"
            echo "   大小: $filesize | 日期: $filedate"
            
            # 显示slot信息（如果文件名中包含slot）
            if echo "$filename" | grep -q "slot-a"; then
                echo "   Slot: a分区"
            elif echo "$filename" | grep -q "slot-b"; then
                echo "   Slot: b分区"
            fi
            
            echo ""
        done
        
        if [ $backup_count -eq 0 ]; then
            echo "暂无备份文件"
        else
            echo "总备份文件数量: $backup_count"
        fi
    else
        echo "备份目录不存在"
    fi
    
    read -p "按回车键继续..."
}

# 13. 清理临时文件
clean_temp_files() {
    echo -e "\n${GREEN}=== 清理临时文件 ===${NC}"
    
    echo "清理Termux临时文件..."
    rm -f /data/data/com.termux/files/usr/tmp/* 2>/dev/null
    
    echo "清理脚本临时文件..."
    rm -f /tmp/fastboot_*.sh 2>/dev/null
    
    echo "清理日志文件？(y/n)"
    read -p "选择: " clean_logs
    if [ "$clean_logs" = "y" ]; then
        if [ -f "$LOG_FILE" ]; then
            rm -f "$LOG_FILE"
            echo "✅ 日志文件已清理"
        else
            echo "⚠️  日志文件不存在"
        fi
    fi
    
    echo "✅ 清理完成"
    
    read -p "按回车键继续..."
}

# 14. 查看操作日志
show_logs() {
    echo -e "\n${GREEN}=== 操作日志 ===${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo "日志文件: $LOG_FILE"
        echo "文件大小: $(du -h "$LOG_FILE" 2>/dev/null | cut -f1)"
        echo "最后修改: $(stat -c %y "$LOG_FILE" 2>/dev/null | cut -d' ' -f1,2)"
        echo ""
        
        echo "选择查看方式："
        echo "1. 查看最后20条日志"
        echo "2. 查看今天的所有日志"
        echo "3. 查看全部日志"
        echo "4. 搜索特定关键词"
        read -p "选择 (1/2/3/4): " log_choice
        
        echo "========================================"
        case $log_choice in
            1)
                tail -20 "$LOG_FILE"
                ;;
            2)
                today=$(date '+%Y-%m-%d')
                grep "^\[$today" "$LOG_FILE" || echo "今天没有日志记录"
                ;;
            3)
                cat "$LOG_FILE"
                ;;
            4)
                read -p "输入搜索关键词: " search_keyword
                grep -i "$search_keyword" "$LOG_FILE" || echo "未找到相关日志"
                ;;
            *)
                tail -20 "$LOG_FILE"
                ;;
        esac
        echo "========================================"
    else
        echo "暂无日志文件"
    fi
    
    read -p "按回车键继续..."
}

# 主循环
main() {
    while true; do
        show_header
        show_menu
        
        read choice
        
        case $choice in
            0)
                echo -e "\n${GREEN}感谢使用，再见！${NC}"
                log "用户退出系统"
                exit 0
                ;;
            1)
                install_deps
                ;;
            2)
                check_device_status
                ;;
            3)
                help_enter_fastboot
                ;;
            4)
                select_and_lock_device
                ;;
            5)
                select_vid_menu
                ;;
            6)
                unlock_bootloader
                ;;
            7)
                select_partition_menu
                ;;
            8)
                backup_partition_menu
                ;;
            9)
                flash_image
                ;;
            10)
                auto_process
                ;;
            11)
                show_device_info
                ;;
            12)
                show_backup_files
                ;;
            13)
                clean_temp_files
                ;;
            14)
                show_logs
                ;;
            *)
                echo -e "\n${RED}无效选择，请重新输入${NC}"
                sleep 1
                ;;
        esac
    done
}

# 异常处理
trap 'echo -e "\n${RED}程序被中断${NC}"; log "程序被用户中断"; exit 1' INT TERM

# 初始化日志
echo "=== Fastboot工具箱启动 $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOG_FILE"

if [ ! -f "$HOME/.fastboot_tool_installed" ]; then
    echo -e "${YELLOW}首次运行检测到依赖可能未安装${NC}"
    echo -e "${YELLOW}建议先选择选项1安装依赖${NC}"
    touch "$HOME/.fastboot_tool_installed"
    sleep 2
fi

# 启动主程序
main