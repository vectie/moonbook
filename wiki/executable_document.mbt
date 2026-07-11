///|
pub(all) struct ExecutableDocument {
  contract_id : String
  book_id : String
  revision : String
  declarations : Array[BookkeeperAction]
  source_digest : String
  recorded_at : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExecutableCompileRecord {
  declaration_path : String
  graph_path : String
  graph : Json
} derive(Debug, Eq, ToJson)

///|
fn decode_executable_action(value : Json) -> BookkeeperAction raise {
  let fields = bk_object(value)
  {
    declaration_id: safe_observation_id(bk_string(fields, "declaration_id")),
    kind: bk_string(fields, "kind"),
    title: bk_string(fields, "title"),
    statement: bk_string(fields, "statement"),
    executor_product: bk_string(fields, "executor_product"),
    requires: bk_strings(fields, "requires"),
    acceptance_criteria: bk_strings(fields, "acceptance_criteria"),
    requested_authority: bk_string(fields, "requested_authority"),
  }
}

///|
pub fn decode_executable_document(value : Json) -> ExecutableDocument raise {
  let fields = bk_object(value)
  let contract_id = bk_string(fields, "contract_id")
  if contract_id != "moonsuite.executable-document.v1" {
    fail("unsupported executable document contract: \{contract_id}")
  }
  let declarations = match fields.get("declarations") {
    Some(Array(values)) => values.map(value => decode_executable_action(value))
    _ => fail("executable document requires declarations array")
  }
  {
    contract_id,
    book_id: bk_string(fields, "book_id"),
    revision: safe_observation_id(bk_string(fields, "revision")),
    declarations,
    source_digest: bk_string(fields, "source_digest"),
    recorded_at: bk_string(fields, "recorded_at"),
  }
}

///|
fn ExecutableDocument::has_cycle(self : ExecutableDocument) -> Bool {
  let ids = self.declarations.map(declaration => declaration.declaration_id)
  let processed : Array[String] = []
  for ;; {
    let before = processed.length()
    for declaration in self.declarations {
      if !processed.contains(declaration.declaration_id) {
        let mut ready = true
        for dependency in declaration.requires {
          if ids.contains(dependency) && !processed.contains(dependency) {
            ready = false
          }
        }
        if ready {
          processed.push(declaration.declaration_id)
        }
      }
    }
    if processed.length() == self.declarations.length() ||
      processed.length() == before {
      break
    }
  }
  processed.length() != self.declarations.length()
}

///|
pub fn ExecutableDocument::quality_issues(
  self : ExecutableDocument,
) -> Array[String] {
  let issues : Array[String] = []
  if self.book_id.trim().is_empty() {
    issues.push("book_id is required")
  }
  if self.revision.trim().is_empty() {
    issues.push("revision is required")
  }
  if self.source_digest.trim().is_empty() {
    issues.push("source_digest is required")
  }
  if self.declarations.is_empty() {
    issues.push("at least one executable declaration is required")
  }
  let ids : Array[String] = []
  for declaration in self.declarations {
    if ids.contains(declaration.declaration_id) {
      issues.push("duplicate declaration_id: \{declaration.declaration_id}")
    } else {
      ids.push(declaration.declaration_id)
    }
    if declaration.statement.trim().is_empty() {
      issues.push(
        "declaration statement is required: \{declaration.declaration_id}",
      )
    }
    if declaration.executor_product.trim().is_empty() {
      issues.push("executor_product is required: \{declaration.declaration_id}")
    }
    if declaration.acceptance_criteria.is_empty() {
      issues.push(
        "acceptance criteria are required: \{declaration.declaration_id}",
      )
    }
  }
  for declaration in self.declarations {
    for dependency in declaration.requires {
      if !ids.contains(dependency) {
        issues.push(
          "unknown declaration dependency \{dependency} for \{declaration.declaration_id}",
        )
      }
    }
  }
  if self.has_cycle() {
    issues.push("executable declarations contain a dependency cycle")
  }
  issues
}

///|
pub fn compile_executable_document(document : ExecutableDocument) -> Json raise {
  let issues = document.quality_issues()
  if !issues.is_empty() {
    fail("unqualified executable document: \{issues.join("; ")}")
  }
  let items : Array[Json] = document.declarations.map(declaration => {
    let dependencies : Array[Json] = declaration.requires.map(dependency => {
      Json::string("work-\{dependency}")
    })
    let acceptance : Array[Json] = declaration.acceptance_criteria.map(criterion => {
      Json::string(criterion)
    })
    (
      {
        "work_item_id": "work-\{declaration.declaration_id}",
        "declaration_id": declaration.declaration_id,
        "product_id": declaration.executor_product,
        "status": if dependencies.is_empty() {
          "ready"
        } else {
          "waiting"
        },
        "depends_on": dependencies,
        "acceptance_criteria": acceptance,
        "requested_authority": declaration.requested_authority,
        "attempt_count": 0,
        "blocker": "",
      } : Json)
  })
  (
    {
      "contract_id": "moonsuite.work-model.v1",
      "graph_id": "flow-\{document.book_id}-\{document.revision}",
      "book_id": document.book_id,
      "declaration_revision": document.revision,
      "source_digest": document.source_digest,
      "items": items,
      "recorded_at": document.recorded_at,
    } : Json)
}

///|
pub async fn compile_executable_document_file(
  root : String,
  document_path : String,
) -> ExecutableCompileRecord {
  let normalized_root = @pathx.normalize(root)
  ensure_bookkeeper_learning_dirs(normalized_root)
  let source = @fsx.read_file(document_path)
  let document = decode_executable_document(@json.parse(source))
  let graph = compile_executable_document(document)
  let declaration_path = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("flow/declarations/\{document.revision}.json"))
    .to_string()
  let graph_path = moonbook_wiki_path(normalized_root)
    .join(moonbook_wiki_path("flow/draft-work-graph.json"))
    .to_string()
  @fsx.write_to_file(
    declaration_path,
    document.to_json().stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(graph_path, graph.stringify(indent=2) + "\n", create=0o644)
  { declaration_path, graph_path, graph }
}
