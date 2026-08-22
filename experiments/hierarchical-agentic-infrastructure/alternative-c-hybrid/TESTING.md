# Alternative C Test Matrix

| Scenario | Expected result |
| --- | --- |
| Full chain from Lumen | Northstar → Aurora → Lumen maps are returned in order. |
| Metadata-only inspection | Resource names and declaring paths appear; `BODY-SENTINEL` values do not. |
| Direct-child routing | Northstar exposes Aurora and Solstice map metadata without loading their resources. |
| Sibling isolation | Lumen's effective ancestor chain contains no Solstice resource or marker. |
| Missing company ancestor | The copied Aurora subtree remains valid with a boundary warning. |
| Nested repository | A nested Git repository at Aurora does not change the declared context chain. |
| Platform adapters | Generation followed by `--check` succeeds without copying context or skill bodies. |

Native discovery may surface the same instruction and skill chain, but every structural expectation is validated through registered paths and the scope tool rather than depending on a platform session.
