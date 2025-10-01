const std = @import("std");
const PngToPalette = @import("PngToPalette");

const Flags = enum {
    p,
    path,
    d,
    data,
    o,
    output,
    a,
    alpha,
    h,
    help,
};

const AlphaMode = enum {
    true,
    false,
    ignore,
};

const OutputTypes = enum {
    hexadecimalArray,
    stringArray,
    file
};
const helpMessage =
\\PngToPalette v1.0.0 example usage:
++ "\n\t" ++ \\PngToPalette -p {{path}}
\\
++ "\n\t" ++ \\Available flags:
++ "\n\t\t" ++ \\-alpha -a {{ true | false | ignore }}
++ "\t" ++ \\| Set processing of alpha channel for upcoming instructions.
++ "\n\t\t" ++ \\-path -p {{ file path }}
++ "\t" ++ \\| Parse file, use multiple times, for multiple files.
++ "\n\t\t" ++ \\-output -o {{ hexadecimalArray | stringArray | file }} {{ file path }}
++ "\t" ++ \\| Set global output mode, file requires file path.
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leak. :(");
    }

    var args = std.process.args();
    _ = args.next(); // Discard program name arg
    var ignoreAlpha = false;
    var outputMode = OutputTypes.hexadecimalArray;
    var outputFilePath : ?[:0]const u8 = null;

    var output = try allocator.alloc(u32, 0);
    var outputOffset : u64 = 0;
    var processedArgs: u16 = 0;

    while (args.next()) |arg| {
        defer processedArgs += 1;

        const data = if(arg.len > 1 and arg[0] == '-') arg[1..] else arg[0..];
        const flag = std.meta.stringToEnum(Flags, data) orelse std.debug.panic("Unknown flag {s}.", .{data});
        switch (flag) {
            .a, .alpha => {
                const value = std.meta.stringToEnum(AlphaMode, args.next() orelse @panic("Expected value for path.")) orelse @panic("Unknown value for alpha channel flag.");
                ignoreAlpha = value == .true;
            },
            .p, .path => {
                const value = args.next() orelse @panic("Expected value for path flag.");
                const fileData = try PngToPalette.loadFileAlloc(allocator, value);
                defer allocator.free(fileData);
                const colors = try PngToPalette.pngToPaletteAlloc(allocator, fileData.ptr, fileData.len, ignoreAlpha);

                output = try allocator.realloc(output, outputOffset + colors.len);
                @memmove(output[outputOffset..], colors);
                outputOffset += colors.len;
            },
            .d, .data => {
                const value = args.next() orelse @panic("Expected value for data flag.");
                const valueCopy = try allocator.dupe(u8, value);
                const colors = try PngToPalette.pngToPaletteAlloc(allocator, valueCopy.ptr, valueCopy.len, ignoreAlpha);

                output = try allocator.realloc(output, outputOffset + colors.len);
                @memmove(output[outputOffset..], colors);
                outputOffset += colors.len;
            },
            .o, .output => {
                const value = args.next() orelse @panic("Expected value for output flag.");
                outputMode = std.meta.stringToEnum(OutputTypes, value) orelse std.debug.panic("Unknown output format type {s}.", .{value});
                if(outputMode == .file){
                    outputFilePath = args.next() orelse @panic("Also expected path value for output flag.");
                }
            },
            .h, .help => {
                processedArgs = 0;
                break;
            }
        }
    }

    if(processedArgs == 0){
        std.debug.print(helpMessage, .{});
    }else{
        switch (outputMode) {
            .hexadecimalArray => {
                std.debug.print("{any}", .{output});
            },
            .stringArray => {
                std.debug.print("{any}", .{output});
            },
            .file => {
                std.debug.print("{any}", .{output});
            }
        }
    }
}