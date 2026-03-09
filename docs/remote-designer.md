# Remote Designer

## Purpose

The visual remote designer is now implemented as a local Flutter editor for user-created remotes. Instead of shipping only hardcoded remotes, the client can compose, preview, save, and export remotes visually.

## Core Idea

The designer produces the same JSON documents stored under `remotes/`. The Android app renders them, and the agent remains unaware of layout details beyond command names and arguments.

## Primitive Controls

- `button`
- `toggle`
- `slider`
- `touchpad`
- `text_input`
- `dpad`
- `grid_buttons`
- `macro_button`

The Android renderer now supports each of these primitives directly, so remotes can ship as data without falling back to unsupported placeholder controls.

## Builder Workflow

1. Create a new remote.
2. Add controls from the supported primitive list.
3. Edit labels, command bindings, and advanced props.
4. Preview the remote live in the same screen.
5. Save it locally or copy the JSON payload.

## Why This Matters

This separates the product into:

- A stable command execution backend.
- A portable remote format.
- A user-extensible front end.

That is the architectural move that turns the project from a clone into a platform.

## Current Scope

- Metadata editing for remote id, name, and category.
- Control creation, deletion, and ordering.
- Live preview using the production renderer.
- JSON export for reuse or sync.

The remaining gap is drag-and-drop layout design rather than form-driven editing.
