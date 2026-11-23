# 密匣 · iPhone 本地密码管理器

一个只存在你手机里的密码库。不联网、不注册、不上传，数据是 `Documents/vault.mxv` 一个加密文件。
给你自己记密码用，用 GitHub Actions 编译、爱思助手自签安装。

- 目标设备：iPhone 13（iOS 16.0 起都支持）
- 技术栈：SwiftUI + CryptoKit，零第三方依赖
- 成品：**未签名 IPA**，你下载后自己签

---

## 一、三步出包

### 1. 建仓库

GitHub 上新建一个仓库（名字随便，比如 `mixia`）。

> 建议设成 **Public**：Actions 的 macOS 机器免费不限时长。
> 设成 Private 也可以，每月 2000 分钟，macOS 按 10 倍计算 ≈ 200 分钟，一次构建约 4 分钟。

### 2. 上传这些文件

把 `mixia-ios` 文件夹里的**全部内容**上传到仓库根目录，注意 `.github` 这个点开头的文件夹也要一起上传（它是隐藏的，网页上传时要能看到）：

```
.github/workflows/build.yml     ← 自动编译脚本
project.yml                     ← XcodeGen 工程描述
MixiaVault/
  Info.plist
  App/MixiaApp.swift
  Core/{Models,Crypto,VaultStore,Support}.swift
  UI/{Theme,Components,LockView,VaultListView,ItemDetailView,ItemEditorView,SettingsView}.swift
  Assets.xcassets/...           ← 图标
```

> **如果 `.github` 拖不进去**（Windows 资源管理器有时不让拖点开头的文件夹）：
> 在仓库页点 `Add file` → `Create new file`，文件名直接敲 `.github/workflows/build.yml`
> （敲 `/` 会自动建目录），然后把 `build.yml` 的内容粘进去，Commit。
> 其它文件照常拖拽上传即可。

### 3. 点一下就跑

仓库页面 → **Actions** → 左边选 `Build IPA` → 右边 **Run workflow** → 绿色按钮。
等 3–6 分钟，进入这次运行 → 页面底部 **Artifacts** → 下载 `MixiaVault-unsigned-ipa`，解压得到 `MixiaVault.ipa`。

---

## 二、爱思助手签名安装

1. 手机连电脑，iPhone 上点「信任」
2. 爱思助手 → 工具箱 → **IPA 签名**
3. 添加刚下载的 `MixiaVault.ipa`，登录 Apple ID（建议用不常用的小号）
4. 开始签名 → 完成后直接安装到设备
5. iPhone：设置 → 通用 → VPN 与设备管理 → 信任该开发者
6. iPhone：设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启（iOS 16 以上必须，否则 App 点开就退）
7. 打开密匣，设置 6 位数字密码，**立刻去设置里导出一份备份**

---

## 三、7 天到期怎么办

免费签名的描述文件 7 天过期。到期后 App 点开就闪退，**但数据还在**：

1. 用爱思助手重新签一次
2. **覆盖安装**（不要先卸载！卸载会连 App 沙盒里的保险库一起删掉）
3. 打开后照常使用

App 里设置页会显示「剩 X 天」，剩 2 天时变黄。

---

## 四、数据与加密

| 项目 | 做法 |
|---|---|
| 存储位置 | `Documents/vault.mxv`（文件级保护 `NSFileProtectionComplete`） |
| 数据密钥 | 随机 32 字节，AES-256-GCM 加密正文 |
| 主密码 | 6 位数字 → PBKDF2-HMAC-SHA256（600,000 次，16 字节盐）派生 KEK，包装数据密钥 |
| 完整性 | 文件头（magic + 迭代次数 + 盐）作为 AAD 参与认证，改一个字节就解不开 |
| Face ID | 数据密钥另存一份在钥匙串，绑定 `biometryCurrentSet`；失效自动退回数字密码 |
| 剪贴板 | 复制后 30 秒由系统自动清空 |
| 后台 | 切走立刻盖遮罩、清内存密钥（防多任务快照泄露） |

**风险说清楚**：6 位数字对"捡到手机的人"够用，但如果有人把你的 `vault.mxv` 拷走做离线爆破，
10^6 组合是能跑完的。所以别用生日 / 123456，也别把备份文件发给别人。

系统的 iCloud 备份会把 `Documents` 一起备走（文件是加密的，但确实会离开手机）。
如果你连这个都不想要：设置 → 你的名字 → iCloud → iCloud 云备份 → 关掉。

## 四之二、已知取舍

- **自动锁定只看"离开 App 的时间"**，不做前台闲置计时——不然你正盯着屏幕看，它给你锁了。
- **截图无法在公开 API 层面拦截**，只做得到"录屏/投屏时自动盖上遮罩"。
- **忘记 6 位密码 = 数据永久打不开**，没有后门，也没有找回流程，这也是它能这么简单的原因。

---

## 五、想改的地方

| 想改 | 改哪 |
|---|---|
| App 名字 | `Info.plist` 的 `CFBundleDisplayName` |
| Bundle ID | `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`（改完要重签，可能丢旧数据，别乱改） |
| 最低系统版本 | `project.yml` 的 `deploymentTarget` |
| 默认分类 | `Core/Models.swift` 里 `Vault.categories` 的初始值 |
| 图标 | 替换 `Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024×1024，不要透明通道） |
| 打包版本号 | `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |

---

## 六、报错怎么办

Actions 失败时，点进这次运行 → 展开 `Build (no code signing)` 那一步 →
把里面第一处 `error:` 开头的几行发我，我改完你重新跑一次就行。

常见原因：

- **找不到 scheme**：`project.yml` 缩进被编辑器改坏了（YAML 对空格敏感）
- **签名相关报错**：说明 `CODE_SIGNING_ALLOWED=NO` 没生效，检查 workflow 里那几行参数
- **Swift 编译错误**：把错误行发我

---

## 七、路线说明

这台机器上没有 macOS，所以工程不能本地编译验证。第一次跑 Actions 大概率会有几个小报错，
属于正常流程——把日志发我，我逐条修，通常 1–2 轮就能出正常 IPA。
