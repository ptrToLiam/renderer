# General Notes

A file for general notes and thoughts related to this project that may not
necessarily belong in a `TODO` yet.

## RETURNING CONTEXT

- Parallelized physics
- SDF Collision Solver
- Tetrahedral normal sampling

## Instanced Rendering

Render N instances of O.
- Linear iteration over primitive arrays per march step
- Cost scales as march_steps × primitive_count × threads
- fmod for uniform spatial repetition (infinite instances, cost of one)
- Spatial partitioning (uniform grid) is the mitigation when counts grow

## Physics / Collisions

Verlet Integration calculations?

Inter-Entity Collisions.

Verlet Integration - position + previous position, no explicit velocity
                     new = cur + (cur - prev) + accel * dt²

SDF collision detection - evaluate sdf_scene(entity_pos) < entity_radius

SDF collision normal - finite differences on sdf_scene at contact point
  (same code as surface normal calculation, already implemented)

Inter-Entity Collisions - naive O(N²), GPU uniform grid for broad phase

## Mouse Input

Want to distinguish between 2 'modes'
- A: Mouse Motion Rotates Camera
- B: Mouse Motion Moves Cursor Position

CPU-Side Management:
- Mode A = locked pointer, relative motion
- Mode B = unlocked pointer, surface-relative position.

GPU-Side Management:
- Input Contains Flag for Mouse Motion Interp?

## Probe Cascade (north star)

- Render full 360° scene into cascaded environment map probes around camera
- Probe update driven by camera POSITION (expensive, amortised)
- Presentation pass driven by camera ORIENTATION (cheap, late-latched)
- LoD via cascade - coarse march for distant probes, fine for close
- Enables painterly/impressionistic distance rendering naturally
- Reference: Aaltonen GDC 2018 Claybook talk

## Future Concerns

View-independent probe cascade, 360 deg around camera, late-latch inputs/cam
to reproject scene into correct view.

LoD, Accel Structures.

Spacial Partitioning

Proper intrumented profiler teporting Min/Max/Avg times.
