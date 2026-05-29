import SwiftUI
import SwiftData
import WhetstoneCore

/// V1.0 单窗口三区工作台:左(导航 + 上下文文章列表)| 中(文章库主场 / 阅读器)| 右(AI 伴)。
/// 左右栏一键滑动折叠(drive 曲线 + clip)。持有上提状态;选择驱动中栏/左栏双模态。
struct WorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @Query(sort: \Article.fetchedAt, order: .reverse) private var articles: [Article]

    @AppStorage("aiEnhanceLayout") private var aiEnhanceLayout: Bool = false
    @AppStorage("leftSidebarOpen") private var leftOpen: Bool = true
    @AppStorage("rightSidebarOpen") private var rightOpen: Bool = true
    @AppStorage("aiPaneWidth") private var aiPaneWidth: Double = 420

    @State private var selectedArticle: Article? = nil
    @State private var searchQuery: String = ""
    @State private var filter: LibraryFilter = .recent
    @State private var showAddArticle = false
    @State private var showSettings = false
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil

    @AppStorage("leftSidebarWidth") private var leftWidth: Double = 300
    @State private var leftDragStartWidth: Double? = nil
    private static let leftMin: Double = 240
    private static let leftMax: Double = 420

    var body: some View {
        HStack(spacing: 0) {
            leftContent
                .frame(width: CGFloat(leftWidth))
                .frame(maxHeight: .infinity)
                .background(Theme.bgSage)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.borderHeavy).frame(width: 1)
                }
                .frame(width: leftOpen ? CGFloat(leftWidth) : 0, alignment: .leading)
                .clipped()
                .overlay(alignment: .trailing) { if leftOpen { leftResizeHandle } }

            centerRegion
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let article = selectedArticle {
                // AIPane 自带 sage 底 + 左缘 1px 分隔 + 宽度;外层 clip 到 0 即折叠。
                AIPane(article: article)
                    .id(article.url)
                    .frame(width: rightOpen ? CGFloat(aiPaneWidth) : 0, alignment: .leading)
                    .clipped()
            }
        }
        .background(Theme.bgCream)
        .ignoresSafeArea(.container, edges: .top)
        .animation(Motion.drive, value: leftOpen)
        .animation(Motion.drive, value: rightOpen)
        .animation(Motion.drive, value: selectedArticle?.url)
        .overlay(alignment: .topLeading) { reopenLeftButton }
        .overlay(alignment: .trailing) { reopenRightButton }
        .overlay { modals }
        .background(sidebarCommands)
    }

    // MARK: - Regions

    private var leftContent: some View {
        VStack(spacing: 0) {
            SidebarNav(
                isHome: selectedArticle == nil,
                onHome: { select(nil) },
                onAddArticle: { showAddArticle = true },
                onOpenSettings: { showSettings = true },
                onCollapse: { leftOpen = false }
            )
            if selectedArticle != nil {
                ArticleListSidebar(
                    articles: articles,
                    searchQuery: $searchQuery,
                    filter: $filter,
                    selectedArticle: selectedArticle,
                    onSelect: { select($0) },
                    onDelete: deleteArticle
                )
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var centerRegion: some View {
        if let article = selectedArticle {
            ReaderPane(article: article)
                .id(article.url)
        } else {
            LibraryHome(
                articles: articles,
                onSelect: { select($0) },
                onAddArticle: { showAddArticle = true },
                onDelete: deleteArticle
            )
        }
    }

    // MARK: - Reopen affordances (when a side is collapsed to 0)

    @ViewBuilder
    private var reopenLeftButton: some View {
        if !leftOpen {
            Button { leftOpen = true } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
            .padding(.leading, 16)
            .padding(.top, 20 + Theme.titlebarInset)   // 对齐 header 行(reader 的 原文/概念 同高)
            .help("展开侧栏 (⌃⌘[)")
        }
    }

    @ViewBuilder
    private var reopenRightButton: some View {
        if !rightOpen && selectedArticle != nil {
            Button { rightOpen = true } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(EditorialButtonStyle(size: .small, variant: .secondary, iconOnly: true))
            .padding(.trailing, 8)
            .help("展开 AI 伙伴 (⌃⌘])")
        }
    }

    /// 左栏右缘的拖拽调宽手柄(对称于 AIPane 的 resize handle)。
    private var leftResizeHandle: some View {
        Color.clear
            .frame(width: 8)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .offset(x: 4)
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = leftDragStartWidth ?? leftWidth
                        if leftDragStartWidth == nil { leftDragStartWidth = start }
                        // 左栏在左侧:向右拖(translation.width 为正)= 变宽。
                        let proposed = start + Double(value.translation.width)
                        leftWidth = min(Self.leftMax, max(Self.leftMin, proposed))
                    }
                    .onEnded { _ in leftDragStartWidth = nil }
            )
    }

    // MARK: - Keyboard toggles (⌃⌘[ / ⌃⌘])

    private var sidebarCommands: some View {
        Group {
            Button("") { leftOpen.toggle() }
                .keyboardShortcut("[", modifiers: [.command, .control])
            Button("") { if selectedArticle != nil { rightOpen.toggle() } }
                .keyboardShortcut("]", modifiers: [.command, .control])
        }
        .opacity(0)
        .allowsHitTesting(false)
        .frame(width: 0, height: 0)
    }

    // MARK: - Selection

    private func select(_ article: Article?) {
        selectedArticle = article
    }

    // MARK: - Modals

    @ViewBuilder
    private var modals: some View {
        if showSettings {
            modalOverlay(onDismiss: { showSettings = false }) {
                SettingsView(onClose: { showSettings = false })
                    .frame(width: 600, height: 600)
                    .background(Theme.bgCream)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.borderHeavy, lineWidth: 1))
            }
        }
        if showAddArticle {
            modalOverlay(onDismiss: { showAddArticle = false }) {
                AddArticleSheet(
                    urlInput: $urlInput,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    onSubmit: { url in Task { await loadArticle(url: url) } },
                    onCancel: { showAddArticle = false }
                )
                .frame(width: 540)
                .background(Theme.bgCream)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.borderHeavy, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func modalOverlay<Content: View>(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
            content()
        }
        .transition(.opacity)
        .animation(Motion.flip, value: showSettings)
        .animation(Motion.flip, value: showAddArticle)
    }

    // MARK: - Data (migrated from ContentView)

    @MainActor
    private func loadArticle(url: String) async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let extracted = try await ArticleExtractor.shared.extract(urlString: url)
            var content = extracted.textContent
            var enhanced = false
            if aiEnhanceLayout, KeychainStore.shared.hasAPIKey {
                do {
                    content = try await services.ai.enhanceLayout(rawText: content)
                    enhanced = true
                } catch {
                    enhanced = false
                }
            }
            let article = Article(
                url: extracted.url,
                title: extracted.title,
                author: extracted.byline,
                content: content,
                excerpt: extracted.excerpt,
                readingTimeMinutes: max(1, extracted.textContent.split(separator: " ").count / 220),
                isLayoutEnhanced: enhanced
            )
            modelContext.insert(article)
            try modelContext.save()
            urlInput = ""
            showAddArticle = false
            selectedArticle = article
        } catch {
            Log.persistence.error("loadArticle save/extract failed: \(error.localizedDescription, privacy: .public)")
            loadError = "无法抽取文章: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteArticle(_ article: Article) {
        let articleURL = article.url
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.articleID == articleURL }
        )
        if let orphans = try? modelContext.fetch(descriptor) {
            orphans.forEach { modelContext.delete($0) }
        }
        if selectedArticle?.url == articleURL { selectedArticle = nil }
        modelContext.delete(article)
        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("deleteArticle save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
