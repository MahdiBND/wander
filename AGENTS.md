# Repository Guidelines

## Project Structure & Module Organization
This repository is an Xcode macOS game project using Swift + Metal.

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
- Keep files focused: rendering logic in `Renderer.swift`, app lifecycle in `AppDelegate.swift`.

## Testing Guidelines
- Add unit tests in `WanderTests/` for math, state, and deterministic logic.
- Add UI flow and launch coverage in `WanderUITests/`.
- Name tests descriptively, e.g. `testRendererInitializesPipelineState()`.
- Run full tests before opening a PR using the `xcodebuild ... test` command above.

## Commit & Pull Request Guidelines
- Prefer Conventional Commit style seen in history (`feat: ...`, `fix: ...`, `chore: ...`).
- Keep commits focused and atomic; avoid mixing refactors with behavior changes.
- PRs should include a clear summary of what changed and why.
- PRs should link the related issue/spec (reference `Wander-spec.md` when relevant).
- PRs should include screenshots or short recordings for rendering/UI changes.
- PRs should include test evidence (command run and result).
