const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const zlib = std.compress.flate.Decompress;

const assert = std.debug.assert;
const magicNumber = [_]u8{0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A};

const U32Context = struct {
    pub fn hash(_: U32Context, val: u32) u64 {
        return val;
    }

    pub fn eql(_: U32Context, a: u32, b: u32) bool {
        return a == b;
    }
};
const setType = std.HashMap(u32, void, U32Context, std.hash_map.default_max_load_percentage);

pub fn loadFileAlloc(allocator: Allocator, path: []const u8) ![]u8 {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024 * 1024 * 2);
}

pub fn pngToPalette(allocator: Allocator, dataPointer: [*] u8, dataLen: usize, ignoreAlpha: bool) ![]const u32 {
    assert(dataLen > 8);
    var data = dataPointer[0..dataLen];
    assert(std.mem.startsWith(u8, data, &magicNumber));
    var pos : usize = 8;

    var set = setType.init(allocator);
    defer set.deinit();

    var w : u32 = 0;
    var h : u32 = 0;
    var bitDepth : u8 = 1;
    var colorType : u8 = 0;
    var filterMode : u8 = 0;
    var zlibLen : u32 = 0;

    var modCount : u5 = 0;
    var bitsPerPixel : u16 = 0;
    var bytesPerPixel : u16 = 0;

    while(pos < dataLen) {
        const chunkLen = parseU32be(data, pos);
        pos += 4;
        const chunkType = parseU32be(data, pos);
        pos += 4;

        if(pos == 16)
            assert(chunkType == comptime stringToU32([4]u8{'I', 'H', 'D', 'R'}));

        switch (chunkType) {
            stringToU32([_]u8{'I', 'H', 'D', 'R'}) => {
                w = parseU32be(data, pos);
                pos += 4;
                h = parseU32be(data, pos);
                pos += 4;
                bitDepth = parseU8be(data[pos]);
                pos += 1;
                colorType = parseU8be(data[pos]);
                pos += 1;
                const compressionMode = parseU8be(data[pos]);
                assert(compressionMode == 0); //zlib
                pos += 1;
                filterMode = parseU8be(data[pos]); // each scanline has 1 byte for filter mode
                assert(filterMode == 0);
                pos += 1;
                //interlace method
                pos += 1;

                modCount = switch (colorType) {
                    1 => 1,
                    2 => 3,
                    3 => 1,
                    4 => 2,
                    6 => 4,
                    else => @panic("Unsupported color type.")
                };
                bitsPerPixel = modCount * bitDepth;
                bytesPerPixel = @divFloor(bitsPerPixel, 8);
            },
            stringToU32([_]u8{'P', 'L', 'T', 'E'}) => {
                for (0..@divFloor(chunkLen, 3)) |_| {
                    const r = data[pos];
                    pos += 1;
                    const g = data[pos];
                    pos += 1;
                    const b = data[pos];
                    pos += 1;
                    try set.put(@as(u32, r) << 24 | @as(u32, g) << 16 | @as(u32, b) << 8, {});
                }
            },
            stringToU32([_]u8{'I', 'D', 'A', 'T'}) => {
                @memmove(data.ptr + zlibLen, data[pos..pos+chunkLen]);
                zlibLen += chunkLen;
                pos += chunkLen;
            },
            else => {
                pos += chunkLen;
            }
        }
        const crc = parseU32be(data, pos);
        _ = crc;
        pos += 4;
    }
    if(zlibLen > 0) {
        var reader = std.Io.Reader.fixed(data[0..zlibLen]);
        var buffer = [1]u8{0} ** std.compress.flate.max_window_len;
        var flate = zlib.init(&reader, .zlib, &buffer);
        const outputBuffer = try std.Io.Reader.allocRemaining(&flate.reader, allocator, .unlimited);
        defer allocator.free(outputBuffer);

        var color : u32 = 0;
        var mod : u5 = 0;

        const scanlineWidth = w * bytesPerPixel + 1;
        const stride: usize = @intCast(scanlineWidth);
        const bpp: usize = @intCast(bytesPerPixel);

        for (0.., outputBuffer) |index, *byte| {
            if(index % scanlineWidth == 0){
                filterMode = byte.*;
                continue;
            }

            if(mod == 0)
                color = 0;
            switch (colorType) {
                0, 2, 4, 6 => {
                    filterModeSwitch: switch (filterMode) {
                        0 => {
                            color |= @as(u32, byte.*) << (modCount - 1 - mod) * 8;
                            break :filterModeSwitch;
                        },
                        1 => {
                            byte.* +%= left(index, stride, bpp, outputBuffer.ptr);
                            continue :filterModeSwitch 0;
                        },
                        2 => {
                            byte.* +%= up(index, stride, outputBuffer.ptr);
                            continue :filterModeSwitch 0;
                        },
                        3 => {
                            const a = left(index, stride, bpp, outputBuffer.ptr);
                            const b = up(index, stride, outputBuffer.ptr);
                            const avg: u8 = @intCast(@divFloor((@as(u16, a) + @as(u16, b)), 2));
                            byte.* +%= avg;
                            continue :filterModeSwitch 0;
                        },
                        4 => {
                            const a = left(index, stride, bpp, outputBuffer.ptr);
                            const b = up(index, stride, outputBuffer.ptr);
                            const c = upperLeft(index, stride, bpp, outputBuffer.ptr);
                            byte.* +%= paeth(a, b, c);
                            continue :filterModeSwitch 0;
                        },
                        else => {
                            std.debug.print("Unsupported filter mode: {} at index {}\n", .{ filterMode, index });
                            @panic("Unsupported filter mode.");
                        },
                    }
                },

                3 => {}, // PALETTE INDEX
                else => {@panic("Unsupported color type.");}
            }

            if(mod == modCount - 1){
                if(!ignoreAlpha)
                    color &= ~@as(u32, 0xff);
                try set.put(color, {});
            }
            mod = (mod + 1) % modCount;
        }
    }

    // var iterator = set.iterator();
    // var string = try std.ArrayList(u8).initCapacity(allocator, 0);
    // defer string.deinit(allocator);
    // std.debug.print("{any} {s}\n", .{set.count(), try iteratorToString(&string, allocator, &iterator, setType.Iterator.next)});

    var itemSize : u32 = 32;
    var items = try allocator.alloc(u32, itemSize);
    var keys = set.keyIterator();
    var itemCount : u32 = 0;
    while (keys.next()) |key| {
        items[itemCount] = key.*;
        itemCount += 1;
        if(itemCount >= itemSize) {
            itemSize *= 2;
            items = try allocator.realloc(items, itemSize);
        }
    }

    items = try allocator.realloc(items, itemCount);

    return items;
}

fn paeth(leftByte: u8, aboveByte: u8, upperLeftByte: u8) u8 {
    const p = @as(i16, leftByte) + aboveByte - upperLeftByte;
    const pa = @abs(p - leftByte);
    const pb = @abs(p - aboveByte);
    const pc = @abs(p - upperLeftByte);

    if (pa <= pb and pa <= pc)
        return leftByte;
    if (pb <= pc)
        return aboveByte;
    return upperLeftByte;
}

fn left(index: usize, stride: usize, bpp: usize, out: [*]const u8) u8 {
    const col = index % stride;
    if (col == 0 or col <= bpp) return 0;
    return out[index - bpp];
}

fn up(index: usize, stride: usize, out: [*]const u8) u8 {
    if (index <= stride) return 0;
    return out[index - stride];
}

fn upperLeft(index: usize, stride: usize, bpp: usize, out: [*]const u8) u8 {
    const col = index % stride;
    if (index <= stride or col == 0 or col <= bpp) return 0;
    return out[index - stride - bpp];
}

fn iteratorToString(string: *std.ArrayList(u8), allocator: Allocator, iterator: *setType.Iterator, input: fn (*setType.Iterator) ?setType.Entry) ![]u8 {
    try string.appendSlice(allocator, "[");
    var i : u32 = 0;
    while (input(iterator)) |entry| {
        if(i > 0)
            try string.appendSlice(allocator, ", ");
        const entryString = try std.fmt.allocPrint(allocator, "#{x}", .{entry.key_ptr.*});
        defer allocator.free(entryString);
        try string.appendSlice(allocator, entryString);

        i += 1;
    }
    try string.appendSlice(allocator, "]");
    return string.items;
}

fn stringToU32(input: [4]u8) u32 {
    return std.mem.readInt(u32, &input, .big);
}

fn u32ToString(input: u32) [4]u8 {
    return [4]u8{@truncate(input >> 24), @truncate(input >> 16), @truncate(input >> 8), @truncate(input)};
}

fn parseU8be(data: u8) u8 {
    return std.mem.readInt(u8, &data, .big);
}

fn parseU32be(data: []const u8, pos: usize) u32 {
    const buffer = [4]u8{data[pos], data[pos+1], data[pos+2], data[pos+3]};
    return std.mem.readInt(u32, &buffer, .big);
}