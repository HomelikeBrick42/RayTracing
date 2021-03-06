package main

import "core:c"
import "core:os"
import "core:mem"
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

WindowScale :: 1
Width :: 640
Height :: 480
Aspect :: f64(Width) / f64(Height)
IsDay :: true

Camera :: struct {
	position: glsl.dvec3,
	forward:  glsl.dvec3,
	right:    glsl.dvec3,
	up:       glsl.dvec3,
	pitch:    f64,
	yaw:      f64,
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
		Portal,
	},
}

Sphere :: struct {
	position: glsl.dvec3,
	radius:   f64,
}

Portal :: struct {
	in_sphere:  Sphere,
	out_sphere: Sphere,
}

Sphere_TryHit :: proc(using sphere: Sphere, ray: Ray, material: Material) -> Maybe(Hit) {
	oc := ray.origin - position
	a := glsl.dot(ray.direction, ray.direction)
	b := 2.0 * glsl.dot(oc, ray.direction)
	c := glsl.dot(oc, oc) - radius * radius
	discriminant := b * b - 4 * a * c
	if discriminant >= 0 {
		distance := (-b - math.sqrt(discriminant)) / (2.0 * a)
		if distance >= 0 {
			point := ray.origin + ray.direction * distance
			normal := glsl.normalize(point - position)
			return Hit{distance = distance, point = point, normal = normal, material = material}
		}
	}
	return nil
}

Object_TryHit :: proc(object: Object, ray: Ray) -> Maybe(Hit) {
	switch o in object.type {
	case Sphere:
		return Sphere_TryHit(o, ray, object.material)
	case Portal:
		return Sphere_TryHit(o.in_sphere, ray, object.material)
	case:
		return nil
	}
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
	window := glfw.CreateWindow(
		Width * WindowScale,
		Height * WindowScale,
		"Ray Tracing",
		nil,
		nil,
	)
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
		position = {0.0, 1.0, -5.0},
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
				diffuse_color = glsl.dvec3{0.1, 0.2, 0.8} * 0.25,
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.25,
				scatter = 0.0,
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
		Object{
			material = Material{
				diffuse_color = {0.0, 0.0, 0.0},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.75,
				scatter = 0.0,
			},
			type = Portal{
				in_sphere = Sphere{position = {-1.6, 0.6, -3.0}, radius = 0.6},
				out_sphere = Sphere{position = {1.8, 0.6, -3.0}, radius = 0.6},
			},
		},
		Object{
			material = Material{
				diffuse_color = {0.0, 0.0, 0.0},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.75,
				scatter = 0.0,
			},
			type = Portal{
				in_sphere = Sphere{position = {1.8, 0.6, -3.0}, radius = 0.6},
				out_sphere = Sphere{position = {-1.6, 0.6, -3.0}, radius = 0.6},
			},
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
		end_y:   int,
		r:       rand.Rand,
		camera:  Camera,
		objects: []Object,
		pixels:  []glsl.vec3,
	}
	thread_datas := make([]TaskData, Height / HeightPerTask)
	defer delete(thread_datas)
	for thread_data, i in &thread_datas {
		thread_data.start_y = i * HeightPerTask
		thread_data.end_y = (i + 1) * HeightPerTask - 1
		thread_data.r = rand.create(rand.uint64())
	}

	TaskProc :: proc(task: thread.Task) {
		using thread_data := cast(^TaskData)task.data
		for y in start_y .. end_y {
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
	last_frame_time := glfw.GetTime()
	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		reset_samples := false

		// Update
		{
			time := glfw.GetTime()
			dt := time - last_time
			last_time = time

			// Camera
			{
				CameraSpeed :: 1.0
				CameraRotationSpeed :: 45.0

				if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
					camera.position += camera.forward * CameraSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
					camera.position -= camera.forward * CameraSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
					camera.position -= camera.right * CameraSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
					camera.position += camera.right * CameraSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_Q) == glfw.PRESS {
					camera.position -= camera.up * CameraSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS {
					camera.position += camera.up * CameraSpeed * dt
					reset_samples = true
				}

				if glfw.GetKey(window, glfw.KEY_LEFT) == glfw.PRESS {
					camera.yaw -= CameraRotationSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_RIGHT) == glfw.PRESS {
					camera.yaw += CameraRotationSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_UP) == glfw.PRESS {
					camera.pitch += CameraRotationSpeed * dt
					reset_samples = true
				}
				if glfw.GetKey(window, glfw.KEY_DOWN) == glfw.PRESS {
					camera.pitch -= CameraRotationSpeed * dt
					reset_samples = true
				}

				if reset_samples {
					using camera
					forward.x = math.sin(yaw * math.RAD_PER_DEG) * math.cos(pitch * math.RAD_PER_DEG)
					forward.y = math.sin(pitch * math.RAD_PER_DEG)
					forward.z = math.cos(yaw * math.RAD_PER_DEG) * math.cos(pitch * math.RAD_PER_DEG)
					forward = glsl.normalize(forward)
					right = glsl.cross(glsl.dvec3{0.0, 1.0, 0.0}, forward)
					right = glsl.normalize(right)
					up = glsl.cross(forward, right)
					up = glsl.normalize(up)
				}
			}

			if glfw.GetKey(window, glfw.KEY_R) == glfw.PRESS {
				reset_samples = true
			}

			if reset_samples {
				for !thread.pool_is_empty(&pool) {
					for task in thread.pool_pop_done(&pool) {
						// do nothing
					}
				}
				mem.set(raw_data(pixels), 0, len(pixels) * size_of(pixels[0]))
				gl.TextureSubImage2D(
					texture,
					0,
					0,
					0,
					Width,
					Height,
					gl.RGB,
					gl.FLOAT,
					raw_data(pixels),
				)
				samples = 0
			}
		}

		// Render
		{
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
				frame_dt := time - last_frame_time
				last_frame_time = time
				fmt.printf(
					"\rSeconds per sample: %.3f, Samples per second: %.3f, Samples: %d                ",
					frame_dt,
					1.0 / frame_dt,
					samples,
				)
				for thread_data in &thread_datas {
					thread_data.camera = camera
					thread_data.objects = objects[:]
					thread_data.pixels = pixels
					thread.pool_add_task(&pool, context.allocator, TaskProc, &thread_data)
				}
			}
			if reset_samples {
				for !thread.pool_is_empty(&pool) {
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
				}
			}

			gl.UseProgram(shader)
			gl.Uniform1ui(gl.GetUniformLocation(shader, "u_Texture"), TextureIndex)
			gl.Uniform1ui(gl.GetUniformLocation(shader, "u_Samples"), samples)
			gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

			glfw.SwapBuffers(window)
		}
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
	objects := objects

	if allowed_bounces < 0 do return {0.0, 0.0, 0.0}

	closest_hit: Maybe(Hit)
	closest_object: ^Object
	for object in &objects {
		hit := Object_TryHit(object, ray)
		if hit, ok := hit.(Hit); ok {
			if close_hit, ok := closest_hit.(Hit); ok {
				if hit.distance < close_hit.distance {
					closest_hit = hit
					closest_object = &object
				}
			} else {
				closest_hit = hit
				closest_object = &object
			}
		}
	}

	if hit, ok := closest_hit.(Hit); ok {
		if portal, ok := closest_object.type.(Portal); ok {
			point: glsl.dvec3
			{
				using portal.in_sphere
				oc := ray.origin - position
				a := glsl.dot(ray.direction, ray.direction)
				b := 2.0 * glsl.dot(oc, ray.direction)
				c := glsl.dot(oc, oc) - radius * radius
				discriminant := b * b - 4 * a * c
				distance := (-b + math.sqrt(discriminant)) / (2.0 * a)
				point = ray.origin + ray.direction * distance
			}
			return glsl.lerp(
				hit.material.diffuse_color,
				1.0,
				hit.material.reflectiveness,
			) * TraceRay(
				Ray{
					origin = portal.out_sphere.position + point - portal.in_sphere.position,
					direction = glsl.lerp(
						ray.direction,
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
		}
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
