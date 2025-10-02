const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("PngToPalette", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    const exe = b.addExecutable(.{
        .name = "PngToPalette",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "PngToPalette", .module = mod },
            },
        }),
    });

    const library = b.addLibrary(.{
        .name = "PngToPalette",
        .linkage = .dynamic,
        // .version = .{ .major = 1, .minor = 0, .patch = 0},
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);
    b.installArtifact(library);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    if (builtin.os.tag == .windows) {
        const sign_step = b.step("sign", "Sign windows exe");
        sign_step.dependOn(run_step);
        if(exe.installed_path) |path| {
            // const password = std.process.getenvW("PASSWORD");
            const sign_cmd = b.addSystemCommand(&.{"signtool", "sign", "/a", "/fd", "SHA256", path});
            sign_step.dependOn(&sign_cmd.step);
        }
    }
}
