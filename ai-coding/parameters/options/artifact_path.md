# `artifact_path` — destination file for the run's primary artifact

Names the file where the run persists its main deliverable (a generated
prompt, a design deliverable, a session snapshot). Whether the write
actually happens is controlled by the [write gate family](write_gate.md).
Aliased as `save_path` (meta-prompt) and `output_path`
(save-session-state).

- **Used by:** meta-prompt, save-session-state, ralph-design, design-skill, designer-controller
- **Full entry:** [concerns/io.md](../concerns/io.md#artifact_path)
