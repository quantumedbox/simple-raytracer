import vmath
import std/[strformat, cpuinfo, monotimes, times]

type
  Ray = object
    origin, dir: Vec3

func alongRay(ray: Ray, t: float32): Vec3 =
  ray.origin + (ray.dir * t)

func raycastSphere(ray: Ray, centre: Vec3, radius: float32): float32 =
  let
    oc = ray.origin - centre
    a = ray.dir.lengthSq
    b = 2.0 * oc.dot(ray.dir)
    c = oc.lengthSq - (radius * radius)

  let discrim = b * b - 4.0 * a * c
  if discrim < 0:
    -1f
  else:
    (-b - sqrt(discrim)) / (2f * a)

func color(ray: Ray, centre: Vec3, radius: float32): Vec3 =
  let t = ray.raycastSphere(centre, radius)
  if t > 0:
    let
      n = normalize(ray.alongRay(t) - centre)
    0.5f * (n + vec3(1))
  else:
    let
      ndir = ray.dir.normalize()
      t = 0.5f * (ndir + vec3(1))
    (1.0f - t) * vec3(1) + t * vec3(0.5, 0.7, 1)

when isMainModule:
  const
    origin = vec3(0)
    aspectRatio = 16 / 9
    width = 1920
    height = (width.float / aspectRatio).int
    viewportHeight = 2f
    viewportWidth = aspectRatio * viewportHeight
    focalLength = 1f
    horizontal = vec3(viewportWidth, 0, 0)
    vertical = vec3(0, viewPortHeight, 0)
    lowerLeftCorner = origin - (horizontal / 2) - (vertical / 2) - vec3(0, 0, focalLength)

    header = "P6\n" & $width & ' ' & $height & " \n255\n"

  var myOutputStr = newSeqUninitialized[byte](header.len + 3 * width * height)
  myOutputStr[0..header.high] = cast[seq[byte]](header)

  let
    workerCount = countProcessors()
    startRenderTime = getMonoTime()

  proc workerThread(id: int) {.thread.} = {.cast(gcSafe).}:
    var writer = header.len + id * 3
    for y in countdown(height - 1, 0):
      var x = id
      while x < width:
        let
          u = x.float32 / width.float32
          v = y.float32 / height.float32
          r = Ray(origin: origin, dir: lowerLeftCorner + u * horizontal + v * vertical - origin)
          color = r.color(vec3(0, 0, -1), 0.5)

        myOutputStr[writer + 0] = (color.x * 255.0).uint8.byte
        myOutputStr[writer + 1] = (color.y * 255.0).uint8.byte
        myOutputStr[writer + 2] = (color.z * 255.0).uint8.byte

        writer += 3 * workerCount
        x += workerCount

  var workers = newSeqOfCap[Thread[int]](workerCount)
  for id in 0..workerCount:
    workers.add default(Thread[int])
    workers[id].createThread workerThread, id

  for worker in workers:
    worker.joinThread()

  let
    endRenderTime = getMonoTime()
    startSaveTime = getMonoTime()

  writeFile "output.ppm", myOutputStr.toOpenArray(0, myOutputStr.high)

  let endSaveTime = getMonoTime()
  echo fmt"It took {endRenderTime - startRenderTime} to render and {endSaveTime - startSaveTime} to save."
