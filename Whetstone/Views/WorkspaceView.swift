import SwiftUI
import SwiftData
import WhetstoneCore

/// V2.0 单窗口三区工作台 —— 系统语义版:
/// 左 = NavigationSplitView sidebar(浮动玻璃),中 = detail(纸面内容层),
/// 右 = inspector(edge-to-edge 玻璃,AI 伴)。
/// V1 的手卷 HStack 折叠 / 拖宽 / 自绘 modal 全部退役,交给系统容器。
struct WorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: AppServices
    @Query(sort: \Article.fetchedAt, order: .reverse) private var articles: [Article]

    @AppStorage("aiEnhanceLayout") private var aiEnhanceLayout: Bool = false
    @AppStorage("leftSidebarOpen") private var leftOpen: Bool = true
    @AppStorage("rightSidebarOpen") private var rightOpen: Bool = true

    @StateObject private var inlineBus = InlineThreadBus()

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedArticle: Article? = nil
    @State private var searchQuery: String = ""
    @State private var filter: LibraryFilter = .recent
    @State private var showAddArticle = false
    @State private var showSettings = false
    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil

    /// 专注模式(⌘.):收双栏 + 隐 toolbar,只剩纸;AI 退化为右下玻璃胶囊。
    @State private var focusMode = false
    @State private var preFocusLeft = true
    @State private var preFocusRight = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            detailContent
        }
        .navigationTitle("Whetstone")
        .environmentObject(inlineBus)
        .onExitCommand { if focusMode { toggleFocus() } }
        .onAppear { columnVisibility = leftOpen ? .all : .detailOnly }
        .onChange(of: columnVisibility) { _, v in leftOpen = (v != .detailOnly) }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false })
                .frame(width: 600, height: 600)
        }
        .sheet(isPresented: $showAddArticle) {
            AddArticleSheet(
                urlInput: $urlInput,
                isLoading: $isLoading,
                loadError: $loadError,
                onSubmit: { url in Task { await loadArticle(url: url) } },
                onCancel: { showAddArticle = false }
            )
            .frame(width: 540)
        }
        .background(sidebarCommands)
    }

    // MARK: - Regions

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            SidebarNav(
                isHome: selectedArticle == nil,
                onHome: { select(nil) },
                onAddArticle: { showAddArticle = true },
                onOpenSettings: { showSettings = true }
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
    private var detailContent: some View {
        Group {
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
        .background(Theme.paper)
        .toolbar {
            if selectedArticle != nil {
                ToolbarItem(placement: .automatic) {
                    Button { toggleFocus() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .help("专注阅读 (⌘.)")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { rightOpen.toggle() } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .help("AI 伙伴 (⌃⌘])")
                }
            }
        }
        .toolbarVisibility(focusMode ? .hidden : .automatic, for: .windowToolbar)
        .overlay(alignment: .bottomTrailing) {
            if focusMode { focusCapsule }
        }
        .inspector(isPresented: inspectorBinding) {
            if let article = selectedArticle {
                AIPane(article: article)
                    .id(article.url)
                    .inspectorColumnWidth(min: 320, ideal: 420, max: 600)
            }
        }
    }

    /// inspector 只在阅读态有意义;浏览态强制收起但不覆写用户偏好。
    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { rightOpen && selectedArticle != nil },
            set: { rightOpen = $0 }
        )
    }

    // MARK: - Keyboard toggles (⌃⌘[ / ⌃⌘])

    private var sidebarCommands: some View {
        Group {
            Button("") {
                columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
            }
            .keyboardShortcut("[", modifiers: [.command, .control])
            Button("") { if selectedArticle != nil { rightOpen.toggle() } }
                .keyboardShortcut("]", modifiers: [.command, .control])
            Button("") { toggleFocus() }
                .keyboardShortcut(".", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .frame(width: 0, height: 0)
    }

    // MARK: - 专注模式

    private func toggleFocus() {
        if focusMode {
            focusMode = false
            columnVisibility = preFocusLeft ? .all : .detailOnly
            rightOpen = preFocusRight
        } else {
            guard selectedArticle != nil else { return }
            preFocusLeft = leftOpen
            preFocusRight = rightOpen
            focusMode = true
            columnVisibility = .detailOnly
            rightOpen = false
        }
    }

    /// 专注模式下唯一的 chrome:右下浮动玻璃胶囊(AI 入口 + 退出)。
    private var focusCapsule: some View {
        HStack(spacing: 16) {
            Button { rightOpen.toggle() } label: {
                Image(systemName: "bubble.left.and.text.bubble.right")
            }
            .buttonStyle(.borderless)
            .help("AI 伙伴 (⌃⌘])")
            Button { toggleFocus() } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(.borderless)
            .help("退出专注 (⌘. / Esc)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .padding(20)
    }

    // MARK: - Selection

    private func select(_ article: Article?) {
        selectedArticle = article
    }

    // MARK: - Data

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
