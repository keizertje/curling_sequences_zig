const std = @import("std");

const CFlags = &.{};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const test_filters: []const []const u8 = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any of the specified filters",
    ) orelse &.{};

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).

    const exe = b.addExecutable(.{
        .name = "out",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe.addCSourceFile(.{
        .file = b.path("src/c_src/c_func.c"),
        .flags = CFlags,
    });

    exe.addIncludePath(b.path("src/include/"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .filters = test_filters,
    });

    const diff_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/benches/diff.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .filters = test_filters,
    });

    const diff_test_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/benches/diff_test.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .filters = test_filters,
    });
    //
    unit_tests.addCSourceFile(.{
        .file = b.path("src/c_src/c_func.c"),
        .flags = CFlags,
    });

    diff_unit_tests.addCSourceFile(.{
        .file = b.path("src/c_src/c_func.c"),
        .flags = CFlags,
    });

    diff_test_unit_tests.addCSourceFile(.{
        .file = b.path("src/c_src/c_func.c"),
        .flags = CFlags,
    });

    unit_tests.addIncludePath(b.path("src/include/"));

    diff_unit_tests.addIncludePath(b.path("src/include/"));

    diff_test_unit_tests.addIncludePath(b.path("src/include/"));

    b.installArtifact(unit_tests);

    b.installArtifact(diff_unit_tests);

    b.installArtifact(diff_test_unit_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const run_diff_unit_tests = b.addRunArtifact(diff_unit_tests);

    const run_diff_test_unit_tests = b.addRunArtifact(diff_test_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_diff_unit_tests.step);
    test_step.dependOn(&run_diff_test_unit_tests.step);
}
