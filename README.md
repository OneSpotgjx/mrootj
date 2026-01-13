### 核心特性：锁定单设备操作
1.  检测设备后，输入 `1` 即可快速选中**第一台设备**
2.  选定后，**后续所有步骤（解锁、备份、刷入、重启）仅针对这一台设备**，无二次选择入口
3.  所有 `fastboot` 命令自动绑定该设备序列号，避免误操作其他设备

### 使用步骤
1.  硬件连接：OTG连接主机和被控机，被控机进入fastboot模式
2.  主机Termux获取USB权限：`termux-usb -r -e $SHELL -e /dev/bus/usb/xxx/xxx`
3.  克隆启动：
    ```bash
    git clone https://github.com/你的用户名/toolbox.git
    cd toolbox && chmod +x flasher.sh && ./flasher.sh
    ```
4.  按提示输入 `1` 选中第一台设备，后续按引导完成操作即可
