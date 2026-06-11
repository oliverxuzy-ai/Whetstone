# 一流长文阅读/学习类 App 调研报告 —— 为 Whetstone「重沉浸长阅读 + AI 理解伴读」定位找参照

调研对象:Readwise Reader、Matter、Instapaper、新版 Reeder、Craft、Bear 2、NetNewsWire、iA Writer、Apple Books / Apple News。调研时间:2026-06-11。

---

## 1. 长阅读排版规范共识

### 1.1 字体:正文倾向衬线,UI 用无衬线
- **行业主流是「正文可选衬线、默认偏衬线;UI chrome 用系统无衬线」**。Matter 提供约 10 款字体,主打阅读级衬线:New York、Valkyrie、Lyon、Literata,早期默认 Amazon Bookerly(被评为"最美阅读字体");Paper 主题 + 衬线营造"报纸感"(https://thesweetsetup.com/is-matter-or-readwise-reader-the-read-later-app-for-you)。
- Instapaper 提供 14 款字体,多款为 App 专门定制,含 Baskerville、Palatino,甚至 Dyslexie(阅读障碍友好),被评价为"读起来不输纸印"(https://thesweetsetup.com/apps/best-read-it-later-service)。
- Craft 只给 4 款字体且全部来自 Apple 自家:System(SF)、Serif(New York,即 Apple Books 同款)、Mono、Round——证明"少而精 + 全原生"在 Mac 上完全成立(https://www.macstories.net/reviews/craft-review-a-powerful-native-notes-and-collaboration-app)。
- Apple 自家长文场景(Books / News 文章页)用 New York 衬线;HIG 明确**避免 Ultralight/Thin/Light 字重**,正文用 Regular–Medium(https://developer.apple.com/design/human-interface-guidelines/typography)。
- 共识:**衬线用于"读",无衬线用于"操作"**;衬线在 Retina 屏上已无渲染劣势,且能在心理上把"阅读区"与"工具区"分开。

### 1.2 行宽(measure):50–75 字符,理想 66
- 经典排印学(Bringhurst《The Elements of Typographic Style》)与 Wikipedia 综述:45–75 cpl 可接受,**66 cpl 为理想**;CSS 可直接用 `66ch`(https://en.wikipedia.org/wiki/Line_length)。
- Baymard 大规模测试:50–75 cpl 最优,>100 cpl 显著疲劳;WCAG 1.4.8 上限 80 cpl,**中日韩文本上限 40 字符**(https://baymard.com/blog/line-length-readability)。
- 中文正文换算:约 **32–40 个全角字/行**;Whetstone 中英混排应按"更严的 CJK 限制"取窄。

### 1.3 字号 / 行高 / 段距
- 桌面长文正文事实标准:**17–21px 字号、行高 1.5–1.7、段距约 0.8–1.5em**;Instapaper 把字号、行距、边距做成三个**独立**滑杆,被认为是其阅读体验超越同类的关键("fiddly but huge impact",https://thesweetsetup.com/apps/best-read-it-later-service)。
- Instapaper Android 5.0 改版专门"调大默认字号与行高"作为卖点(https://blog.instapaper.com/post/746654374752878592/instapaper-android-50-article-list-redesign)——默认值要偏大、偏松,不要指望用户去调。
- 左对齐不两端对齐(避免 dyslexia 用户的"river effect");Apple Books 把 Justify 做成可关的开关(https://blogs.oregonstate.edu/calverta/line-width-in-digital-typography-for-accessibility-and-comprehension)。

### 1.4 阅读底色:暖白/纸感优于纯白,暖深灰优于纯黑
- **浅色**:纯白 #FFF 被普遍认为"刺眼";Instapaper 提供 White / **Sepia(米褐)** 两档浅色,且有 Twilight 模式随日落从白→sepia→黑渐变(https://thesweetsetup.com/apps/best-read-it-later-service)。Apple Books 五主题(Quiet / Paper / Bold / Calm / Focus)同样以纸感底色为主(https://www.idownloadblog.com/2022/09/21/how-to-use-themes-in-books-app-on-ipad-iphone)。
- **深色**:共识是**避免纯黑 #000**——白字配纯黑对比过狠、OLED 滚动有拖影;推荐 **#121212–#1E1E1E 深灰**(Material 基准 #121212,仅比纯黑多耗电 0.3%),文字用 #E8E8E8 级灰白而非纯白(https://weareaffective.com/learning-centre/how-do-i-make-sure-my-apps-dark-mode-doesnt-strain-users-eyes、https://atmos.style/blog/dark-mode-ui-best-practices)。Instapaper 深色默认即"dark gray + light gray text",真黑(true black)只是给 OLED 党的可选开关(https://veroniiiica.com/instapaper-accessibility)。Matter 的多档深色模式被赞"不会像 Reader 那样在夜里闪你一脸白字"(https://robertbreen.com/2025/02/27/elevate-your-online-reading-with-matter)。
- 注意:多项研究表明**浅色正极性下阅读理解/校对成绩更好**(https://atmos.style/blog/dark-mode-ui-best-practices)——深色模式是"环境适配",不是"默认更好"。

---

## 2. 沉浸 / 专注模式做法

| 手法 | 代表产品 | 要点 |
|---|---|---|
| **chrome 自动淡出** | iA Writer、Apple Books | iA Writer "一旦开始输入,菜单与窗口装饰全部消失,只剩文字 + 字数"(https://ia.net/topics/an-adhd-friendly-writing-app);Books 阅读时工具栏隐藏,点一下页面才唤出 |
| **滚动隐藏工具栏** | Matter、Safari Reader、Readwise Reader | 下滚收起、上滚或点击召回;Reader 桌面端用 `[` `]` 收起左右侧栏,全键盘驱动(https://docs.readwise.io/reader/docs/faqs/navigation) |
| **Focus 单句/单段高亮** | iA Writer(标杆) | 当前句/段保持全黑,其余 dim;另有 Typewriter 滚动(光标垂直居中)。New Yorker 称其为"给写作者的马眼罩",情绪价值与功能价值并重(https://ia.net/writer/support/editor/focus-mode、https://www.newyorker.com/magazine/2021/12/20/can-distraction-free-devices-change-the-way-we-write) |
| **进度指示** | Instapaper、Books、Matter | Instapaper 把旧的"圆点进度"换成**预计阅读时长**(列表)+ 页内进度条(https://blog.instapaper.com/post/746654374752878592);Books 显示"本章剩余 X 页";共识:列表里给"X min read",文内给低调进度(细条或边缘指示),**不用百分比数字打断心流** |
| **位置即进度** | 新版 Reeder | 干脆取消未读计数,只同步"时间线位置",把"清零焦虑"从产品里删掉(https://reederapp.com) |
| **链接不出走** | Matter | 文内链接点开是浮层预览,可一键存入队列,点边缘返回原文——保护沉浸的典型控件(https://robertbreen.com/2025/02/27/elevate-your-online-reading-with-matter) |

---

## 3. 标注 / 高亮 / 笔记 UX + AI 伴读交互形态

### 3.1 高亮/笔记
- **选中 → 轻量 popover(高亮/笔记/分享)是统一范式**;Matter 被认为做得最好:高亮色刻意用**低饱和黄**避免干扰阅读;点高亮弹出上下文菜单可加笔记、可生成"quote shot"分享图;右上角一键查看本文全部高亮与笔记(https://thesweetsetup.com/is-matter-or-readwise-reader-the-read-later-app-for-you)。
- **margin/侧栏笔记**:Hypothesis / Google Docs 模式——正文只留高亮痕迹,评论体收进右侧 sidebar,可折叠;Docs 的优势是"原生选区直接挂评论 + 移动端评论浮在底部可横滑"(https://tomcritchlow.com/2019/02/12/annotations)。结论:**正文内只留最轻的锚痕(下划线/淡高亮/小气泡),重内容放侧栏或浮层**——Whetstone 现有 inline thread 方向与此一致。
- Readwise Reader 高亮支持颜色、嵌套、标签、附笔记,并自动回流到间隔重复复习(Daily Review)——"高亮不是终点,是学习闭环的入口"(https://www.speedreadinglounge.com/readwise-reader-review)。

### 3.2 AI 伴读(Ghostreader 为最成熟参照)
- **触发**:选中文字按 `G`(选区级)/ `Shift+G`(全文级);选区长短决定预设 prompt 集(选 1–4 个词→词典/百科;选长段→解释/简化/翻译)(https://docs.readwise.io/reader/guides/ghostreader/overview)。
- **演进方向**:Ghostreader 已从"按钮出结果"**收敛进统一 Chat 侧栏**——选区问答、全文摘要、生成思考题都进同一对话流,可追问;文档级回答还会写入 Document Note。关键架构优势被评为"**highlight 级上下文 + 每条回答带引文链接锚回原文**"(https://www.speedreadinglounge.com/readwise-reader-review)。
- **典型 AI 动作清单**(2022 年首发即有):in-context 定义、百科查询、翻译、简化复杂句、"与作者达成共识"(come to terms)、生成阅读前思考题(https://blog.readwise.io/the-next-chapter-of-reader-public-beta)。
- Craft 的 AI 走"文档助手"路线(起草/总结/头脑风暴,本地小模型 + 云端 Claude 可选)(https://aiproductivity.ai/tools/craft);iA Writer 反向做 **Authorship**:标记哪些字是你写的、哪些是 AI 贴的——"AI 内容显式可辨"是差异化的伦理姿态(https://ia.net/writer)。
- 对 Whetstone 最重要的同行结论:**AI 回答必须锚回原文(引用可点击跳转),且全部 AI 入口收敛到一个对话面,而不是散落的按钮**。

---

## 4. 信息架构惯例(进度 / 队列 / 归档 / 标签)

- **四桶 triage 模型(Readwise Reader)**:Inbox(新进)→ Later(想读)→ Archive(读完/放弃)→ Shortlist(精选);Library 与 Feed(订阅流)分开,**手动收藏的永久库永不被订阅流污染**(https://blog.readwise.io/p/f8c0f71c-fe5f-4025-af57-f9f65c53fed7)。用户实测:这套桶 + 快捷键 + auto-advance(处理完自动跳下一篇)让"每日 15 分钟清队列"成为可持续习惯(https://talk.macpowerusers.com/t/help-me-figure-out-a-read-it-later-workflow/31010、https://fourhourfreedom.substack.com/p/how-i-use-readwise-reader-to-organise)。
- **列表元数据惯例**:缩略图 + 标题 + 来源 + **预计阅读时长**(Instapaper 5.0 以读时取代进度点,https://blog.instapaper.com/post/746654374752878592);NetNewsWire 时间线单元格定高(利扫读)、信息只有标题/首行/日期/来源四件套(https://inessential.com/2018/10/09/the_design_of_netnewswires_timeline.html)。
- **标签轻量化**:Bear 用 `#tag` 内联打标签;Reader 标签 + 过滤查询生成自定义视图("你自己的算法");新版 Reeder 任何 tag 可变成公开 JSON feed 分享(https://reederapp.com)。
- **进度同步代替未读计数**:Reeder 的"timeline position sync"——对长阅读产品,"接着上次读"比"还剩多少没读"更健康。
- **继续阅读 hero**:Matter/Books 都把"上次读到一半的那篇"放在首屏最大位——Whetstone 的 `ContinueReadingHero` 已符合此惯例,应保留并强化。

---

## 5. 各产品设计哲学一句话

| 产品 | 一句话哲学 |
|---|---|
| **Readwise Reader** | 「为重度读者造的动力工具」:全格式入一库、全键盘驱动、AI 与高亮都服务于"读过的东西必须留下来"的知识闭环(https://blog.readwise.io/the-next-chapter-of-reader-public-beta) |
| **Matter** | 「排版即产品」:用杂志级衬线、克制的高亮色和不打断心流的链接预览,把"读"本身做成奢侈品——并且已整体迁移到 iOS 26 Liquid Glass,"全原生组件、让内容发光"(https://apps.apple.com/us/app/matter-reading-app/id1501592184) |
| **Instapaper** | 「无装饰的纸」:18 年只做一件事——把网页还原成一张可以无限调校(字体/字距/底色/日落变色)的安静纸面(https://blog.instapaper.com/post/170231611161) |
| **新版 Reeder** | 「删掉焦虑的时间线」:取消未读计数、只同步阅读位置,无算法纯时序,让"跟上互联网"不再是债务(https://reederapp.com) |
| **Craft** | 「Apple 原生的美感即功能」:四款 SF/NY 字体、块编辑、处处系统能力,是"Notion 想成为却成不了的原生体验"(https://www.macstories.net/reviews/craft-review-a-powerful-native-notes-and-collaboration-app) |
| **Bear 2** | 「工具退后,文字向前」:Markdown 语法按需显隐、一个快捷键万物消失只剩字,优雅是默认值不是主题(https://robertbreen.com/2024/02/23/bear-2-for-writing-and-thinking) |
| **NetNewsWire** | 「质量就是最重要的功能」:不崩溃、零 bug、轻如空气的快,宁可慢加功能也不伤手感(https://netnewswire.com/philosophy.html) |
| **iA Writer** | 「给注意力戴马眼罩」:Focus Mode 单句高亮 + 一切 chrome 消失,把"当下这一句"变成全世界(https://ia.net/writer) |
| **Apple Books / News** | 「主题化的纸书隐喻」:Quiet/Paper/Bold/Calm/Focus 五套打包主题(底色×字体×间距),用户选"氛围"而不是调参数(https://www.idownloadblog.com/2022/09/21/how-to-use-themes-in-books-app-on-ipad-iphone) |

---

## 6. 给 Whetstone 的 12 条可执行启示(控件/页面级)

1. **ReaderPane 正文换衬线 + 锁行宽**:正文默认 New York(`.fontDesign(.serif)` 或 NSFont New York),中文回退苹方;行宽锁 `min(可用宽, ~680pt)`(约 66 英文字符 / 36 全角字),居中,两侧留白交给 Liquid Glass 背景。标题保留大号但从 42px 无衬线改为衬线 display。
2. **底色放弃 cream/sage 双色块,改为「纸感双模式」token**:浅色用暖白(参照 Books Paper/Instapaper Sepia 倾向,如 #FAF8F2 级),深色用暖深灰 **#16181A–#1E1E1E,绝不用纯黑**;正文文字浅色 #1A1A1A→深色 #E6E3DD 级灰白。左右栏不再用对比色块,而是同底色上的 Liquid Glass 材质层级(`glassEffect`/`NSGlassEffectView`),靠模糊与浮起区分区域。
3. **阅读时 chrome 淡出**:ReaderPane 滚动向下时,顶部 header 与左右栏自动减淡/收窄(Liquid Glass 的 scroll edge effect 正适合);鼠标移动或上滚恢复。给一个显式「专注阅读」开关(⌘.)一键收起左右两栏只剩正文——参照 iA Writer/Books。
4. **新增 Focus 段落模式(可选)**:阅读区开关:当前视口中央段落全对比度、其余段落降到 ~55% 不透明度,随滚动平滑过渡——iA Writer 的 Focus Mode 移植到"读"场景,与"AI 逐段伴读"天然配对(AI 可针对当前 focus 段提问)。
5. **进度改为「时长 + 细条」**:ArticleRowCard 显示"约 X 分钟·已读 Y%";ReaderPane 顶边缘加 2pt 锈红→中性色的滚动进度细条,文内不出现百分比数字。续读入口保留 `ContinueReadingHero`(符合 Matter/Books 惯例)。
6. **AIPane 收敛为唯一 AI 入口 + 回答锚回原文**:学 Ghostreader 把"概念卡、inline ask、苏格拉底 quiz"都呈现在同一对话流里(quiz 是对话内的一种回合),并给 AI 回答中的原文引用加可点击锚(点击滚动到原文句子并短暂高亮)——这是 Reader 被公认的架构优势,Whetstone 已有 anchorStart/End 坐标系,补"反向跳转"即可。
7. **选区 popover 按选区长度分流**:学 Ghostreader——选 1–4 个词时 popover 提供「释义 / 翻译」快捷项;选整句/段时提供「高亮 / Ask / 简化解释」;快捷键 `G` 直接对选区发问,降低鼠标依赖。
8. **inline thread 气泡保持"最轻锚痕"**:正文内只留下划线 + 小圆点(现状正确),但卡片应迁移为 Liquid Glass 浮层材质,且加"在右栏继续"之外的**折叠为 margin 指示**——参照 Hypothesis/Google Docs:重内容永远不常驻正文层。
9. **库区四桶 + auto-advance**:LibraryHome 在现有过滤上显式化 Inbox / Later / Archive(+ Shortlist 可后置);文章读完(滚动到底或手动归档 `E`)自动跳下一篇待读——Reader 用户验证过的"15 分钟清队列"习惯回路,与 Whetstone 的学习闭环(读完→quiz)可以串成一条链。
10. **未读焦虑做减法**:学新版 Reeder——列表不挂未读红点计数,只用细微的视觉差(标题字重/小圆点)区分未读,主指标是"继续读"位置;锈红 accent 在新主题下保留为唯一强调色,但深色模式下需调亮(如 #D9603E)保证对比度。
11. **主题打包而非散参数**:不暴露十个排版滑杆,学 Apple Books 提供 2–3 套打包主题(如「纸面」「夜读」+「专注」变体 = 底色×字号×行高×段距的预设),外加一个全局字号步进(⌘+/-);Instapaper 式的精调入口收进设置页二级。
12. **把「质量手感」写进验收协议**:NetNewsWire 的哲学落到工程——新视觉协议中增加硬性检查项:滚动 60fps、窗口 resize 无闪烁、玻璃层级不超过两层叠加、深浅模式切换全 token 化无硬编码颜色;Matter 的 iOS 26 重构证明 Liquid Glass 改造的正确姿势是"**全原生组件 + 让内容发光**",而不是给旧布局刷玻璃质感(https://apps.apple.com/us/app/matter-reading-app/id1501592184)。

### 关键来源索引
- Ghostreader 文档与演进:https://docs.readwise.io/reader/guides/ghostreader/overview 、https://blog.readwise.io/the-next-chapter-of-reader-public-beta 、https://www.speedreadinglounge.com/readwise-reader-review
- Matter 设计与 Liquid Glass 重构:https://www.macstories.net/reviews/matter-a-fresh-take-on-read-later-apps 、https://thesweetsetup.com/is-matter-or-readwise-reader-the-read-later-app-for-you 、https://apps.apple.com/us/app/matter-reading-app/id1501592184
- Instapaper 排版与底色:https://thesweetsetup.com/apps/best-read-it-later-service 、https://veroniiiica.com/instapaper-accessibility 、https://blog.instapaper.com/post/746654374752878592
- 行宽研究:https://en.wikipedia.org/wiki/Line_length 、https://baymard.com/blog/line-length-readability
- 深色模式:https://weareaffective.com/learning-centre/how-do-i-make-sure-my-apps-dark-mode-doesnt-strain-users-eyes 、https://atmos.style/blog/dark-mode-ui-best-practices
- Focus/沉浸:https://ia.net/writer/support/editor/focus-mode 、https://www.newyorker.com/magazine/2021/12/20/can-distraction-free-devices-change-the-way-we-write
- IA/队列:https://blog.readwise.io/p/f8c0f71c-fe5f-4025-af57-f9f65c53fed7 、https://talk.macpowerusers.com/t/help-me-figure-out-a-read-it-later-workflow/31010 、https://reederapp.com
- 哲学:https://netnewswire.com/philosophy.html 、https://inessential.com/2018/10/09/the_design_of_netnewswires_timeline.html 、https://www.macstories.net/reviews/craft-review-a-powerful-native-notes-and-collaboration-app 、https://robertbreen.com/2024/02/23/bear-2-for-writing-and-thinking
- 标注 UX:https://tomcritchlow.com/2019/02/12/annotations
- Apple Books 主题:https://www.idownloadblog.com/2022/09/21/how-to-use-themes-in-books-app-on-ipad-iphone 、https://support.apple.com/en-my/guide/iphone/iphc1af7c57/ios