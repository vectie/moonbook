# Search interviews and meetings by their timed quotes

Export a meeting, interview, lecture or customer call as a local UTF-8 `.vtt`
(WebVTT) or `.srt` file, then use ordinary source ingestion:

```text
moonbook wiki init ./research-book
moonbook wiki ingest ./research-book /absolute/path/Aurora-workshop.vtt
moonbook wiki query ./research-book "Orchid escalation desk"
```

From an initialized Book, `moonbook wiki ingest interview.vtt` and
`moonbook wiki ingest . interview.srt` also work. Relative inputs resolve inside
the selected Book. Uppercase `.VTT` and `.SRT` work. No meeting account,
recording upload, transcription service, audio/video fetch or network access is
involved. The title comes from the input filename.

The complete original is copied into `raw/imported/transcript.vtt` or
`transcript.srt` before parsing. A searchable source page contains every spoken
cue, in export order, with normalized time offsets and supplied speaker labels:

```text
[00:12:34.500 --> 00:12:40.000] Mei & Lin: Orchid escalation desk closes Friday.
```

Search matches later cues as well as the beginning of the transcript. Ordinary
short-caption search excerpts keep the offset next to the quote. Inspect the
source in Book search to read the complete transcript or download the exact
retained original. Collect it with other sources, add notes, save/resume the
collection, and export a Markdown research brief containing the timed quotes.
The original recording is not available through this import; use the offset in
your own player. Times are media offsets, not meeting dates or wall-clock times.

The projection folds caption line wraps into spaces, decodes common entities,
and renders source text inertly inside a fence. WebVTT voice tags become
`Speaker: text`. Common styling and inline karaoke timestamps are removed from
the readable projection. Header metadata, cue IDs/settings, NOTE, STYLE and
REGION blocks remain only in the original. Unrecognized inline tags remain
literal text. Existing search snippets are limited to 220 code units; inspect
the source when a long cue's matching word falls beyond that excerpt.

## Supported local export shape

- UTF-8, optional BOM; CRLF, LF or CR newlines. At most 1 MiB per file, 5,000
  cues, and 16,384 UTF-16 code units of payload per cue. Bytes are read before
  the file bound is checked.
- WebVTT starts with `WEBVTT`, optional header text/metadata, then a blank line.
  Cues have an optional identifier, timing line, and nonempty payload, separated
  by blank lines. `MM:SS.mmm` and `HH:MM:SS.mmm` are supported. Hours are two
  digits (00–99); minutes/seconds are 00–59, milliseconds are three digits.
  Cue layout settings are ignored. NOTE, STYLE and REGION blocks are skipped.
- SRT cues have a numeric identifier, `HH:MM:SS,mmm --> HH:MM:SS,mmm`, and
  nonempty text, with blank lines between cues. SRT positioning extensions are
  unsupported. Textual speaker labels, such as `Mei:`, are retained.
- Cue end must be after start. Overlap and non-chronological export order are
  preserved; there is no sorting, deduplication or inferred chronology.
- WebVTT voice spans (including voice classes), b/i/u/c/ruby/rt/lang styling,
  and inline timestamps are projected as plain text. SRT b/i/u tags are stripped.
  Supported named entities: amp, lt, gt, nbsp, lrm, rlm, quot, apos. Other
  entities and tags stay literal. This is a bounded text reader, not a complete
  [WebVTT renderer](https://www.w3.org/TR/webvtt1/).

## Repeat or repair an import

Every import appends a new snapshot. Repeating the same export creates suffixed
raw and page paths; previous versions stay untouched. There is no automatic
merging of rolling captions, speaker matching, translation or diarization.

Within the file bound, malformed timing, invalid UTF-8, unsupported control
characters, empty payloads or cue-limit errors retain the original and report
its path. No partial source page is created on parse failure, even if earlier
cues were valid. Re-export or fix the input, then import again. Oversized files
are rejected before retention. One operator/import at a time is supported;
the existing multi-file index updates are not transactional.

Speaker labels, timestamps and statements are supplied evidence, not verified
identity, transcription accuracy or factual acceptance. Existing `accepted` /
`verified` metadata mechanics are unchanged. Review private meeting content
before sharing the original or research brief.
