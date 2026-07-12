///|
pub(all) struct ExecutableDocument {
  contract_id : String
  book_id : String
  revision : String
  declarations : Array[BookkeeperAction]
  execution_bindings : Array[ExecutableExecutionBinding]
  source_digest : String
  recorded_at : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExecutableExecutionBinding {
  declaration_id : String
  operation : String
  input_contracts : Array[String]
  output_contracts : Array[String]
  required_claim : String
  input_artifacts : Array[String]
  timeout_ms : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ExecutableCompileRecord {
  declaration_path : String
  graph_path : String
  graph : Json
} derive(Debug, Eq, ToJson)

///|
fn executable_bindings_for_actions(
  actions : Array[BookkeeperAction],
  input_artifact : String,
) -> Json {
  Json::array(
    actions.map(action => {
      (
        {
          "declaration_id": action.declaration_id,
          "operation": action.kind,
          "input_contracts": ["moonbook.bookkeeper-reflection.v1"],
          "output_contracts": ["moonsuite.evidence-envelope.v1"],
          "required_claim": "execution-result",
          "input_artifacts": [input_artifact],
          "timeout_ms": 120000,
        } : Json)
    }),
  )
}

///|
pub fn executable_authority_is_canonical(authority : String) -> Bool {
  [
    "observe", "cognitive-maintenance", "sandbox-execution", "workspace-mutation",
    "external-effect", "physical-effect",
  ].contains(authority)
}

///|
pub fn executable_source_digest_is_valid(digest : String) -> Bool {
  if digest.length() != 71 || !digest.has_prefix("sha256:") {
    return false
  }
  for index in 7..<digest.length() {
    let unit = digest[index]
    if !((unit >= '0' && unit <= '9') || (unit >= 'a' && unit <= 'f')) {
      return false
    }
  }
  true
}

///|
pub fn executable_sha256(text : String) -> String {
  let hex = @crypto.sha256(@utf8.encode(text))
    .map(byte => byte.to_hex())
    .join("")
  "sha256:\{hex}"
}

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
fn decode_execution_binding(value : Json) -> ExecutableExecutionBinding raise {
  let fields = bk_object(value)
  {
    declaration_id: safe_observation_id(bk_string(fields, "declaration_id")),
    operation: bk_string(fields, "operation"),
    input_contracts: bk_strings(fields, "input_contracts"),
    output_contracts: bk_strings(fields, "output_contracts"),
    required_claim: bk_string(fields, "required_claim"),
    input_artifacts: bk_strings(fields, "input_artifacts"),
    timeout_ms: bk_double(fields, "timeout_ms").to_int(),
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
  let execution_bindings = match fields.get("execution_bindings") {
    Some(Array(values)) => values.map(value => decode_execution_binding(value))
    _ => fail("executable document requires execution_bindings array")
  }
  {
    contract_id,
    book_id: bk_string(fields, "book_id"),
    revision: safe_observation_id(bk_string(fields, "revision")),
    declarations,
    execution_bindings,
    source_digest: bk_string(fields, "source_digest"),
    recorded_at: bk_string(fields, "recorded_at"),
  }
}

///|
fn ExecutableDocument::binding_for(
  self : ExecutableDocument,
  declaration_id : String,
) -> ExecutableExecutionBinding? {
  for binding in self.execution_bindings {
    if binding.declaration_id == declaration_id {
      return Some(binding)
    }
  }
  None
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
  if !executable_source_digest_is_valid(self.source_digest) {
    issues.push("source_digest must be a lowercase sha256 digest")
  }
  if self.declarations.is_empty() {
    issues.push("at least one executable declaration is required")
  }
  if self.execution_bindings.length() != self.declarations.length() {
    issues.push("every declaration requires exactly one execution binding")
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
    if !executable_authority_is_canonical(declaration.requested_authority) {
      issues.push(
        "requested_authority is not canonical: \{declaration.declaration_id}",
      )
    }
  }
  for declaration in self.declarations {
    guard self.binding_for(declaration.declaration_id) is Some(binding) else {
      issues.push("missing execution binding: \{declaration.declaration_id}")
      continue
    }
    if binding.operation.trim().is_empty() ||
      binding.input_contracts.is_empty() ||
      binding.output_contracts.is_empty() ||
      binding.required_claim.trim().is_empty() ||
      binding.input_artifacts.is_empty() ||
      binding.timeout_ms <= 0 {
      issues.push("incomplete execution binding: \{declaration.declaration_id}")
    }
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
    let binding = document.binding_for(declaration.declaration_id).unwrap()
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
        "operation": binding.operation,
        "input_contracts": binding.input_contracts.to_json(),
        "output_contracts": binding.output_contracts.to_json(),
        "required_claim": binding.required_claim,
        "input_artifacts": binding.input_artifacts.to_json(),
        "timeout_ms": binding.timeout_ms,
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
