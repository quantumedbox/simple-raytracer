const std = @import("std");
const za = @import("zalgebra");
const Vec3 = za.Vec3;

const Ray = struct {
  origin: Vec3,
  dir: Vec3,

  fn alongRay(self: Ray, t: f32) Vec3 {
    return self.origin.add(self.dir.scale(t));
  }
};

const worker_count = 2; // todo: Could get thread count at runtime, of course

const origin = Vec3.zero();
const aspect_ratio: f32 = 16.0 / 9.0;
const width: i32 = 1920;
const height = @floatToInt(i32, @intToFloat(f32, width) / aspect_ratio);
const viewport_height = 2.0;
const viewport_width = aspect_ratio * viewport_height;
const focal_length = 1.0;
const horizontal = Vec3.new(viewport_width, 0.0, 0.0);
const vertical = Vec3.new(0.0, viewport_height, 0.0);
const lower_left_corner = origin.sub(horizontal.scale(0.5))
  .sub(vertical.scale(0.5))
  .sub(Vec3.new(0.0, 0.0, focal_length));

const ppm_header = std.fmt.comptimePrint("P6\n{any} {any} \n255\n", .{width, height});
const output_bytes = ppm_header.len + @as(usize, 3 * width * height);

var output: [output_bytes]u8 = undefined;

pub fn main() !void {
  std.mem.copy(u8, output[0..], ppm_header);

  var timer = try std.time.Timer.start();
  const start_render_time = timer.read();

  var workers: [worker_count]std.Thread = undefined;
  var worker_id: usize = 0;
  while (worker_id != worker_count) : (worker_id += 1)
    workers[worker_id] = try std.Thread.spawn(.{}, workerThread, .{worker_id});

  for (workers) |worker|
    worker.join();

  const end_render_time = timer.read();

  var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
  const path = try std.fs.realpath("./", &path_buffer);

  var dir = try std.fs.openDirAbsolute(path, .{});
  try dir.writeFile("output.ppm", output[0..]);

  const end_save_time = timer.read();

  std.debug.print("It took {} ms to render and {} ms to save",
    .{(end_render_time - start_render_time) / 1000_000,
      (end_save_time - end_render_time) / 1000_000}
  );
}

fn workerThread(id: usize) !void {
  var writer = ppm_header.len + 1 + id * 3;
  var y: usize = height - 1;
  while (true) {
    var x: usize = id;
    while (x < width) {
      const u = @intToFloat(f32, x) / @intToFloat(f32, width);
      const v = @intToFloat(f32, y) / @intToFloat(f32, height);
      const r = Ray {
        .origin = origin,
        .dir = lower_left_corner
          .add(horizontal.scale(u))
          .add(vertical.scale(v))
          .sub(origin)
      };
      const res = color(r, Vec3.new(0.0, 0.0, -1.0), 0.5);

      output[writer + 0] = @floatToInt(u8, res.x() * 255.0);
      output[writer + 1] = @floatToInt(u8, res.y() * 255.0);
      output[writer + 2] = @floatToInt(u8, res.z() * 255.0);

      writer += 3 * worker_count;
      x += worker_count;
    }
    if (y == 0) break;
    y -= 1;
  }
}

fn color(ray: Ray, centre: Vec3, radius: f32) Vec3 {
  const t = raycastSphere(ray, centre, radius);
  if (t > 0.0) {
    const n = ray.alongRay(t).sub(centre).norm();
    return n.add(Vec3.one()).scale(0.5);
  } else {
    const ndir = ray.dir.norm();
    const t2 = ndir.add(Vec3.one()).scale(0.5);
    return (Vec3.one().sub(t2)
      .mul(Vec3.one()))
      .add(t2.mul(Vec3.new(0.5, 0.7, 1.0)));
  }
}

fn raycastSphere(ray: Ray, centre: Vec3, radius: f32) f32 {
  const oc = ray.origin.sub(centre);
  // const a = std.math.pow(f32, ray.dir.length(), 2);
  const a = ray.dir.dot(ray.dir);
  const b = 2.0 * oc.dot(ray.dir);
  // const c = std.math.pow(f32, oc.length(), 2) - (radius * radius);
  const c = oc.dot(oc) - (radius * radius);
  const discrim = b * b - 4.0 * a * c;
  if (discrim < 0.0) {
    return -1.0;
  } else {
    return ((-b) - std.math.sqrt(discrim)) / (2.0 * a);
  }
}
