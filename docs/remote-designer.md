# Remote Designer

## Purpose

The visual remote designer is the natural extension of the JSON remote system. Instead of shipping only hardcoded remotes, the client will eventually let users compose them visually.

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
2. Add controls to a canvas.
3. Configure labels, style, and command bindings.
4. Save the remote locally or sync it to an agent.

## Why This Matters

This separates the product into:

- A stable command execution backend.
- A portable remote format.
- A user-extensible front end.

That is the architectural move that turns the project from a clone into a platform.
