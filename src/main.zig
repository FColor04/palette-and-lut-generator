const std = @import("std");
const PngToPalette = @import("PngToPalette");

const maxSizeMB = 100;
const maxSizeB = maxSizeMB * 1024 * 1024;
var buffer = [_]u8{0} ** maxSizeB;

pub fn main() !void {
    const len = try PngToPalette.loadFile("test1.png", &buffer);
    const a = try PngToPalette.pngToPalette(&buffer, len);
    std.debug.print("{any}", .{a});
}