# Whetstone 功能探索调研报告(基于产品定位 + 学习科学 + 竞品功能面)

调研输入:`CLAUDE.md`、设计文档 `~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`、代码实扫(`Whetstone/Views/**`、`Packages/WhetstoneCore/Sources/WhetstoneCore/**`)、Tavily 网络调研(学习科学 + Readwise Reader / Matter / FSRS 等)。

---

## 1. 目标用户画像 + 三大可用性缺口

### 用户画像(一页)

**「主题式自驱学习者」**(首个用户 = 作者本人,工程师)
- **输入源**:技术博客、深度长文、行业分析(1500–3000+ 字图文);明确不是视频/论文/书(设计文档 P3 锁定)。
- **动机**:不是"收藏",是"内化"——原始痛点是"看的时候觉得原来如此,三天后只剩模糊标题印象"。
- **方法论认同**:用机制语言思考(费曼/苏格拉底),要的是有学习科学支撑的工具,不是"AI+阅读"跟风品。
- **使用形态**:macOS 桌面、长 session(15–60 分钟/篇)、中英双语(已有段落对齐翻译功能)、AI 伴读不抢戏(主动召唤而非被突击)。
- **量化偏好**:接受并喜欢数字分反馈(P2 DEFENDED),但仅在主动"考考我"时打分。
- **成功判据**:第 7 天还会主动打开;理想 ≥5 篇/周。

### 当前功能面(代码实扫结论)

已有:URL 抓取(Readability)+ AI 排版增强、Library(stats/继续阅读/搜索/recent-unread 过滤)、阅读器(高亮、选中 Ask 文中 thread、双语翻译)、AI 栏(3 概念提取、persona 类比答疑、自由问、苏格拉底 quiz + 三维评分 recall/apply/analyze、QuizResultCard)、Onboarding/Settings。

### 三大可用性缺口

1. **长文读到一半就"丢了"——没有阅读位置/进度持久化。**
   `ReaderPane`/`WorkspaceView` 全无 scrollPosition 持久化;`LibrarySelectors.continueReading` 用「有对话轮且未打分」来*猜*在读文章,不知道你读到哪。对一个以 30 分钟长文为核心场景的产品,这是最大的日常摩擦。

2. **学完即终点——复习闭环完全缺失,直接背叛了产品的原始问题陈述。**
   quiz 产出的 `ConceptScore`(逐概念 recall/apply/analyze 0–2 + 诊断 note)是全 app 最贵的数据,但**没有任何下游消费**:没有复习队列、没有弱点追练、没有高亮回流。Highlight 存了就再也不出现。设计文档把"艾宾浩斯复习"显式 defer 到 v1,至今未建。"三天后忘光"的原问题,当前产品只解决了"读的那一刻",没解决"三天后"。

3. **入库单通道 + 没有"主题"组织——捕获摩擦高,"主题学习"无主题。**
   唯一入口是 app 内 `AddArticleSheet` 粘 URL:无 Share Extension、无全局快捷键、无剪贴板捕获、无 PDF。且 Library 是平铺列表(recent/unread),没有 topic/标签/队列状态(inbox→在读→已学→归档)——"用长文做主题学习"的用户没法把 5 篇 Rust 异步文章归成一个主题推进。

---

## 2. 功能候选清单(22 个)

复杂度为 Swift 原生视角:S ≤1 天、M = 2–4 天、L = 1 周+。契合度 = 与费曼/苏格拉底方法论及"伴读不抢戏"定位的契合(高/中/低)。

### A. 阅读流

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| A1 | **阅读位置记忆 + 进度条** | 按字符偏移持久化滚动位置,文章卡片显示真实 % 进度 | "昨天读到一半,今天接着读" | 中(沉浸基线) | **S** | 无(NSTextView 几何已有,`reportAnchorRects` 同源) |
| A2 | **阅读队列状态机** | Article 加 `status: inbox/reading/done/archived`,Library 按泳道展示 | "我存了 20 篇,下一篇读哪篇" | 中 | **S** | Article schema 迁移 |
| A3 | **主题(Topic)分组** | 多篇文章归入一个主题,主题页聚合概念与分数 | "我在主题式学习,不是零散读" | **高**(跨文概念是费曼检验场) | M | schema + Library UI |
| A4 | **文内 TOC 浮层** | 从 markdown 标题生成目录,点击跳转 | "长文中定位/回看某节" | 低 | S | isLayoutEnhanced 已产 markdown |

### B. 捕获

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| B1 | **Share Extension** | Safari 分享菜单一键送 URL 入库 | "看到好文,2 秒存下,不打断当前事" | 中 | M | App Group + Extension target(项目 v1 计划内) |
| B2 | **全局快捷键 + 剪贴板捕获** | ⌥⌘S 抓剪贴板 URL 静默入库,菜单栏小图标反馈 | 同上,覆盖任意浏览器 | 中 | **S** | NSEvent global hotkey / MenuBarExtra |
| B3 | **拖拽入库** | URL/文本/`.md` 拖进窗口即建文章 | 低摩擦捕获兜底 | 中 | S | `.dropDestination` |
| B4 | **PDF 导入** | PDFKit 抽文本走同一概念/quiz 管线 | "论文/报告也想这样学" | 中 | L | PDFKit + 排版管线适配(违反 P3 锁定,谨慎) |
| B5 | RSS 订阅 | 订阅源自动入 inbox | "固定信源自动流入" | **低**(制造无限流,见 §4) | L | 后台拉取 |

### C. 复习(学习科学核心:检索练习 + 间隔重复是 Dunlosky 2013 综述中仅有的两个"high utility"技术;Roediger & Karpicke 2006 证明检索练习一周后保留显著优于重读 — https://recallify.ai/evidence-for-active-recall-and-spaced-repetition)

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| C1 | **概念复习队列(FSRS-lite)** | 以 Concept 为卡、ConceptScore 为初始难度,FSRS/SM-2 排期到期复习 | "三天后还记得" — 产品原始承诺 | **极高** | M | FSRS 算法可纯 Swift 实现(参考 https://github.com/open-spaced-repetition/fsrs4anki) |
| C2 | **复习 = 迷你苏格拉底** | 到期概念不是"看卡片",而是 AI 出 1 道生成式问题→你作答→AI 评 | 检索练习用生成而非重读(testing effect 本体) | **极高**(复用 quiz 全套管线) | M | C1;复用 grader |
| C3 | **弱点追练** | quiz 后针对 analyze/apply = 0 的概念,一键"再教我这个"教学循环 | "知道哪弱,立刻补" | **高**(设计文档 v1 的 Reinforce 模式) | S–M | ConceptScore 已有 note 字段 |
| C4 | **高亮回流** | 每日 review 面板回放 3–5 条到期高亮 + 所在文中 thread | "划过的重点别白划"(Readwise 核心留存机制 — https://www.speedreadinglounge.com/readwise-reader-review) | 中高 | S | Highlight 已有时间戳 |
| C5 | **费曼空白页** | 读完(或读前回忆)给一张空白页:"用自己的话写这篇讲了什么"→AI 对照原文指出漏点与误解 | 费曼方法的字面实现;self-explanation 在 cued recall 上显著优于复读(https://www.sciencedirect.com/science/article/abs/pii/S0361476X97909772) | **极高** | M | 新 prompt(非 P1 锁定,可自由迭代) |
| C6 | 跨文章概念图谱 | 同名/同义概念跨文章串联,主题页可视化 | "知识连成网" | 中 | L | A3 + embedding 或 LLM 归并 |

### D. 沉浸(配合 Liquid Glass V2 重构)

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| D1 | **Focus mode** | 一键收起双栏 + 隐 chrome,仅正文居中;AI 入口退化为浮动 glass 胶囊 | "30 分钟不被打扰地读" | **高**(伴读不抢戏的极致) | **S** | 折叠机制已有,只差编排 |
| D2 | **排版控制面板** | 字号/行距/栏宽/衬线切换 + 浅深模式,glass 浮层承载 | "长读不累眼" | 中 | S–M | 与 V2 主题 token 同期做最省 |
| D3 | **TTS 朗读 + 跟读高亮** | AVSpeechSynthesizer 朗读正文,当前句高亮滚动 | "眼睛累了换耳朵"(Matter 的招牌能力 — https://mwm.ai/apps/matter-reading-app/1501592184) | 中 | M | AVFoundation;与锚点几何复用 |
| D4 | 阅读会话计时 | 静默记录本篇累计阅读时长,只在文末/统计页露出 | "我真的投入了多少" | 低 | S | 无 |

### E. 效率

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| E1 | **⌘K 命令面板** | 搜文章/概念/高亮 + 跑命令(开 quiz、切 focus、加文章) | "手不离键盘驱动全 app" | 中 | M | 全局搜索索引(SwiftData 查询即可) |
| E2 | **键盘流阅读** | j/k 段落、space 翻页、h 高亮、a 对选中句 Ask | 重度阅读者效率基线 | 中 | M | BrutalistTextView 键件分发 |
| E3 | Quick Ask 全局唤起 | 全局快捷键弹小窗,对剪贴板文本即问即答 | "不在 app 里也能问" | 低(脱离文章上下文,易变泛用聊天) | M | 全局快捷键 + 独立窗口 |

### F. 数据

| # | 功能 | 一句话 | JTBD | 契合 | 复杂度 | 依赖 |
|---|------|--------|------|------|--------|------|
| F1 | **Markdown 导出** | 单篇/全库导出:正文+高亮+文中 threads+概念+分数,Obsidian 友好 | "数据是我的;学习成果沉淀进 PKM" | 中高(费曼产出物可带走) | **S** | 无 |
| F2 | **学习统计页** | 复习 streak、概念掌握曲线(三维分趋势)、主题覆盖 | "看见自己在变强"(P2:数字反馈正激励) | 中 | M | C1 数据;Swift Charts |
| F3 | CloudKit 同步 | 多 Mac 同步库与进度 | 多设备 | 低(单用户单机现状) | M–L | schema 按 CloudKit 4 坑改造(设计文档已列) |

---

## 3. Top 8 推荐(价值 × 契合 ÷ 成本)与功能包

| 排名 | 功能 | 理由 |
|------|------|------|
| 1 | C1+C2 概念复习队列(FSRS-lite,复习即迷你苏格拉底) | 唯一兑现"三天后还记得"原始承诺的功能;ConceptScore 数据已在白白产出;竞品(Readwise)证明这是留存核心;与苏格拉底方法论 100% 契合 |
| 2 | A1 阅读位置记忆 | S 级成本消灭最高频日常摩擦;长文产品的地板 |
| 3 | C5 费曼空白页 | 方法论字面实现 + 学习科学最强证据(self-explanation/生成效应);prompt 非 P1 锁定可自由迭代 |
| 4 | D1 Focus mode | S 级成本,"伴读不抢戏"的极致表达,且是 Liquid Glass V2 重构的天然展示位 |
| 5 | C3 弱点追练 | 设计文档 v1 既定的 Reinforce 模式,数据(note 字段)已就位,S–M 成本 |
| 6 | B1+B2 Share Extension + 全局快捷键捕获 | 入库摩擦是 ≥5 篇/周目标的直接瓶颈;B2 先行(S 级)可立刻止血 |
| 7 | A2+A3 队列状态 + 主题分组 | 把"收藏夹"升级成"学习推进器";A3 为 C6 打地基 |
| 8 | F1 Markdown 导出 | S 级成本买"数据不锁死"的信任 + 学习成果流入 PKM 生态 |

### 顺序交付的三个功能包

**功能包 1「读得下去」(随 Liquid Glass V2 重构同车发布,~1 周)**
A1 阅读位置记忆 → D1 Focus mode → D2 排版控制 → A2 队列状态。
理由:全部触 ReaderPane/主题层,与 V2 视觉重构改同一批文件,合并改动最省;发布即"新皮肤 + 新手感"。

**功能包 2「记得住」(核心差异化,~2 周)**
C1 FSRS-lite 排期 → C2 复习即迷你苏格拉底 → C3 弱点追练 → C4 高亮回流 → F2 统计页(收口)。
理由:复用 quiz/grader 全套管线和 ConceptScore 数据,是从"AI 阅读器"到"学习系统"的跃迁;Readwise 走"重看高亮"路线,Whetstone 走"生成式检索练习"路线——证据上后者更强,是可声明的差异点。

**功能包 3「进得来 + 流得动」(~1.5 周)**
B2 全局快捷键捕获 → B1 Share Extension → A3 主题分组 → E1 ⌘K 面板 → F1 导出 → C5 费曼空白页。
(C5 也可前移进包 2 末尾,视包 2 进度。)

---

## 4. 「不该做」清单

| 不做 | 原因 |
|------|------|
| **AI 自动全文总结 / TL;DR 卡片** | 总结是用户的费曼作业,AI 代写 = 摧毁方法论根基;这是与 Readwise Ghostreader 们的刻意反向差异 |
| **AI 主动突击提问 / 开屏即考** | v0 office-hours 已显式否决(陪伴型 lock-in);破坏"用户主动召唤"的契约 |
| **RSS 全功能订阅 / 发现 feed / 推荐流** | 制造无限流与囤积焦虑,把"内化工具"退化成又一个 read-later 坟场;捕获靠 B1/B2 点状解决 |
| **社交:分享成绩卡、排行榜、好友** | 单用户自驱场景,P4 验证与此无关 |
| **重型游戏化(徽章/经验值/宠物)** | 与"安静、不抢戏"的产品气质冲突;数字分(P2)已是足够的量化反馈 |
| **视频 / 播客 / 推特串 ingestion** | P3 锁定:文章是瓶颈;多媒体管线成本巨大且稀释定位 |
| **泛用笔记 / 块编辑器(Notion 化)** | 笔记沉淀交给导出(F1)+ 用户自己的 PKM;做笔记器 = 和 Obsidian 打仗 |
| **完整浏览器扩展** | v0 已评估否决(Manifest V3 坑);Share Extension + 全局快捷键覆盖 90% 场景 |
| **阅读中常驻 AI 侧栏推送("你可能想问…"主动气泡)** | 打断沉浸,违反"AI speaks beside you, not over you" |
| **复习推送通知轰炸** | 复习入口放 app 内(Library 顶部"今日待复习 N"),最多一条可关的每日摘要;通知驱动与自驱学习者画像相悖 |

---

## 附:引用来源

- 检索练习/间隔重复证据综述(Roediger & Karpicke 2006;Karpicke & Blunt 2011;Dunlosky et al. 2013):https://recallify.ai/evidence-for-active-recall-and-spaced-repetition
- Self-explanation vs elaborative interrogation(self-explanation 显著更优):https://www.sciencedirect.com/science/article/abs/pii/S0361476X97909772
- Dunlosky 2013 中 elaboration/self-explanation 定位(moderate utility 补充技术):https://www.med.uvm.edu/docs/elaboration/active_learning/the_science_of_learning_-_elaboration.pdf
- Readwise Reader 功能面与 spaced-repetition 高亮回流:https://www.speedreadinglounge.com/readwise-reader-review 、https://aipedia.wiki/tools/readwise
- Matter 功能面(TTS/队列/导出):https://mwm.ai/apps/matter-reading-app/1501592184
- FSRS 开源调度算法(可纯 Swift 移植):https://github.com/open-spaced-repetition/fsrs4anki
- 本地依据:`/Users/zhengyangxu/Desktop/side_project/learning-mate/CLAUDE.md`、`~/.gstack/projects/learning-mate/zhengyangxu-design-20260524-212909.md`、`Packages/WhetstoneCore/Sources/WhetstoneCore/Library/LibrarySelectors.swift`(continueReading 推断逻辑)、`Models/ConceptScore.swift`(三维分无下游消费)、`Whetstone/Views/Library/AddArticleSheet.swift`(唯一捕获入口)