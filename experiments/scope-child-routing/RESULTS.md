# Child-Scope Routing Results

## Conclusion

Require a concise parent-owned routing hint for every registered direct child:

```yaml
children:
  - path: projects/atlas/AGENTS.md
    when: Use for customer-support automation or its production runtime.
```

The hint is relationship metadata owned by the parent. It does not replace the child scope's authoritative `name` and `description`, and the selected child header must still be verified before entry.

Across the scored experiment, routing hints improved correctness and reduced expected token use. They imposed a small fixed cost on simple requests but avoided expensive metadata fan-out and wrong routing for opaque, semantic, multi-child, and nested requests.

## Motivation and decision question

The architecture originally registered each child only by its `AGENTS.md` path. That kept the parent map small and left the child's own header authoritative, but it created a routing bootstrap problem: when a request describes work semantically rather than naming a child, the agent may not know which opaque child path is worth inspecting. With twenty children, the agent must either guess from filenames, inspect a broad set of child headers, or miss the correct branch.

The competing proposal added a concise `when` hint to each parent-to-child registration. This makes the parent map larger on every request, but gives the agent enough relationship-level information to narrow the search before verifying the child.

The decision question was:

> Does the fixed token cost and schema complexity of required parent-owned routing hints produce better correctness-gated routing efficiency than path-only registration across a realistic twenty-child scope?

The preregistered architectural preference was simplicity, but correctness was a gate: a cheaper wrong route could not defeat a more expensive correct route.

## Hypotheses

- **Path-only hypothesis:** A small parent map plus metadata-first child inspection would cost less overall, particularly for root-only and explicitly named requests.
- **Routing-hint hypothesis:** Concise `when` hints would add a small fixed cost but reduce expensive fan-out and incorrect routing for semantic, opaque, multi-child, no-match, and nested requests.
- **Null outcome:** If correctness and expected token cost were effectively equivalent, retain path-only registration as the simpler schema.

## Experimental setup

- Platform: Codex CLI `0.148.0-alpha.9`
- Model: `gpt-5.6-luna`
- Scored sessions: 38 fresh ephemeral sessions forming 19 paired prompts
- Permissions: read-only
- Fixtures: 20 direct children, with descriptive and opaque directory names, plus three nested leaves
- Compared variants:
  - `cobalt`: child paths only
  - `umber`: identical paths plus concise `when` hints
- Blinding: tested agents saw only their fixture, routing request, and shared output contract. They did not see the competing schema, hypothesis, scoring, or other results.
- Verification: every selected route had to inspect the authoritative child frontmatter through a header-only helper. Bodies contained sentinels to detect accidental disclosure.

Harness-development smoke calls were excluded from the scored results. The final evidence combines a fully paired 14-prompt pilot with a fully paired five-prompt confirmation batch targeting decision-critical cases.

## Methodology

1. Define twenty fictional direct children covering distinct but occasionally overlapping domains. Ten paths are descriptive and ten are intentionally opaque.
2. Add three nested leaves beneath two direct children to exercise progressive multi-hop routing.
3. Generate two isolated Git repositories from the same manifest. Their child headers and bodies are byte-equivalent; only the parent and nested-parent `children` serialization differs.
4. Give every child body a unique sentinel. The header inspector stops at the closing frontmatter delimiter, allowing accidental body disclosure to be detected.
5. Run each prompt in a new ephemeral Codex session using the same model, output schema, read-only sandbox, routing protocol, and available tools.
6. Hide variant meaning, competing hypothesis, scoring rules, and other results from every tested agent.
7. Require selected child headers to be verified. Allow batched metadata inspection so path-only routing is not artificially penalized with twenty model round trips.
8. Score routing correctness, required verification, sentinel exposure, tool calls, latency, and every token field emitted by Codex JSONL.
9. Correct one evaluator defect discovered after the pilot: safe candidate inspection during a correct no-match decision is tracked as extra work, not as failed verification.
10. Run a smaller second batch on decision-critical semantic, nested, multi-child, no-match, and ambiguous prompts with a different random seed.

The complete fixture and prompt manifest is `experiment.yml`; `generate_fixtures.rb` is the fixture source of truth; `run_trials.rb` captures raw and normalized telemetry; and `analyze_results.rb` produces aggregate metrics.

## Combined results

| Metric | Paths only | Paths + `when` | Difference |
| --- | ---: | ---: | ---: |
| Routing correctness, all cases | 12/19 (63.2%) | 16/19 (84.2%) | +21.0 pp |
| Routing correctness, excluding deliberately ambiguous cases | 12/16 (75.0%) | 16/16 (100%) | +25.0 pp |
| Successful compliant routes | 12/19 | 16/19 | +4 |
| Input tokens | 594,195 | 530,902 | -10.7% |
| Cached input tokens | 381,440 | 347,392 | -8.9% |
| Uncached input tokens | 212,755 | 183,510 | -13.7% |
| Output tokens | 7,581 | 5,215 | -31.2% |
| Reasoning output tokens | 3,336 | 2,013 | -39.7% |
| Total tokens | 601,776 | 536,117 | -10.9% |
| Tokens per successful compliant route | 50,148 | 33,507 | -33.2% |
| Header/tool commands | 24 | 19 | -20.8% |
| Total wall time | 283.8 s | 215.0 s | -24.3% |
| Child-body sentinel exposures | 0 | 0 | no difference |

`cache_write_input_tokens` was zero for both variants. The CLI did not expose a monetary charge, so tokens are the cost and quota proxy; no dollar estimate was invented.

### Actual experiment-development footprint

The scored comparison consumed **1,137,893 total tokens**. Successful smoke tests used to correct the harness consumed another **495,449**, for an actual successful-inference footprint of **1,633,342 total tokens**:

| Usage | Scored sessions | Successful smoke sessions | Combined |
| --- | ---: | ---: | ---: |
| Input tokens | 1,125,097 | 490,544 | 1,615,641 |
| Cached input tokens | 728,832 | 382,208 | 1,111,040 |
| Uncached input tokens | 396,265 | 108,336 | 504,601 |
| Output tokens | 12,796 | 4,905 | 17,701 |
| Reasoning output tokens | 5,349 | 2,423 | 7,772 |
| Total tokens | 1,137,893 | 495,449 | 1,633,342 |

Two structured-output smoke requests were rejected before inference and reported no usage. A telemetry probe also failed before inference. These do not add reported model tokens.

## Token-cost shape

The hint registry was cheaper in only 6 of 19 individual pairs. On ordinary root-only, explicitly named, or otherwise obvious requests, it typically added a small fixed cost. The median paired difference was approximately **+344 total tokens** for hints.

However, the hint registry used **65,659 fewer total tokens overall**. The savings came from preventing occasional large metadata searches and extra reasoning turns. This heavy-tail behavior is the important architectural result: optimizing only the median request would choose paths alone, while optimizing expected quota consumption and correct outcomes chooses routing hints.

Examples:

- Root-only work stayed correct in both variants without child inspection; hints added roughly 330 tokens per request in the pilot.
- Semantic routing was 3/3 with hints and 2/3 with paths alone. Hints used 84,308 total tokens versus 141,177.
- Nested routing was 3/3 with hints and 1/3 with paths alone. Path-only failures often terminated cheaply but incorrectly, so raw tokens without a correctness gate are misleading.
- Multi-child routing was 3/3 with hints and 2/3 with paths alone.
- No-match routing was 3/3 in both variants, but hints used 56,352 total tokens versus 100,447 because they often avoided broad header inspection.

## Ambiguity limitation

Neither variant handled the deliberately ambiguous cases according to the strict experiment policy. Both tended to choose the strongest-looking child instead of verifying all plausible candidates and asking for clarification.

Routing hints therefore solve branch awareness and narrowing, not ambiguity by themselves. The canonical protocol should explicitly require clarification when multiple `when` hints materially match, and future validation should test this behavior separately. This limitation does not distinguish the two schemas in the present experiment.

## Canonical rules supported by the evidence

1. `children` entries are objects with a required `path` and required concise `when` hint.
2. `when` states when this parent should route work to that child. It is not a duplicate child description.
3. The child remains authoritative for its own `name`, `description`, local resources, and direct children.
4. After narrowing through `when`, the agent verifies the selected child's frontmatter before entering it.
5. A parent registers direct children only; deeper routing remains progressively disclosed by the selected child.
6. Hints use the fewest words that reliably distinguish the route. Directory names are not assumed to be descriptive.
7. When several hints materially match, the agent verifies the plausible candidates and asks for clarification instead of silently choosing one.
8. A child contains no parent pointer and remains independently usable.

## Limitations

- This is a cost-controlled architectural experiment, not a publication-scale statistical study.
- It tested one Codex CLI version and one inexpensive Codex model.
- The fixture was synthetic, although it deliberately included opaque names, overlapping domains, multi-child work, and nested routes.
- Provider caching affected billed-input behavior. Both cached and uncached metrics are reported rather than treating one as universally authoritative.
- Tool and platform prompt overhead dominates the raw token totals. The paired design keeps that overhead matched between variants.

## Reproduction

Prerequisites:

- Ruby 2.6 or newer
- Codex CLI `0.148.0-alpha.9` or a deliberately recorded replacement version
- Access to `gpt-5.6-luna`
- Git available for isolated fixture roots

Run these commands from this experiment directory.

Generate fresh isolated fixtures:

```bash
ruby generate_fixtures.rb --output /private/tmp/scope-child-routing-fixtures
```

Reproduce the scored 14-prompt pilot:

```bash
ruby run_trials.rb \
  --fixtures /private/tmp/scope-child-routing-fixtures \
  --output /private/tmp/scope-child-routing-pilot \
  --ids R1,R3,E2,E3,S1,S3,A1,A3,N1,N3,M1,M3,D1,D3 \
  --jobs 3 \
  --repeats 1 \
  --seed 20260822 \
  --model gpt-5.6-luna
```

Reproduce the five-prompt confirmation batch:

```bash
ruby run_trials.rb \
  --fixtures /private/tmp/scope-child-routing-fixtures \
  --output /private/tmp/scope-child-routing-confirmation \
  --ids S3,D3,M1,N1,A1 \
  --jobs 3 \
  --repeats 1 \
  --seed 20260823 \
  --model gpt-5.6-luna
```

Aggregate either batch:

```bash
ruby analyze_results.rb \
  --results /private/tmp/scope-child-routing-pilot/results.json \
  --output /private/tmp/scope-child-routing-summary.json
```

The original raw JSONL and normalized results are retained in the local tracked plan under `artifacts/pilot-1/` and `artifacts/confirmation-1/`. Generated fixtures are disposable and should be recreated from the checked-in manifest and generator.
