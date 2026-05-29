# milkdragon Desktop Pet

milkdragon（中文名：奶龙）是一个纯本地 Windows 桌宠。它使用 PNG 精灵图和 PowerShell/WPF 实现，不需要 Codex、Python、API key 或联网。

## 运行方式

双击：

```text
run_milkdragon.bat
```

也可以在终端运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\milkdragon_pet.ps1
```

## 交互

- 左键点击奶龙：随机做动作、切换表情，偶尔换装。
- 右键点击奶龙：用中文菜单选择装扮或指定表情。
- 长按拖动：移动悬浮窗，拖动期间不会切换装扮。
- 向左/向右拖动：奶龙会左右小跑和倾斜。
- 向上拖动：普通装扮会小跳；飞行员装扮会进入向上飞行姿态。
- 向下拖动：奶龙会蹲低。
- 快速甩动：奶龙会摇晃。
- 整点：奶龙会做动作并播报当前时间。

## 当前资源

- 装扮：默认奶龙、海盗船长、田园草帽、小画家、飞行员、购物达人、雨衣套装。
- 表情/动作：吐舌动作、害羞脸红、害羞低头。
- 雨衣套装已重新处理为不透明绿色雨衣和黄色伞帽，不再使用会误抠绿色衣服的透明处理。

## 文档

每套装扮和特殊表情都有中文说明文件，位置在：

```text
docs/
```

## 隐私

项目不包含 API key、token、password、cookie 或个人凭据。所有效果都在本地运行。
