const std = @import("std");

const CrossTarget = struct {
    os_name: []const u8, // folder name: "Windows", "Linux", "MacOS", "FreeBSD"
    bin_suffix: []const u8, // e.g. "x86_64", "aarch64-musl"
    cpu_arch: std.Target.Cpu.Arch,
    os_tag: std.Target.Os.Tag,
    abi: ?std.Target.Abi = null,
};

// ═══════════════════════════════════════════════════════════════════
//  Full cross-compilation matrix
//  Output layout:  bin/{OS}/veiltext-{arch}[.exe]
// ═══════════════════════════════════════════════════════════════════

const cross_targets = [_]CrossTarget{
    // ── Linux (glibc) ──────────────────────────────────────────────
    .{ .os_name = "Linux", .bin_suffix = "x86_64", .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "aarch64", .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "x86", .cpu_arch = .x86, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "arm", .cpu_arch = .arm, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "riscv64", .cpu_arch = .riscv64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "mips", .cpu_arch = .mips, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "mips64", .cpu_arch = .mips64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "powerpc", .cpu_arch = .powerpc, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "powerpc64", .cpu_arch = .powerpc64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "powerpc64le", .cpu_arch = .powerpc64le, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "s390x", .cpu_arch = .s390x, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "loongarch64", .cpu_arch = .loongarch64, .os_tag = .linux },
    .{ .os_name = "Linux", .bin_suffix = "sparc64", .cpu_arch = .sparc64, .os_tag = .linux },
    // ── Linux (musl / static — ideal for Alpine, containers) ──────
    .{ .os_name = "Linux", .bin_suffix = "x86_64-musl", .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "aarch64-musl", .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "x86-musl", .cpu_arch = .x86, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "arm-musl", .cpu_arch = .arm, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "riscv64-musl", .cpu_arch = .riscv64, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "mips-musl", .cpu_arch = .mips, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "mips64-musl", .cpu_arch = .mips64, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "powerpc-musl", .cpu_arch = .powerpc, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "powerpc64-musl", .cpu_arch = .powerpc64, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "powerpc64le-musl", .cpu_arch = .powerpc64le, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "s390x-musl", .cpu_arch = .s390x, .os_tag = .linux, .abi = .musl },
    .{ .os_name = "Linux", .bin_suffix = "loongarch64-musl", .cpu_arch = .loongarch64, .os_tag = .linux, .abi = .musl },
    // ── Windows ────────────────────────────────────────────────────
    .{ .os_name = "Windows", .bin_suffix = "x86_64", .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .os_name = "Windows", .bin_suffix = "aarch64", .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .os_name = "Windows", .bin_suffix = "x86", .cpu_arch = .x86, .os_tag = .windows },
    // ── macOS ──────────────────────────────────────────────────────
    .{ .os_name = "MacOS", .bin_suffix = "x86_64", .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .os_name = "MacOS", .bin_suffix = "aarch64", .cpu_arch = .aarch64, .os_tag = .macos },
    // ── FreeBSD ────────────────────────────────────────────────────
    .{ .os_name = "FreeBSD", .bin_suffix = "x86_64", .cpu_arch = .x86_64, .os_tag = .freebsd },
    .{ .os_name = "FreeBSD", .bin_suffix = "aarch64", .cpu_arch = .aarch64, .os_tag = .freebsd },
    .{ .os_name = "FreeBSD", .bin_suffix = "x86", .cpu_arch = .x86, .os_tag = .freebsd },
    .{ .os_name = "FreeBSD", .bin_suffix = "arm", .cpu_arch = .arm, .os_tag = .freebsd, .abi = .eabihf },
    // Zig 0.16.0 exposes powerpc64 and powerpc64le FreeBSD targets, but not 32-bit powerpc-freebsd.
    .{ .os_name = "FreeBSD", .bin_suffix = "powerpc64", .cpu_arch = .powerpc64, .os_tag = .freebsd },
    .{ .os_name = "FreeBSD", .bin_suffix = "powerpc64le", .cpu_arch = .powerpc64le, .os_tag = .freebsd },
    .{ .os_name = "FreeBSD", .bin_suffix = "riscv64", .cpu_arch = .riscv64, .os_tag = .freebsd },
};

pub fn build(b: *std.Build) void {
    const native_target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dist_optimize: std.builtin.OptimizeMode = switch (optimize) {
        .Debug => .ReleaseFast,
        else => optimize,
    };

    const install_step = b.getInstallStep();
    const native_step = b.step("native", "Build and install native executable");
    const dist_step = b.step("dist", "Build cross-platform release binaries");
    const wasm_step = b.step("wasm", "Build WebAssembly core module");

    const core = coreModule(b, native_target, optimize);
    const exe = b.addExecutable(.{
        .name = "veiltext",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bin/main.zig"),
            .target = native_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "veiltext", .module = core },
            },
        }),
    });

    const install = b.addInstallArtifact(exe, .{});
    native_step.dependOn(&install.step);
    install_step.dependOn(&install.step);

    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run VeilText server");
    run_step.dependOn(&run_exe.step);

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm_exe = b.addExecutable(.{
        .name = "veiltext-core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = dist_optimize,
        }),
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    wasm_exe.export_memory = true;
    wasm_exe.initial_memory = 4 * 1024 * 1024;
    wasm_exe.max_memory = 64 * 1024 * 1024;

    const wasm_install = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{ .override = .{ .custom = "bin/Wasm" } },
        .dest_sub_path = "veiltext-core.wasm",
    });
    wasm_step.dependOn(&wasm_install.step);
    dist_step.dependOn(&wasm_install.step);

    for (cross_targets) |ct| {
        const ct_target = b.resolveTargetQuery(.{
            .cpu_arch = ct.cpu_arch,
            .os_tag = ct.os_tag,
            .abi = ct.abi,
        });
        // Output: bin/{OS}/veiltext-{arch}[.exe]
        const ct_dest_dir: std.Build.InstallDir = .{ .custom = b.fmt("bin/{s}", .{ct.os_name}) };
        const ct_core = coreModule(b, ct_target, dist_optimize);
        const ct_exe = b.addExecutable(.{
            .name = "veiltext",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/bin/main.zig"),
                .target = ct_target,
                .optimize = dist_optimize,
                .imports = &.{
                    .{ .name = "veiltext", .module = ct_core },
                },
            }),
        });
        const ct_install = b.addInstallArtifact(ct_exe, .{
            .dest_dir = .{ .override = ct_dest_dir },
            .pdb_dir = .disabled,
            .dest_sub_path = archBinaryName(b, "veiltext", ct.bin_suffix, ct.os_tag),
        });
        dist_step.dependOn(&ct_install.step);
    }

    const tests = b.addTest(.{
        .name = "veiltext-test",
        .root_module = coreModule(b, native_target, optimize),
    });
    const run_tests = b.addRunArtifact(tests);
    const wasm_tests = b.addTest(.{
        .name = "veiltext-wasm-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = native_target,
            .optimize = optimize,
        }),
    });
    const run_wasm_tests = b.addRunArtifact(wasm_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_wasm_tests.step);
}

fn coreModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}

/// Produce binary name: "veiltext-{suffix}" or "veiltext-{suffix}.exe" for Windows
fn archBinaryName(b: *std.Build, base: []const u8, suffix: []const u8, os: std.Target.Os.Tag) []const u8 {
    if (os == .windows) {
        return b.fmt("{s}-{s}.exe", .{ base, suffix });
    }
    return b.fmt("{s}-{s}", .{ base, suffix });
}
