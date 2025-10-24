//------------------------------------------------------------------------------
//                         Memory Management API Surface
//------------------------------------------------------------------------------
pub fn mem_reserve(size: usize) []align(page_size_min) u8 {
    const ptr = VirtualAlloc(
            null,
            size,
            MEM_RESERVE,
            PAGE_READWRITE,
    ) catch |err| {
        log.err("VirtualAlloc of size {d} failed :: {s}", .{
            @errorName(err),
        });
        unreachable; // intentional crash
    };
    const ptr_u8 = @as([*]align(page_size_min) u8, @ptrCast(@alignCast(ptr)));
    return ptr_u8[0..size];
}

pub fn mem_commit(bytes: []align(page_size_min) u8) bool {
    _ = VirtualAlloc(
        @ptrCast(bytes),
        bytes.len,
        MEM_COMMIT,
        PAGE_READWRITE,
    ) catch return false;

    return true;
}

pub fn mem_decommit(bytes: []align(page_size_min) u8) void {
    VirtualFree(
        @ptrCast(bytes),
        bytes.len, 
        MEM_DECOMMIT,
    );
}

pub fn mem_release(bytes: []align(page_size_min) u8) void {
    VirtualFree(
        @ptrCast(bytes),
        0, 
        MEM_FREE,
    );
}

pub fn mem_reserve_large(size: usize) ?[]align(page_size_min) u8 {
    const ptr = VirtualAlloc(
            null,
            size,
            MEM_RESERVE | MEM_COMMIT | MEM_LARGE_PAGES,
            PAGE_READWRITE,
    ) catch |err| {
        log.err("VirtualAlloc large page of size {d} failed :: {s}", .{
            @errorName(err),
        });
        return null;
    };
    const ptr_u8 = @as([*]align(page_size_min) u8, @ptrCast(@alignCast(ptr)));
    return ptr_u8[0..size];
}

pub fn mem_commit_large(bytes: []align(page_size_min) u8) bool {
    _ = VirtualAlloc(
        @ptrCast(bytes),
        bytes.len,
        MEM_COMMIT,
        PAGE_READWRITE,
    ) catch return false;

    return true;
}
//------------------------------------------------------------------------------

const page_size_min = std.heap.page_size_min;

pub const MEM_RESERVE = std.os.windows.MEM_RESERVE;
pub const MEM_COMMIT = std.os.windows.MEM_COMMIT;
pub const MEM_DECOMMIT = std.os.windows.MEM_DECOMMIT;
pub const MEM_FREE = std.os.windows.MEM_FREE;
pub const MEM_LARGE_PAGES = std.os.windows.MEM_LARGE_PAGES;

pub const PAGE_READWRITE = std.os.windows.PAGE_READWRITE;

pub const VirtualFree = std.os.windows.VirtualFree;
pub const VirtualAlloc = std.os.windows.VirtualAlloc;
pub const VirtualProtect = std.os.windows.VirtualProtect;

const log = std.log.scoped(.Win32);

// 3rd-Party Imports
const std = @import("std");
