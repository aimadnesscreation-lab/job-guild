# Auto-Context Skill

Automatically maintain a `CONTEXT.md` file at the project root to track all development progress, architecture decisions, bugs fixed, and future goals. This skill applies to every project you work on.

## Rules

### 0. Self-reminder banner (CRITICAL)

When creating `CONTEXT.md` for the first time in a new project, ALWAYS add this banner as the very first thing:

```markdown
> 🧠 **AI Instruction: Load the auto-context skill at the START of every session**
> Run: `skill("auto-context")` — then follow its instructions to maintain this file.
> This banner exists so you never need reminding. Just do it.
```

This banner is how you (the AI) will remember to load this skill in future sessions. Without it, you will forget.

### 1. Create CONTEXT.md if it doesn't exist

When starting work in a new project that has no `CONTEXT.md`, create one (with the banner from Rule 0) containing at minimum:

- **Project Overview** — one-liner describing what the project is
- **Current State** — today's date, what's been done so far
- **What's Implemented** — list of screens/features completed
- **What's Next / Future Goals** — what remains to be done

Infer the project type from the files present (e.g., `pubspec.yaml` = Flutter/Dart, `package.json` = Node/React, `Cargo.toml` = Rust, etc.).

### 2. Update CONTEXT.md after every successful session

After any significant code change, bug fix, feature addition, or architecture decision, update `CONTEXT.md` with:

#### Required updates:
- **Date** — update the date stamp at the top
- **Latest Developments** — add a bullet-point summary of what was accomplished in this session (keep it scannable: screens built, bugs fixed, features added, tests written)
- **What's Implemented** — add new screens/features to the list with ✅
- **What's Next / Future Goals** — mark completed items as `[x]`, add new items as `[ ]`
- **Code Health** — update test counts, `dart analyze` / lint status after running validation

#### Optional (when relevant):
- **Architecture Decisions** — log any significant design choices and why
- **Bug Fixes** — log bugs found and fixed (use emoji: 🔴 = fixed bug, 🟡 = issue, 🧹 = cleanup)
- **Configuration Changes** — env vars added, secrets set, packages installed
- **Known Issues** — note any remaining bugs or TODOs

### 3. Keep it scannable

- Use bullet points, not paragraphs
- Group related items under headings
- Use emoji for visual scanning (✅, 🔴, 🟡, 🧹, 🔄)
- Keep the "Future Goals" section as a checklist

### 4. Don't overwrite existing content

Preserve all existing sections. Only:
- Add new entries
- Update dates and counts
- Mark items as complete

### 5. File Format

CONTEXT.md should use Markdown with this structure:

```markdown
> 🧠 AI self-reminder banner here (from Rule 0)

# Project Name

## Current State (Updated YYYY-MM-DD)

Brief status line with health indicators.

### Latest Developments (YYYY-MM-DD)

- [ ] Key items done this session

## What's Implemented

1. ✅ Feature/screen one
2. ✅ Feature/screen two

## Future Goals

### Short-term
- [ ] Next thing to do

### Medium-term
- [ ] Later thing

### Phase N
- [ ] Future thing
```
