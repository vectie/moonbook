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
  SnapshotUnavailable
  SnapshotStale
  SnapshotWaiting
  SnapshotRetained
  SnapshotMissing
  SnapshotLiveMode
  SnapshotStaticMode
  SnapshotRetry
  SnapshotRefresh
  SnapshotDetails
  HeroEyebrow
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
    (SimplifiedChinese, SidebarLoaded) => "工作区快照已加载。"
    (SimplifiedChinese, SnapshotUnavailable) => "工作区快照不可用。"
    (SimplifiedChinese, SnapshotStale) => "工作区快照可能已过期。"
    (SimplifiedChinese, SnapshotWaiting) =>
      "正在读取工作区快照，尚未加载工作区数据。"
    (SimplifiedChinese, SnapshotRetained) =>
      "正在显示上次成功读取的数据；数据可能已过期。"
    (SimplifiedChinese, SnapshotMissing) =>
      "尚未加载工作区数据。重试以读取快照。"
    (SimplifiedChinese, SnapshotLiveMode) =>
      "已配置自动更新。需要时也可刷新快照。"
    (SimplifiedChinese, SnapshotStaticMode) =>
      "静态快照模式：未启用自动更新。刷新以重新读取快照。"
    (SimplifiedChinese, SnapshotRetry) => "重试快照"
    (SimplifiedChinese, SnapshotRefresh) => "刷新快照"
    (SimplifiedChinese, SnapshotDetails) => "快照诊断详情"
    (SimplifiedChinese, HeroEyebrow) => "知识工作区"
    (SimplifiedChinese, WorkflowTitle) => "工作流界面"
    (SimplifiedChinese, WorkflowSubtitle) =>
      "此界面使用生成的工作区状态呈现当前 MoonBook 流程，而不是硬编码的演示计数。"
    (SimplifiedChinese, BookkeeperTitle) => "Bookkeeper 闭环"
    (SimplifiedChinese, BookkeeperSubtitle) =>
      "选择一条持久记录，由具名人工审核，并重放日志以验证结果。"
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
    (_, SidebarLoaded) => "Workspace snapshot loaded."
    (_, SnapshotUnavailable) => "Workspace snapshot unavailable."
    (_, SnapshotStale) => "Workspace snapshot may be out of date."
    (_, SnapshotWaiting) =>
      "Reading the workspace snapshot. Workspace data has not loaded yet."
    (_, SnapshotRetained) =>
      "Showing the last successful read; this data may be out of date."
    (_, SnapshotMissing) =>
      "Workspace data has not loaded. Retry to read the snapshot."
    (_, SnapshotLiveMode) =>
      "Automatic updates are configured. You can also refresh the snapshot."
    (_, SnapshotStaticMode) =>
      "Static snapshot mode: automatic updates are off. Refresh to read the snapshot again."
    (_, SnapshotRetry) => "Retry snapshot"
    (_, SnapshotRefresh) => "Refresh snapshot"
    (_, SnapshotDetails) => "Snapshot diagnostics"
    (_, HeroEyebrow) => "Knowledge workspace"
    (_, WorkflowTitle) => "Workflow Surface"
    (_, WorkflowSubtitle) =>
      "The UI mirrors the current MoonBook loop using generated workspace state instead of hardcoded demo counters."
    (_, BookkeeperTitle) => "Bookkeeper Closed Loop"
    (_, BookkeeperSubtitle) =>
      "Select a durable record, review it with named-human authority, and replay the journal to verify the outcome."
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
  }
}

///|
#cfg(target="js")
extern "js" fn browser_interface_locale() -> String = "()=>{let stored=null;try{const cookie=document.cookie.match(/(?:^|; )moonsuite_interface_locale=([^;]+)/);stored=cookie?decodeURIComponent(cookie[1]):localStorage.getItem('moonsuite.interfaceLocale')}catch(_){}const raw=!stored||stored==='system'?(globalThis.navigator?.languages?.[0]||globalThis.navigator?.language||'en-US'):stored;return /^(zh(?:-|_)(?:Hans|CN|SG)|zh$)/i.test(raw)?'zh-Hans':'en-US'}"

///|
#cfg(target="js")
extern "js" fn persist_browser_interface_locale(locale : String) = "(locale)=>{try{document.cookie='moonsuite_interface_locale='+encodeURIComponent(locale)+'; Path=/; Max-Age=31536000; SameSite=Lax';localStorage.setItem('moonsuite.interfaceLocale',locale)}catch(_){}document.documentElement.lang=locale;document.documentElement.dir='ltr'}"

///|
#cfg(target="js")
extern "js" fn use_browser_system_locale() = "()=>{try{document.cookie='moonsuite_interface_locale=system; Path=/; Max-Age=31536000; SameSite=Lax';localStorage.setItem('moonsuite.interfaceLocale','system')}catch(_){}const raw=globalThis.navigator?.languages?.[0]||globalThis.navigator?.language||'en-US';document.documentElement.lang=/^(zh(?:-|_)(?:Hans|CN|SG)|zh$)/i.test(raw)?'zh-Hans':'en-US';document.documentElement.dir='ltr'}"

///|
extern "js" fn browser_system_locale() -> String = "()=>/^(zh(?:-|_)(?:Hans|CN|SG)|zh$)/i.test(globalThis.navigator?.languages?.[0]||globalThis.navigator?.language||'en-US')?'zh-Hans':'en-US'"

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
