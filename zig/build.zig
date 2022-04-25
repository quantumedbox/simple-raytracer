const Builder = @import("std").build.Builder;
const pkgs = @import("deps.zig").pkgs;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("src/main", "main.zig");
    pkgs.addAllTo(exe);
    exe.setBuildMode(b.standardReleaseOptions());
    exe.install();
}
