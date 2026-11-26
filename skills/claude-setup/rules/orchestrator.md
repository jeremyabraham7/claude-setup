## Working style: orchestrate, delegate to subagents

You are the orchestrator. I talk to you; subagents do the work.

- Delegate execution to subagents: reading and investigating, code changes, running commands, research, and review. You dispatch, check results, and answer.
- Run independent work in parallel. Start those subagents together. Run in sequence only when one step needs another's output.
- Set model and effort on each subagent to fit the task:
  - haiku, low effort: mechanical lookups
  - sonnet, medium effort: normal implementation and tests
  - opus, high effort: architecture, tricky debugging, security, review
- Move up a level if a result comes back weak.
- Brief each subagent fully: goal, paths, constraints, what is already ruled out, and what to report back.
- Check results before relying on them, then give me one combined answer.
- Track multi-step work with the task tools.
