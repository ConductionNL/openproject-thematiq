# 6. The style editor's live preview only sets custom properties; the server decides what is kept

- Status: accepted (the first step is built)
- Source: [docs/design/style-editor.md](../design/style-editor.md) ("How the live preview stays safe", "How a group is added")

## Context

The style editor shows a change at once in a preview, the way thematiq's editor does. A preview script that writes markup or style rules, or talks to the network, would widen what an editor value can do.

## Decision

- The preview script sets custom properties on one element with `style.setProperty`. It writes no markup and no style rules.
- It checks a value with the same patterns as the server before drawing it, and draws nothing that fails.
- It sends nothing and stores nothing. A unit test reads the script and fails when it reaches for the network, storage or markup.
- The server checks every value again on save. The script decides nothing that is kept.
- Groups of the editor are one list, `GROUPS` in `lib/open_project/thematiq/editor.rb`; a test fails when a role is in no group or in two.

## Consequences

- The preview can be wrong in looks but cannot store or send an unchecked value.
- The preview uses the same patterns as the server, so a new kind of value needs both to know it.
