package main

import "core:c"
import "core:os"
import "core:fmt"
import "core:runtime"

import "core:sync"
import "core:thread"

import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:opengl"

when ODIN_OS == .Windows {
	import "core:sys/windows"
}

Width :: 640
Height :: 480
Aspect :: f64(Width) / f64(Height)
IsDay :: false

Camera :: struct {
	position: glsl.dvec3,
	forward:  glsl.dvec3,
	right:    glsl.dvec3,
	up:       glsl.dvec3,
	fov:      f64,
}

Ray :: struct {
	origin:    glsl.dvec3,
	direction: glsl.dvec3,
}

Hit :: struct {
	distance: f64,
	point:    glsl.dvec3,
	normal:   glsl.dvec3,
	material: Material,
}

Material :: struct {
	diffuse_color:  glsl.dvec3,
	emission_color: glsl.dvec3,
	reflectiveness: f64,
	scatter:        f64,
}

Object :: struct {
	material: Material,
	type:     union {
		Sphere,
	},
}

Sphere :: struct {
	position: glsl.dvec3,
	radius:   f64,
}

Object_TryHit :: proc(object: Object, ray: Ray) -> Maybe(Hit) {
	switch o in object.type {
	case Sphere:
		sphere := o
		oc := ray.origin - sphere.position
		a := glsl.dot(ray.direction, ray.direction)
		b := 2.0 * glsl.dot(oc, ray.direction)
		c := glsl.dot(oc, oc) - sphere.radius * sphere.radius
		discriminant := b * b - 4 * a * c
		if discriminant >= 0 {
			distance := (-b - math.sqrt(discriminant)) / (2.0 * a)
			if distance >= 0 {
				point := ray.origin + ray.direction * distance
				normal := glsl.normalize(point - sphere.position)
				return Hit{
					distance = distance,
					point = point,
					normal = normal,
					material = object.material,
				}
			}
		}
	}
	return nil
}

main :: proc() {
	if glfw.Init() == 0 {
		fmt.eprintf("GLFW Error {1}: {0}\n", glfw.GetError())
		os.exit(1)
	}
	defer glfw.Terminate()

	glfw.SetErrorCallback(proc "c" (code: c.int, description: cstring) {
			context = runtime.default_context()
			fmt.eprintf("GLFW Error {}: {}\n", code, description)
		})

	glfw.WindowHint(glfw.RESIZABLE, 0)
	glfw.WindowHint(glfw.VISIBLE, 0)
	window := glfw.CreateWindow(Width, Height, "Ray Tracing", nil, nil)
	if window == nil {
		fmt.eprintf("GLFW Error {1}: {0}\n", glfw.GetError())
		os.exit(1)
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)
	gl.load_up_to(4, 6, glfw.gl_set_proc_address)

	vertex_array: u32
	gl.GenVertexArrays(1, &vertex_array)
	defer gl.DeleteVertexArrays(1, &vertex_array)
	gl.BindVertexArray(vertex_array)

	shader, _ := gl.load_shaders_source(
		string(#load("./VertexShader.glsl")),
		string(#load("./FragmentShader.glsl")),
	)
	defer gl.DeleteProgram(shader)

	TextureIndex :: 0

	texture: u32
	gl.GenTextures(1, &texture)
	defer gl.DeleteTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TextureStorage2D(texture, 1, gl.RGB32F, Width, Height)
	gl.BindTextureUnit(TextureIndex, texture)

	pixels := make([]glsl.vec3, Width * Height)
	defer delete(pixels)

	GetSkyColor :: proc(ray: Ray) -> glsl.dvec3 {
		when IsDay {
			return glsl.lerp_dvec3({1.0, 1.0, 1.0}, {0.5, 0.7, 1.0}, ray.direction.y * 0.5 + 0.5)
		} else {
			return {0.0, 0.0, 0.0}
		}
	}

	camera := Camera {
		position = {0.0, 1.0, -4.0},
		forward = {0.0, 0.0, 1.0},
		right = {1.0, 0.0, 0.0},
		up = {0.0, 1.0, 0.0},
		fov = 45.0,
	}

	objects := [?]Object{
		Object{
			material = Material{
				diffuse_color = {0.2, 0.8, 0.1},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			type = Sphere{position = {0.0, -100000.0, 0.0}, radius = 100000.0},
		},
		Object{
			material = Material{
				diffuse_color = {0.1, 0.2, 0.8},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			type = Sphere{position = {-0.4, 1.0, 0.0}, radius = 1.0},
		},
		Object{
			material = Material{
				diffuse_color = {0.8, 0.8, 0.6},
				emission_color = glsl.dvec3{0.8, 0.8, 0.6} * 2.0,
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			type = Sphere{position = {1.0, 0.4, -1.0}, radius = 0.4},
		},
	}

	thread_count := 8
	when ODIN_OS == .Windows {
		system_info: windows.SYSTEM_INFO
		windows.GetSystemInfo(&system_info)
		thread_count = int(system_info.dwNumberOfProcessors)
	}
	fmt.printf("Using %d threads\n", thread_count)

	pool: thread.Pool
	thread.pool_init(&pool, context.allocator, thread_count - 1)
	defer thread.pool_destroy(&pool)
	thread.pool_start(&pool)
	defer thread.pool_finish(&pool)

	HeightPerTask :: 1
	#assert(Height % HeightPerTask == 0)

	TaskData :: struct {
		start_y: int,
		height:  int,
		r:       rand.Rand,
		camera:  Camera,
		objects: []Object,
		pixels:  []glsl.vec3,
	}
	thread_datas: [Height / HeightPerTask]TaskData
	for thread_data, i in &thread_datas {
		thread_data.start_y = i * HeightPerTask
		thread_data.height = HeightPerTask
		thread_data.r = rand.create(rand.uint64())
	}

	TaskProc :: proc(task: thread.Task) {
		using thread_data := cast(^TaskData)task.data
		for y in start_y .. start_y + height - 1 {
			for x in 0 .. Width - 1 {
				uv := glsl.dvec2{f64(x) / f64(Width), f64(y) / f64(Height)} * 2.0 - 1.0
				when Width > Height {
					uv.x *= f64(Width) / f64(Height)
				} else {
					uv.y *= f64(Height) / f64(Width)
				}
				uv += RandomDirectionInUnitCircle(&r) / {f64(Width), f64(Height)}
				uv *= math.tan_f64(camera.fov * math.RAD_PER_DEG * 0.5) * 2.0

				ray := Ray {
					origin    = camera.position,
					direction = glsl.normalize(camera.forward + camera.right * uv.x + camera.up * uv.y),
				}

				color := TraceRay(ray, objects[:], GetSkyColor, &r, 100)
				pixels[x + y * Width] += {f32(color.r), f32(color.g), f32(color.b)}
			}
		}
	}

	samples := u32(0)
	last_time := glfw.GetTime()
	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		for task in thread.pool_pop_done(&pool) {
			y := (^TaskData)(task.data).start_y
			gl.TextureSubImage2D(
				texture,
				0,
				0,
				i32(y),
				Width,
				HeightPerTask,
				gl.RGB,
				gl.FLOAT,
				&pixels[y * Width],
			)
		}
		if thread.pool_is_empty(&pool) {
			samples += 1
			time := glfw.GetTime()
			dt := time - last_time
			last_time = time
			fmt.printf(
				"\rSeconds per sample: %.3f, Samples per second: %.3f, Samples: %d                ",
				dt,
				1.0 / dt,
				samples,
			)
			for thread_data in &thread_datas {
				thread_data.camera = camera
				thread_data.objects = objects[:]
				thread_data.pixels = pixels
				thread.pool_add_task(&pool, context.allocator, TaskProc, &thread_data)
			}
		}

		gl.UseProgram(shader)
		gl.Uniform1ui(gl.GetUniformLocation(shader, "u_Texture"), TextureIndex)
		gl.Uniform1ui(gl.GetUniformLocation(shader, "u_Samples"), samples)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

		glfw.SwapBuffers(window)
	}
	glfw.HideWindow(window)
}

TraceRay :: proc(
	ray: Ray,
	objects: []Object,
	sky_color: proc(ray: Ray) -> glsl.dvec3,
	r: ^rand.Rand,
	allowed_bounces: int,
) -> glsl.dvec3 {
	if allowed_bounces < 0 do return {0.0, 0.0, 0.0}

	closest_hit: Maybe(Hit)
	for object in objects {
		hit := Object_TryHit(object, ray)
		if hit, ok := hit.(Hit); ok {
			if close_hit, ok := closest_hit.(Hit); ok {
				if hit.distance < close_hit.distance {
					closest_hit = hit
				}
			} else {
				closest_hit = hit
			}
		}
	}

	if hit, ok := closest_hit.(Hit); ok {
		return glsl.lerp(
			hit.material.diffuse_color,
			1.0,
			hit.material.reflectiveness,
		) * TraceRay(
			Ray{
				origin = hit.point,
				direction = glsl.lerp(
					glsl.reflect(ray.direction, hit.normal),
					glsl.normalize(RandomInHemisphere(hit.normal, r)),
					hit.material.scatter,
				),
			},
			objects,
			sky_color,
			r,
			allowed_bounces - 1,
		) + hit.material.emission_color
	} else {
		return sky_color(ray)
	}
}

RandomDirectionInUnitCircle :: proc(r: ^rand.Rand) -> glsl.dvec2 {
	for {
		random_direction := glsl.dvec2{
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
		}
		if glsl.dot(random_direction, random_direction) > 1.0 do continue
		return random_direction
	}
}

RandomDirectionInUnitSphere :: proc(r: ^rand.Rand) -> glsl.dvec3 {
	for {
		direction := glsl.dvec3{
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
		}
		if glsl.dot(direction, direction) > 1.0 do continue
		return direction
	}
}

RandomInHemisphere :: proc(normal: glsl.dvec3, r: ^rand.Rand) -> glsl.dvec3 {
	in_unit_sphere := RandomDirectionInUnitSphere(r)
	if (glsl.dot(in_unit_sphere, normal) > 0.0) {
		return in_unit_sphere
	} else {
		return -in_unit_sphere
	}
}
