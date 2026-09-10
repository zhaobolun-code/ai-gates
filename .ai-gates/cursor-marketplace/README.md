# Cursor marketplace root files

Copy **this directory's contents** (not the folder name) to the **GitHub repo root** of `zhaobolun-code/ai-gates`, as a sibling of `.ai-gates/`:

```text
.ai-gates/                 # library (already on GitHub)
.cursor-plugin/plugin.json  # from this folder
plugin-hooks.json
assets/logo.svg
skills/ai-gates/SKILL.md
```

`plugin.json` `version` must match `.ai-gates/skills/VERSION`.

Do not point `"skills"` at `.ai-gates/skills` (that would double-load job skills next to the project portal).
