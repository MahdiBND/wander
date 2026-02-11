# Wander Development Flow

- [x] **Step 1: Engine bootstrap + target constraints**
  - Add `EngineTargets`, `EngineContext`, `EngineSystem`, `EngineCoordinator`, and `FrameClock`.
  - Wire bootstrap systems into renderer startup and frame update.
  - Add baseline tests for target constraints and frame delta clamping.

- [ ] **Step 2: Scene Graph Core (nodes + transforms + depth-first world matrix update)**
  - Implement node hierarchy ownership (`SceneNodeID`, parent/children links).
  - Implement local `Transform` + cached world matrix updates via depth-first traversal.
  - Add dirty propagation so unchanged branches skip recomputation.
  - Add tests for hierarchy transforms, reparenting, and traversal order.

- [ ] **Step 3: Component System Foundation**
  - Introduce protocol-oriented `Component` model with lifecycle hooks.
  - Bind components by `SceneNodeID` (avoid strong node references).
  - Add tests for attach/detach ordering and invalid-node safety.

- [ ] **Step 4: Camera Modes + View/Projection Pipeline**
  - Implement chase, hood, and cinematic follow camera modes.
  - Feed active camera matrices into renderer uniforms.
  - Add tests for mode switching, smoothing stability, and resize handling.

- [ ] **Step 5: Procedural Road Spline + Frenet Frames**
  - Build deterministic spline segment generation with seeded noise.
  - Compute Frenet frames and extrude road mesh.
  - Add tests for frame orthogonality and segment seam continuity.

- [ ] **Step 6: Chunked Terrain Generation**
  - Implement terrain chunk grid around player position.
  - Generate chunk meshes and blend road-terrain edges.
  - Add tests for chunk indexing, seam continuity, and deterministic regeneration.

- [ ] **Step 7: Threaded Streaming Pipeline**
  - Add bounded worker queues for generate/mesh/upload-ready stages.
  - Enforce main-thread GPU submission and chunk activation safety.
  - Add tests for chunk state transitions and queue limits.

- [ ] **Step 8: Renderer Expansion (terrain, road, props)**
  - Add dedicated render paths for terrain, road mesh, and instanced props.
  - Extend argument-buffer layout for per-frame and per-draw data.
  - Add tests for pipeline setup and instance buffer bounds.

- [ ] **Step 9: Fog + Sky Atmosphere**
  - Implement distance fog and dynamic sky gradient presets.
  - Bind fog/sky parameters to shader constants.
  - Add tests for fog clamp behavior and preset transitions.

- [ ] **Step 10: Arcade Vehicle Physics + Input**
  - Implement simplified arcade vehicle integration.
  - Add two tunings (`glider`, `trailblazer`) with distinct handling.
  - Add tests for tuning differences, speed clamp, and stable integration.

- [ ] **Step 11: Biomes, Props, and LOD**
  - Add `mountain-mist` and `desert-dusk` biome presets.
  - Implement roadside prop placement with GPU instancing and LOD.
  - Add tests for biome assignment, prop density bounds, and LOD thresholds.

- [ ] **Step 12: Stabilization, Profiling, and Ship Gate**
  - Add frame-time/hitch metrics and debug overlay.
  - Optimize toward 60 FPS on M1 baseline scenarios.
  - Run full acceptance + regression checks before release.
