# teamlog

**一本公共日志，一个 hub，每人一个 agent。** 面向小团队的沟通约定：团队里每个人都和自己的 AI agent 一起工作。

[English](README.md)

## 想法

团队沟通复杂，是因为每条消息都要有收件人。发的人得决定谁需要知道、什么时候说、用什么形式。会议、群、抄送、工单，都是在解决这个路由问题。

团队没有干脆把所有事写在同一个地方，是因为没人读得完。agent 读得完。

所以在 teamlog 里没有人"发"消息：

- 人只和自己的 agent 说话。
- agent 把简短的条目追加到一本公共日志里。
- **hub** 把每条新日志读一遍，决定这条还**该给谁**看。
- 每个人的 **worker agent** 读取给自己主人的内容，决定**什么时候**告诉他。

```
log/
  20261006-090100-alice.md   登录接口改完了，测试通过，等人评审
  20261006-090200-bob.md     下周三前需要定价方案，@carol 能给吗
  20261006-090300-carol.md   re: ...-bob   方案周一给。另外我觉得应该先做企业版
  20261006-090600-hub.md     re: ...-alice @bob [action] 他负责评审
```

Alice 的那条没有 @ 任何人。hub 把它转给了 Bob，因为评审归他管。整个机制就是这样。

## 试一下

需要 Python 3.8+ 和 git。没有依赖，不需要 API key。

```bash
git clone https://github.com/Ivann1242/teamlog && cd teamlog
./examples/demo.sh
```

演示会在临时目录里模拟一个四人团队：写日志、hub 路由、回复关闭一个请求、没人回应的请求在 26 小时后被重新提起。

## 团队怎么用

一个人创建团队空间，推到全队都能访问的 git 远端：

```bash
./tl init ~/myteam          # 生成 log/、people/、AGENTS.md，并复制一份 tl
cd ~/myteam
git remote add origin <你的远端> && git add -A && git commit -m "teamlog" && git push -u origin HEAD
```

每个人 clone 这个仓库，声明自己是谁：

```bash
./tl join alice --owns "登录, sso" --cares "企业版"
```

然后用你的编码 agent（Claude Code、Codex，或任何会读 `AGENTS.md` 的工具）打开团队空间。`AGENTS.md` 会告诉它怎样做你的 worker agent：会话开始先看收件箱，你完成了什么或需要什么时写日志，按合适的档位告诉你事情。也可以手动操作：

```bash
./tl write "登录接口改完了，测试通过，等人评审"
./tl inbox
./tl reply <id> "评审通过"
./tl sync                   # git pull，提交日志，push
```

由一台机器运行 hub，只能有一个：

```bash
./tl hub --watch 300 --sync     # 每 5 分钟一轮，之前 pull，之后 push
```

## 工作方式

```
team/
  log/              只追加的条目，事实的唯一来源
  people/alice.md   每人一份：负责、关心、不关心、打断，加自由说明
  STATUS.md         由 hub 重建：等待中 / 最新 / 已决定
  hub/seen          hub 已经路由过的条目
  AGENTS.md         给 worker agent 的说明
  tl                工具本身，一个文件
```

一条日志是一个 Markdown 文件，文件名为 `<UTC 时间>-<作者>.md`。第一行可以写 `re: <id>` 表示回复。格式只有这些。

| | Hub（团队一个） | Worker agent（每人一个） |
|---|---|---|
| 回答的问题 | 这条**该给谁** | **什么时候**告诉我的主人 |
| 读什么 | 每条新日志，读一遍 | @ 了主人的，以及 hub 转给主人的 |
| 写什么 | 路由、提醒、`STATUS.md` | 主人的进展、请求、决定 |
| 不做什么 | 不做决定、不排优先级、不替任何人表态 | 不替主人承诺或决定 |

条目里的约定：

- `@名字` 表示请这个人处理。在对方回复之前，这个请求一直是未完成状态。
- `cc @名字`（或 `抄送 @名字`）表示只是让对方知道。
- `#decision`（或 `#决定`）会让这条进入 `STATUS.md` 的"已决定"。
- 作者自己回复并带上 `#closed`（或 `#关闭`），可以关闭自己发起的请求。

个人档案 `people/<名字>.md` 的四个关键词行，可以用英文键 `owns / cares / ignores / interrupt`，也可以用中文键 `负责 / 关心 / 不关心 / 打断`。

收件箱把新内容分成三档：

| 档位 | 含义 | 哪些内容会进来 |
|---|---|---|
| `NOW` | 立刻告诉主人 | 主人一直没回应的请求被再次提醒；命中 `interrupt` 关键词的内容 |
| `LATER` | 下一个自然间歇再说 | 待处理的请求；别人对主人条目的回复 |
| `FYI` | 不用汇报，记住即可 | 值得知道、但无需行动的内容 |

命令行给出的档位只是按规则算出的基线。worker agent 应该在此基础上结合主人当前在做的事来判断，`AGENTS.md` 里有说明。

三条规则保证它不容易坏：

1. **@ 不经过 hub。** worker agent 直接读提到自己主人的条目。hub 只处理没被 @ 的部分，两条通路互相独立。
2. **hub 不保存私有状态。** 它知道的一切都在仓库里。删掉 `hub/seen`，它会重新算出同样的路由，不会重复写入。
3. **能用代码做的不用模型。** 提醒和 `STATUS.md` 是普通代码。只有"这条和谁有关"需要模型判断。

## 用模型做路由

默认情况下，hub 用每个人的 `owns` 和 `cares` 关键词去匹配条目。这不需要任何配置，但很粗糙：只能找到字面匹配。

把 `TL_LLM` 设为任何"从标准输入读提示词、把回答打印出来"的命令，hub 就会改为询问它：

```bash
export TL_LLM="claude -p --model haiku"
./tl hub
```

hub 会把这条日志和所有人的档案发过去，期望得到一个 JSON 数组，例如 `[{"to":"bob","kind":"action","why":"负责代码评审"}]`。如果命令失败或回答无法解析，这一条会退回关键词路由，hub 会说明。

注意：

- 请在普通终端里运行 hub。`claude -p` 不允许在另一个 Claude Code 会话内部启动，所以由你的编码 agent 拉起的 hub 会退回关键词路由。
- 日志条目按数据处理。模型的回答也会被过滤：只保留已知的队友，以及 `action` 和 `fyi` 两种类型。

## 命令

```
tl init [dir]            创建团队空间
tl join <name>           在这台机器上声明你是谁，并创建档案
tl write "text"          追加一条日志（也可以从标准输入传入）
tl reply <id> "text"     回复一条日志
tl inbox [--peek|--json] 给你的新内容，分三档
tl show <id>             一条日志及其回复
tl log [-n N] [--hub]    最近的日志
tl status                谁在等谁、每人最新一条、已做的决定
tl hub [--watch S] [--sync] [--llm CMD] [--no-llm] [--remind-hours H] [--remind-max N]
tl sync                  git pull，提交日志，push
```

`<id>` 可以简写成任何唯一的片段。环境变量：`TL_ME`（身份）、`TL_ROOT`（团队空间）、`TL_LLM`（模型命令）、`TL_REMIND_HOURS`（默认 24）。

## 现状与局限

这是 v0.1，一个实验。已验证和未验证的部分如下：

- 工具行为有端到端测试覆盖（`python3 -m unittest discover -s tests`），包括两个克隆通过 git 远端交换日志。
- 模型路由只用一个桩命令测试过。**真实模型的路由质量还没有评估。** 整个设计押注在这一点上，它也是下一步要测量的东西。
- `AGENTS.md` 里给 worker agent 的说明，还没有在不同的 agent 上测试过。

已知局限：

- 为小团队设计，大约十人以内。日志没有分区。
- 日志对所有能访问仓库的人公开。没有私密条目，也没有访问控制。
- 默认信任所有人。没有任何机制阻止队友冒用别人的名字写日志。
- 只能运行一个 hub。两个 hub 会写出重复的路由。
- 关键词路由是子串匹配，关键词要写得短。

## 许可

MIT
