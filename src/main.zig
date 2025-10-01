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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var ignoreAlpha = false;
    var outputMode = OutputTypes.hexadecimalArray;
    var outputFilePath : ?[:0]const u8 = null;

    var output = try allocator.alloc(u32, 0);
    var outputOffset : u64 = 0;
    var processedArgs: u16 = 0;
    var i: u16 = 1;
    while (i < args.len) {
        defer i += 1;
        defer processedArgs += 1;
        const arg = args[i];

        const data = if(arg.len > 1 and arg[0] == '-') arg[1..] else arg[0..];
        const flag = std.meta.stringToEnum(Flags, data) orelse std.debug.panic("Unknown flag {s}.", .{data});
        switch (flag) {
            .a, .alpha => {
                if(args.len <= i + 1) @panic("Expected value for path.");
                const value = std.meta.stringToEnum(AlphaMode, args[i + 1]) orelse @panic("Unknown value for alpha channel flag.");
                i += 1;
                ignoreAlpha = value == .true;
            },
            .p, .path => {
                if(args.len <= i + 1) @panic("Expected value for path flag.");
                const value = args[i + 1];
                i += 1;
                const fileData = try PngToPalette.loadFileAlloc(allocator, value);
                defer allocator.free(fileData);
                const colors = try PngToPalette.pngToPaletteAlloc(allocator, fileData.ptr, fileData.len, ignoreAlpha);

                output = try allocator.realloc(output, outputOffset + colors.len);
                @memmove(output[outputOffset..], colors);
                outputOffset += colors.len;
            },
            .d, .data => {
                if(args.len <= i + 1) @panic("Expected value for data flag.");
                const value = args[i + 1];
                i += 1;
                const valueCopy = try allocator.dupe(u8, value);
                const colors = try PngToPalette.pngToPaletteAlloc(allocator, valueCopy.ptr, valueCopy.len, ignoreAlpha);

                output = try allocator.realloc(output, outputOffset + colors.len);
                @memmove(output[outputOffset..], colors);
                outputOffset += colors.len;
            },
            .o, .output => {
                if(args.len <= i + 1) @panic("Expected value for output flag.");
                const value = args[i + 1];
                i += 1;
                outputMode = std.meta.stringToEnum(OutputTypes, value) orelse std.debug.panic("Unknown output format type {s}.", .{value});
                if(outputMode == .file){
                    if(args.len <= i + 1) @panic("Also expected path value for output flag.");
                    outputFilePath = args[i + 1];
                    i += 1;
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