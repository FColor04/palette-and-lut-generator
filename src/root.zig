const std = @import("std");
const fs = std.fs;
const assert = std.debug.assert;
const magicNumber = [_]u8{0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A};

pub fn loadFile(path: []const u8, buffer: []u8) !usize {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readAll(buffer);
}

pub fn pngToPalette(dataPointer: [*]const u8, dataLen: usize) ![]const u32 {
    assert(dataLen > 8);
    const data = dataPointer[0..dataLen];
    assert(std.mem.startsWith(u8, data, &magicNumber));
    var pos : usize = 8;

    var w : u32 = 0;
    var h : u32 = 0;
    var colorType : u8 = 0;

    while(pos < dataLen) {
        const chunkLen = parseU32be(data, pos);
        pos += 4;
        const chunkType = parseU32be(data, pos);
        pos += 4;

        if(pos == 16)
            assert(chunkType == comptime stringToU32([4]u8{'I', 'H', 'D', 'R'}));

        const chunkData = data[pos..pos+chunkLen];

        switch (chunkType) {
            stringToU32([_]u8{'I', 'H', 'D', 'R'}) => {
                w = parseU32be(data, pos);
                pos += 4;
                h = parseU32be(data, pos);
                pos += 4;
                //bit depth
                pos += 1;
                colorType = data[pos];
                pos += 1;
                //compression method
                pos += 1;
                //filter method
                pos += 1;
                //interlace method
                pos += 1;
                std.debug.print("{any}\n", .{.{w, h, colorType}});
            },
            stringToU32([_]u8{'P', 'L', 'T', 'E'}) => {
                for (0..@divFloor(chunkLen, 3)) |_| {
                    const r = data[pos];
                    pos += 1;
                    const g = data[pos];
                    pos += 1;
                    const b = data[pos];
                    pos += 1;
                    std.debug.print("{x}{x}{x}\n", .{r, g, b});
                }
            },
            else => {
                pos += chunkLen;
            }
        }
        const crc = parseU32be(data, pos);
        pos += 4;
        std.debug.print("{any} {s} {any} {any}\n", .{chunkLen, u32ToString(chunkType), chunkData, crc});
    }

    const u32pointer : [*]const u32 = @ptrCast(@alignCast(dataPointer));
    return u32pointer[0..@divFloor(dataLen, 4)];
}

fn stringToU32(input: [4]u8) u32 {
    return std.mem.readInt(u32, &input, .big);
}

fn u32ToString(input: u32) [4]u8 {
    return [4]u8{@truncate(input >> 24), @truncate(input >> 16), @truncate(input >> 8), @truncate(input)};
}

fn parseU32be(data: []const u8, pos: usize) u32 {
    const buffer = [4]u8{data[pos], data[pos+1], data[pos+2], data[pos+3]};
    return std.mem.readInt(u32, &buffer, .big);
}