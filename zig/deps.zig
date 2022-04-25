const std = @import("std");
const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

pub const pkgs = struct {
    pub const zalgebra = Pkg{
        .name = "zalgebra",
        .path = FileSource{
            .path = ".gyro\\zalgebra-kooparse-github.com-84c65673\\pkg\\src\\main.zig",
        },
    };

    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        artifact.addPackage(pkgs.zalgebra);
    }
};
