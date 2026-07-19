///|
enum InterfaceLocale {
  English
  SimplifiedChinese
} derive(Eq)

///|
enum InterfaceMessage {
  LanguageSystem
  LanguageEnglish
  LanguageSimplifiedChinese
  NavOpen
  NavWorkspaceOverview
  NavBookkeeper
  NavReviewQueue
  NavSynthesisMap
  NavKeeperState
  NavReadingSurface
  SidebarProduct
  SidebarNextStep
  SidebarRefreshing
  SidebarLoaded
  HeroEyebrow
  HeroSearchPlaceholder
  HeroRefreshing
  HeroSnapshotLive
  WorkflowTitle
  WorkflowSubtitle
  BookkeeperTitle
  BookkeeperSubtitle
  BookkeeperNoRecords
  BookkeeperEvidence
  BookkeeperIssues
  BookkeeperHumanReview
  BookkeeperAutomatedState
  BookkeeperProjectionLoaded
  BookkeeperProjectionMissing
  ReviewsTitle
  ReviewsSubtitle
  KeeperTitle
  KeeperSubtitle
  PagesTitle
  PagesSubtitle
  MapTitle
  MapSubtitle
  OperatorEyebrow
  OperatorTitle
  OperatorReaderNavigation
  OperatorDashboard
  OperatorSynthesisPanel
  OperatorSnapshotReady
}

///|
fn interface_message(
  locale : InterfaceLocale,
  message : InterfaceMessage,
) -> String {
  match (locale, message) {
    (SimplifiedChinese, LanguageSystem) => "跟随系统"
    (SimplifiedChinese, LanguageEnglish) => "English"
    (SimplifiedChinese, LanguageSimplifiedChinese) => "简体中文"
    (SimplifiedChinese, NavOpen) => "打开"
    (SimplifiedChinese, NavWorkspaceOverview) => "工作区概览"
    (SimplifiedChinese, NavBookkeeper) => "Bookkeeper 闭环"
    (SimplifiedChinese, NavReviewQueue) => "审核队列"
    (SimplifiedChinese, NavSynthesisMap) => "综合地图"
    (SimplifiedChinese, NavKeeperState) => "Keeper 状态"
    (SimplifiedChinese, NavReadingSurface) => "阅读界面"
    (SimplifiedChinese, SidebarProduct) => "MoonBook 界面"
    (SimplifiedChinese, SidebarNextStep) => "下一步"
    (SimplifiedChinese, SidebarRefreshing) => "正在刷新工作区快照。"
    (SimplifiedChinese, SidebarLoaded) => "实时工作区快照已加载。"
    (SimplifiedChinese, HeroEyebrow) => "文档控制台"
    (SimplifiedChinese, HeroSearchPlaceholder) =>
      "搜索论点、章节、概念或 Keeper 笔记"
    (SimplifiedChinese, HeroRefreshing) => "正在刷新"
    (SimplifiedChinese, HeroSnapshotLive) => "快照已上线"
    (SimplifiedChinese, WorkflowTitle) => "工作流界面"
    (SimplifiedChinese, WorkflowSubtitle) =>
      "此界面使用生成的工作区状态呈现当前 MoonBook 流程，而不是硬编码的演示计数。"
    (SimplifiedChinese, BookkeeperTitle) => "Bookkeeper 闭环"
    (SimplifiedChinese, BookkeeperSubtitle) =>
      "从交付验收到结果绑定，再到三差距学习、MoonCode 工作单和能力采用的只读治理视图。"
    (SimplifiedChinese, BookkeeperNoRecords) =>
      "等待后端生成此阶段的领域中立投影视图。"
    (SimplifiedChinese, BookkeeperEvidence) => "证据"
    (SimplifiedChinese, BookkeeperIssues) => "问题"
    (SimplifiedChinese, BookkeeperHumanReview) => "需要人工审核"
    (SimplifiedChinese, BookkeeperAutomatedState) => "确定性状态"
    (SimplifiedChinese, BookkeeperProjectionLoaded) => "投影视图已加载"
    (SimplifiedChinese, BookkeeperProjectionMissing) => "等待投影视图"
    (SimplifiedChinese, ReviewsTitle) => "审核队列"
    (SimplifiedChinese, ReviewsSubtitle) =>
      "高价值合并和提升应在成为持久 Wiki 编辑之前清晰可见。"
    (SimplifiedChinese, KeeperTitle) => "Keeper 状态"
    (SimplifiedChinese, KeeperSubtitle) =>
      "有界记忆应拥有独立的操作面板，而不是隐藏在文件名中。"
    (SimplifiedChinese, PagesTitle) => "页面族"
    (SimplifiedChinese, PagesSubtitle) =>
      "阅读界面应将维护面呈现为产品地图，而不只是 Markdown 文件。"
    (SimplifiedChinese, MapTitle) => "综合地图预览"
    (SimplifiedChinese, MapSubtitle) =>
      "覆盖范围、枢纽和开放事项的专用界面让本地规划直观可见。"
    (SimplifiedChinese, OperatorEyebrow) => "操作员备注"
    (SimplifiedChinese, OperatorTitle) => "当前界面覆盖范围"
    (SimplifiedChinese, OperatorReaderNavigation) =>
      "维护页面族的阅读导航。"
    (SimplifiedChinese, OperatorDashboard) =>
      "审核积压、证据和开放事项的仪表盘视图。"
    (SimplifiedChinese, OperatorSynthesisPanel) =>
      "反映生成规划层的综合地图面板。"
    (SimplifiedChinese, OperatorSnapshotReady) => "快照就绪"
    (_, LanguageSystem) => "System"
    (_, LanguageEnglish) => "English"
    (_, LanguageSimplifiedChinese) => "简体中文"
    (_, NavOpen) => "open"
    (_, NavWorkspaceOverview) => "Workspace Overview"
    (_, NavBookkeeper) => "Bookkeeper Loop"
    (_, NavReviewQueue) => "Review Queue"
    (_, NavSynthesisMap) => "Synthesis Map"
    (_, NavKeeperState) => "Keeper State"
    (_, NavReadingSurface) => "Reading Surface"
    (_, SidebarProduct) => "MoonBook UI"
    (_, SidebarNextStep) => "Next Step"
    (_, SidebarRefreshing) => "Refreshing workspace snapshot."
    (_, SidebarLoaded) => "Live workspace snapshot loaded."
    (_, HeroEyebrow) => "Swiss docs console"
    (_, HeroSearchPlaceholder) =>
      "Search claims, chapters, concepts, or keeper notes"
    (_, HeroRefreshing) => "Refreshing"
    (_, HeroSnapshotLive) => "Snapshot Live"
    (_, WorkflowTitle) => "Workflow Surface"
    (_, WorkflowSubtitle) =>
      "The UI mirrors the current MoonBook loop using generated workspace state instead of hardcoded demo counters."
    (_, BookkeeperTitle) => "Bookkeeper Closed Loop"
    (_, BookkeeperSubtitle) =>
      "Read-only governance from deliverable acceptance and outcome binding through Three-Gap learning, MoonCode work orders, evaluation, and capability adoption."
    (_, BookkeeperNoRecords) =>
      "Waiting for the backend to publish a domain-neutral projection for this stage."
    (_, BookkeeperEvidence) => "evidence"
    (_, BookkeeperIssues) => "issues"
    (_, BookkeeperHumanReview) => "human review required"
    (_, BookkeeperAutomatedState) => "deterministic state"
    (_, BookkeeperProjectionLoaded) => "projection loaded"
    (_, BookkeeperProjectionMissing) => "awaiting projection"
    (_, ReviewsTitle) => "Review Queue"
    (_, ReviewsSubtitle) =>
      "High-value merges and promotions should be legible before they become durable wiki edits."
    (_, KeeperTitle) => "Keeper State"
    (_, KeeperSubtitle) =>
      "Bounded memory needs its own operator panel instead of disappearing into file names."
    (_, PagesTitle) => "Page Families"
    (_, PagesSubtitle) =>
      "The reading UI should make the maintained surfaces feel like a product map, not just markdown files."
    (_, MapTitle) => "Synthesis Map Preview"
    (_, MapSubtitle) =>
      "A dedicated surface for coverage, hubs, and open loops makes local planning tangible."
    (_, OperatorEyebrow) => "Operator Notes"
    (_, OperatorTitle) => "What the UI now covers"
    (_, OperatorReaderNavigation) =>
      "Reader navigation for the maintained page families."
    (_, OperatorDashboard) =>
      "Dashboard view for review backlog, evidence, and open loops."
    (_, OperatorSynthesisPanel) =>
      "A synthesis map panel that reflects the generated planning layer."
    (_, OperatorSnapshotReady) => "Snapshot Ready"
  }
}

///|
#cfg(target="js")
extern "js" fn browser_interface_locale() -> String = "()=>{const cookie=document.cookie.match(/(?:^|; )moonsuite_interface_locale=([^;]+)/);const stored=cookie?decodeURIComponent(cookie[1]):localStorage.getItem('moonsuite.interfaceLocale');const raw=!stored||stored==='system'?(navigator.languages?.[0]||navigator.language||'en-US'):stored;return /^(zh(?:-|_)(?:Hans|CN|SG)|zh$)/i.test(raw)?'zh-Hans':'en-US'}"

///|
#cfg(target="js")
extern "js" fn persist_browser_interface_locale(locale : String) = "(locale)=>{document.cookie='moonsuite_interface_locale='+encodeURIComponent(locale)+'; Path=/; Max-Age=31536000; SameSite=Lax';localStorage.setItem('moonsuite.interfaceLocale',locale);document.documentElement.lang=locale;document.documentElement.dir='ltr'}"

///|
#cfg(target="js")
extern "js" fn use_browser_system_locale() = "()=>{document.cookie='moonsuite_interface_locale=system; Path=/; Max-Age=31536000; SameSite=Lax';localStorage.setItem('moonsuite.interfaceLocale','system');window.location.reload()}"

///|
fn initial_interface_locale() -> InterfaceLocale {
  if browser_interface_locale() == "zh-Hans" {
    SimplifiedChinese
  } else {
    English
  }
}

///|
fn persist_interface_locale_cmd(locale : InterfaceLocale) -> @rabbita.Cmd {
  let tag = if locale == SimplifiedChinese { "zh-Hans" } else { "en-US" }
  @cmd.custom_cmd(
    _ => persist_browser_interface_locale(tag),
    kind=@cmd.after_render,
  )
}

///|
fn use_system_interface_locale_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => use_browser_system_locale(), kind=@cmd.after_render)
}

///|
test "interface messages use semantic locale selection" {
  assert_eq(interface_message(English, NavOpen), "open")
  assert_eq(interface_message(SimplifiedChinese, NavOpen), "打开")
}
