# Typeless Dictionary Transfer

[![README-English](https://img.shields.io/badge/README-English-555555?style=for-the-badge)](README.md)
[![README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-2d6cdf?style=for-the-badge)](README.zh-CN.md)

把 Typeless 个人词典导出成可移植 bundle，审查后再导入到当前登录的 Typeless 账号。

这个项目优先解决“词典可移植性”，账号迁移只是其中一个场景。它可以帮助你：

- 导出当前登录 Typeless 账号的词典
- 在导入前审查或编辑导出的 bundle
- 对当前 Typeless 账号执行 dry-run 导入
- 在明确切换账号后，把 bundle 导入另一个 Typeless 账号

它**不会**自动替你执行 Typeless 的登录/登出。账号切换保留为显式人工检查点，以降低把词典导入错误账号的风险。

## 快速开始

### 1. 查看当前 Typeless 账号

```bash
/Users/Totoro/bin/typeless-dict whoami
```

### 2. 导出一个可移植 bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle source-account
```

这会在 `~/Downloads/typeless-transfer-.../` 下生成：

```text
account.json
dictionary.json
dictionary.txt
```

### 3. 先做一次 dry-run 导入

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run /path/to/bundle-dir
```

### 4. 确认后再正式导入

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle /path/to/bundle-dir
```

## 运行要求 / 兼容性

- macOS，且 Typeless 桌面客户端安装在 `/Applications/Typeless.app`
- 本地 helper 命令存在于 `/Users/Totoro/bin/typeless-dict`
- Typeless 桌面客户端中已经登录了一个账号
- 本机有 Node.js，可供 helper 通过 remote debugging 接管 Typeless

这套流程建立在当前 Typeless 桌面客户端的请求与签名行为之上。如果 Typeless 后续大改桌面内部实现，helper 可能需要同步更新。

## 安装

这个 skill 当前已经放在 Codex 的本地 skill 目录中：

```text
/Users/Totoro/.codex/skills/typeless-dictionary-transfer/
```

如果你只想直接使用底层命令行能力，核心 helper 是：

```bash
/Users/Totoro/bin/typeless-dict help
```

## 项目能力

这套工作流可以拆成三个动作：

1. 从当前登录的 Typeless 账号导出 bundle
2. 在本地审查/编辑 bundle
3. 把 bundle 导入当前登录的 Typeless 账号

所以它可以覆盖这些场景：

- 备份
- 恢复
- 同账号重新导入
- 跨账号转移
- 跨机器转移

## 仓库结构

```text
typeless-dictionary-transfer/
├── README.md
├── README.zh-CN.md
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── typeless_dictionary_transfer.sh
```

相关底层 helper 位于 skill 目录之外：

```text
/Users/Totoro/bin/typeless-dict
```

## 使用方式

### 查看当前账号

```bash
/Users/Totoro/bin/typeless-dict whoami
```

### 直接导出当前词典

```bash
/Users/Totoro/bin/typeless-dict export /tmp/typeless-dictionary.json --tab all --format json
/Users/Totoro/bin/typeless-dict export /tmp/typeless-dictionary.txt --tab all --format txt
```

### dry-run 导入

```bash
/Users/Totoro/bin/typeless-dict import /path/to/dictionary.txt --dry-run
```

### 正式导入

```bash
/Users/Totoro/bin/typeless-dict import /path/to/dictionary.txt
```

### 删除一个词条

```bash
/Users/Totoro/bin/typeless-dict delete "term-here"
```

## 包装脚本工作流

### 导出 bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle [label]
```

### 从 bundle 做 dry-run 导入

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
```

### 导入 bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle <bundle-dir>
```

## 推荐的跨账号转移流程

### 1. 从 source 账号 A 导出

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle source-a
```

### 2. 审查 bundle

重点检查并按需编辑：

- `dictionary.json`
- `dictionary.txt`

### 3. 手动把 Typeless 切换到账号 B

这套工具刻意不自动执行登录/登出。

### 4. 校验 target 账号 B

```bash
/Users/Totoro/bin/typeless-dict whoami
```

### 5. 先执行 dry-run

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run /path/to/bundle-dir
```

### 6. 确认后再导入

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle /path/to/bundle-dir
```

## 故障排查

- **导出结果意外为 0**
  先确认 Typeless 桌面客户端确实已登录，并重新运行 `typeless-dict whoami`。

- **dry-run 显示已有词太多**
  先审查并精简 `dictionary.txt`，再执行正式导入。bundle 刻意保留为纯文本，方便人工修改。

- **担心导入错账号**
  在导入前永远先执行一次 `typeless-dict whoami`。这是最重要的安全检查。

- **Typeless 更新后 helper 失效**
  这套工具依赖 Typeless 当前桌面行为；升级 Typeless 后应重新验证 export/import。

## 安全 / 隐私

- 这套流程直接复用你本机的 Typeless 桌面会话。
- 导出的 bundle 包含你的个人词典数据，应视为私有文件。
- bundle 被刻意保存在磁盘上，方便你审查、编辑和存档。
- 如果你不打算共享这些术语，请不要把 bundle 发给第三方。

## 支持 / 开发

Codex 侧的主要实现说明在：

- [SKILL.md](SKILL.md)

底层 helper 入口在：

- [/Users/Totoro/bin/typeless-dict](/Users/Totoro/bin/typeless-dict)

如果你后续继续扩展这个 skill，请保持 README、`SKILL.md` 和包装脚本的一致性。

## 许可证 / 状态

当前它仍是本地 Codex 环境下维护的 skill/workflow。是否独立公开发布、使用什么 License，与它最终落入哪个远端仓库有关。
