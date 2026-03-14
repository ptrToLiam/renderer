# General Notes

A file for general notes and thoughts related to this project that may not
necessarily belong in a `TODO` yet.


## Mouse Input

Want to distinguish between 2 'modes'
A: Mouse Motion Rotates Camera
B: Mouse Motion Moves Cursor Position

CPU-Side Management:
Mode A = locked pointer, relative motion
Mode B = unlocked pointer, surface-relative position.

GPU-Side Management:
Input Contains Flag for Mouse Motion Interp?

## Future Concerns

View-independent probe cascade, 360 deg around camera, late-latch inputs/cam
to reproject scene into correct view.

LoD, Accel Structures.

Spacial Partitioning

Proper intrumented profiler teporting Min/Max/Avg times.
