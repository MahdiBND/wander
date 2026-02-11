# Repository Guidelines

## Project Structure & Module Organization
This repository is an Xcode macOS game project using Swift + Metal.

- `readme.md`: Describes project's folder structure that should be followed.
- `Wander/`: App source files and runtime assets.
- `Wander/AppDelegate.swift`: App lifecycle entry point.
- `Wander/GameViewController.swift`: View/controller glue for rendering.
- `Wander/Renderer.swift`: Core Metal render loop and frame logic.
- `Wander/Shaders.metal` and `Wander/ShaderTypes.h`: GPU shaders and shared shader data types.
- `Wander/Assets.xcassets/`: App icon, colors, and texture assets.
- `WanderTests/`: Unit tests.
- `WanderUITests/`: UI/launch tests.
- `Wander.xcodeproj/`: Project configuration and build settings.

## Build, Test, and Development Commands
- `open Wander.xcodeproj`: Open in Xcode for local development.
- `xcodebuild -project Wander.xcodeproj -scheme Wander -configuration Debug build`: Build app from CLI.
- `xcodebuild -project Wander.xcodeproj -scheme Wander -destination 'platform=macOS' test`: Run unit and UI test targets.
- `xcodebuild -project Wander.xcodeproj -scheme Wander -configuration Release build`: Produce optimized build.

Use Xcode Product actions for day-to-day iteration; use `xcodebuild` in CI or reproducible local checks.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines and keep code clean and SOLID.
- Use 4 spaces for indentation; avoid tabs.
- Use `UpperCamelCase` for types (`Renderer`), `lowerCamelCase` for vars/functions, and clear verb-based method names.
- Keep Metal function/type names explicit and consistent between `ShaderTypes.h` and `Shaders.metal`.
- Keep files focused: each file should contain only one `class`, `struct`, `protocol`, `enum`, and etc...

## Testing Guidelines
- Add unit tests in `WanderTests/` for math, state, and deterministic logic.
- Add UI flow and launch coverage in `WanderUITests/`.
- Name tests descriptively, e.g. `testRendererInitializesPipelineState()`.
- Run full tests before opening a PR using the `xcodebuild ... test` command above.

## Commit & Pull Request Guidelines
- Prefer Conventional Commit style seen in history (`feat: ...`, `fix: ...`, `chore: ...`).
- Keep commits focused and atomic; avoid mixing refactors with behavior changes.
- Keep commits small, one file at max.
- PRs should include a clear summary of what changed and why.
- PRs should link the related issue/spec (reference `Wander-spec.md` when relevant).
- PRs should include screenshots or short recordings for rendering/UI changes.
- PRs should include test evidence (command run and result).

## Branching Workflow (Required)
- `main` is protected for stable history; do not develop features directly on `main`.
- Create one branch per task using `task/<short-scope>` naming.
- Examples: `task/scene-graph-core`, `task/chunk-streaming-pipeline`, `task/fog-atmosphere`.
- Open a PR from the task branch into `main` for every task, even small ones.
- Keep PR scope aligned to a single step from `dev-flow.md`.

## Dev Flow Tracking (Required)
- `dev-flow.md` is the source of truth for implementation progress.
- When a step is completed and merged, immediately update its checkbox to `[x]`.
- Do not mark a step done unless code is implemented and test checks pass.
- If scope changes, update the step text in `dev-flow.md` in the same PR.
