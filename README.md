# OnePlus Init_Boot 刷入 & 解锁脚本说明 ## 📌 脚本用途说明 本脚本用于 **一加（OnePlus）等 A/B 分区安卓设备**，主要实现以下功能： - 解锁 Bootloader（BL） - 自动识别当前 A/B Slot - 刷入已修补的 `init_boot.img`（如 Magisk 修补） - 支持 fastboot 安全刷入 - 降低误刷、乱刷分区的风险 脚本适用于： - 一加 A/B 分区设备 - 已安装 adb / fastboot 的 Linux / Termux 环境 - 需要刷入 root（Magisk）或修补 init_boot 的用户 --- ## ⚠️ 使用前必读（非常重要） 1. **解锁 Bootloader 会清空所有用户数据** 2. 请提前备份手机内的重要资料 3. 确保数据线稳定，刷机过程中不要断开 4. 本脚本只刷入 **当前 Slot（A 或 B）** 5. 另一 Slot 会保留作为“安全退路” --- ## 🛠 使用环境准备 - 电脑 / 手机（Termux）已安装： - `adb` - `fastboot` - 被刷设备已开启： - USB 调试 - OEM 解锁（开发者选项） - 已准备好 **修补后的 `init_boot.img`** --- ## 🚀 脚本基本使用流程 ### 1️⃣ 连接设备 使用数据线连接手机，确认设备可识别： ```bash adb devices 

2️⃣ 运行脚本

cd mrootj

chmod +x scripts/mrootjbl.sh

./scripts/mrootjbl.sh

按提示操作即可。

📂 init_boot 镜像路径输入说明

当脚本提示输入 init_boot.img 路径时，
如果文件在手机存储根目录，请输入：

/storage/emulated/0/init_boot.img 

路径区分大小写，文件名必须完全一致。

🔓 功能说明（逐项）

功能 1：解锁 Bootloader（BL）

执行 fastboot 解锁命令

手机会弹出确认界面

需在手机上使用音量键确认

输出示例（正常）：

OKAY 

注意：

必定清空数据

属于官方行为，无法跳过

功能 2：识别当前 A/B Slot

脚本会自动识别当前系统运行的 Slot（A 或 B）：

当前为 A → 刷 init_boot_a

当前为 B → 刷 init_boot_b

输出示例：

当前 Slot: a 

功能 3：刷入 init_boot.img

仅刷入当前 Slot 对应的分区：

safe_fastboot flash init_boot_a init_boot.img 

成功输出示例：

Sending 'init_boot_a' OKAY Writing 'init_boot_a' OKAY Finished. Total time: 0.XXXs 

📊 常见输出与含义说明

✅ 成功情况

OKAY Finished. Total time: 0.XXXs 

含义：

刷入成功

可正常重启进入系统

❌ 文件路径错误

error: cannot load '/storage/emulated/0/init_boot.img' 

含义：

文件不存在或路径输错

手机不会受影响

解决：

确认文件位置

重新输入正确路径

❌ 分区不存在

FAILED (remote: 'Partition not found') 

含义：

设备不支持该分区名

不会刷坏设备

❌ 刷入失败

FAILED (remote: 'Flash failure') 

含义：

未成功刷入

fastboot 仍可使用

可重新尝试

🔁 A/B 分区刷入说明

✅ 默认：只刷当前 Slot（推荐）

❌ 不建议：同时刷 A + B

原因：

单 Slot 刷入更安全

另一 Slot 可作为恢复备用

🔐 风险说明

本脚本不会：

锁死 fastboot

进入 EDL

直接导致硬砖

如刷入失败，仍可通过 fastboot 重刷。

📞 问题反馈 / 联系作者

如出现以下情况：

刷机流程中断

fastboot 报错无法理解

脚本异常退出

请准备以下信息联系作者：

设备型号

fastboot 输出内容（原样复制）

使用的 init_boot.img 来源

📧 联系方式：
作者本人 / 脚本维护者

✅ 最后说明

使用本脚本即表示你已了解刷机风险。
脚本已尽量避免危险操作，但请务必谨慎。

祝你刷机顺利 👍
