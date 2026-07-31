///|
pub fn ReaderProjection::view_mode(self : ReaderProjection) -> ReaderView {
  self.view
}

///|
pub fn ReaderProjection::display_title(self : ReaderProjection) -> String {
  self.title
}

///|
pub fn ReaderProjection::revision(self : ReaderProjection) -> String {
  self.projection_revision
}

///|
pub fn ReaderProjection::content_digest(self : ReaderProjection) -> String {
  self.projection_digest
}

///|
/// Immutable record identity reviewed for the canonical source revision. This
/// is intentionally separate from the stable logical `book_id`.
pub fn ReaderProjection::canonical_subject_id(
  self : ReaderProjection,
) -> String {
  self.canonical_source_subject_id
}

///|
pub fn ReaderProjection::reading_minutes(self : ReaderProjection) -> Int {
  self.estimated_minutes
}

///|
pub fn ReaderProjection::message(self : ReaderProjection) -> String {
  self.main_message
}

///|
pub fn ReaderProjection::action(self : ReaderProjection) -> String {
  self.next_action
}

///|
pub fn ReaderProjection::reader_sections(
  self : ReaderProjection,
) -> ReadOnlyArray[ReaderSection] {
  self.sections
}

///|
pub fn ReaderProjection::source_review_status(
  self : ReaderProjection,
) -> ReaderReviewStatus {
  self.source_review.review_status()
}

///|
pub fn ReaderProjection::projection_review_status(
  self : ReaderProjection,
) -> ReaderReviewStatus {
  self.projection_review.review_status()
}

///|
pub fn ReaderSection::markdown(self : ReaderSection) -> String {
  self.body_markdown
}

///|
pub fn ReaderSection::citations(self : ReaderSection) -> ReadOnlyArray[String] {
  self.source_ref_ids
}

///|
pub fn ReaderSourceRef::source_locator(self : ReaderSourceRef) -> String {
  self.locator
}
