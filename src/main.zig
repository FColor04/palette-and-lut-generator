const std = @import("std");
const PngToPalette = @import("PngToPalette");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) @panic("TEST FAIL");
    }
    const data = try PngToPalette.loadFileAlloc(allocator, "test2.png");
    defer allocator.free(data);
    const palette = try PngToPalette.pngToPalette(allocator, data.ptr, data.len, true);
    defer allocator.free(palette);

    std.debug.print("{any}", .{palette});
}