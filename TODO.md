# Software Rendering

- Separate Wayland-specifics from main application code
- Basic Lighting
- Rasterizing
- 3D models

# Project Structure

- Wayland protocol codegen tool should depend on platform for thread context
- Platform support for Win32 so I can work on the rendering side of things regardless of booted system.
- Unified events system (using comptime for Win32 vs Wayland)

# Application Logic

- App build on from platform
- Separate start logic per-platform
- Support IPC ?
