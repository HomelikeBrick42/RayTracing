package main

import "core:thread"
import "core:sync"
import "core:math/linalg/glsl"
import "core:math/rand"

import "vendor:glfw"
import gl "vendor:opengl"

Width :: 640
Height :: 480

Camera :: struct {
	position: glsl.dvec3,
	forward:  glsl.dvec3,
	right:    glsl.dvec3,
	up:       glsl.dvec3,
}

Ray :: struct {
	origin:    glsl.dvec3,
	direction: glsl.dvec3,
}

Object :: union {
	Sphere,
	Plane,
}

Object_GetColor :: #force_inline proc(object: Object) -> glsl.dvec3 {
	switch o in object {
	case Sphere:
		return o.color
	case Plane:
		return o.color
	case:
		return {0.0, 0.0, 0.0}
	}
}

Object_GetReflectiveness :: #force_inline proc(object: Object) -> f64 {
	switch o in object {
	case Sphere:
		return o.reflectiveness
	case Plane:
		return o.reflectiveness
	case:
		return 0.0
	}
}

Object_GetScatter :: #force_inline proc(object: Object) -> f64 {
	switch o in object {
	case Sphere:
		return o.scatter
	case Plane:
		return o.scatter
	case:
		return 0.0
	}
}

Sphere :: struct {
	color:          glsl.dvec3,
	reflectiveness: f64,
	scatter:        f64,
	position:       glsl.dvec3,
	radius:         f64,
}

Plane :: struct {
	color:          glsl.dvec3,
	attenuation:    f64,
	scatter:        f64,
	reflectiveness: f64,
	y_position:     f64,
}

Draw :: proc(
	camera: ^Camera,
	objects: []Object,
	y_start: int,
	y_end: int,
	pixels: []glsl.vec3,
	r: ^rand.Rand,
) {
	for y in y_start .. y_end - 1 {
		for x in 0 .. Width - 1 {
			uv := glsl.dvec2{f64(x) / f64(Width), f64(y) / f64(Height)} * 2.0 - 1.0
			when Width > Height {
				uv.x *= f64(Width) / f64(Height)
			} else {
				uv.y *= f64(Height) / f64(Width)
			}
			uv += RandomDirectionInUnitCircle(r) / {f64(Width), f64(Height)}

			ray := Ray {
				origin    = camera.position,
				direction = glsl.normalize_dvec3(
					camera.forward + camera.right * uv.x + camera.up * uv.y,
				),
			}

			color := RayMarch(ray, objects[:], r)
			pixels[x + y * Width] += {cast(f32)color.r, cast(f32)color.g, cast(f32)color.b}
		}
	}
}

main :: proc() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.VISIBLE, 0)
	window := glfw.CreateWindow(Width, Height, "Ray Tracing", nil, nil)
	defer glfw.DestroyWindow(window)
	glfw.MakeContextCurrent(window)

	gl.load_up_to(4, 6, glfw.gl_set_proc_address)

	pixels := new([Height * Width]glsl.vec3)
	defer free(pixels)

	texture: u32
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	defer gl.DeleteTextures(1, &texture)
	gl.TextureStorage2D(texture, 1, gl.RGB32F, Width, Height)

	texture_index := u32(0)
	gl.BindTextureUnit(texture_index, texture)

	shader, shader_ok := gl.load_shaders_source(
		string(#load("./VertexShader.glsl")),
		string(#load("./FragmentShader.glsl")),
	)
	gl.UseProgram(shader)
	gl.ProgramUniform1i(
		shader,
		gl.GetUniformLocation(shader, "u_Texture"),
		i32(texture_index),
	)

	camera := Camera {
		position = {0.0, 1.0, -3.0},
		forward = {0.0, 0.0, 1.0},
		right = {1.0, 0.0, 0.0},
		up = {0.0, 1.0, 0.0},
	}

	objects := [?]Object{
		Plane{color = {0.2, 0.8, 0.3}, reflectiveness = 0.0, scatter = 1.0, y_position = 0.0},
		Sphere{
			color = {0.1, 0.3, 0.8},
			reflectiveness = 0.0,
			scatter = 1.0,
			position = {0.0, 1.0, 0.0},
			radius = 1.0,
		},
	}

	ThreadCount :: 12
	#assert(Height % ThreadCount == 0)

	@(static)
	quit := false

	start_barrier: sync.Barrier
	end_barrier: sync.Barrier
	sync.barrier_init(&start_barrier, ThreadCount + 1)
	sync.barrier_init(&end_barrier, ThreadCount + 1)

	RenderData :: struct {
		start_barrier: ^sync.Barrier,
		end_barrier:   ^sync.Barrier,
		camera:        ^Camera,
		objects:       []Object,
		pixels:        []glsl.vec3,
		y_start:       int,
		y_end:         int,
	}

	render_threads: [ThreadCount]^thread.Thread
	render_datas: [ThreadCount]RenderData
	for i in 0 .. ThreadCount - 1 {
		render_datas[i] = RenderData {
			start_barrier = &start_barrier,
			end_barrier   = &end_barrier,
			camera        = &camera,
			objects       = objects[:],
			pixels        = pixels[:],
			y_start       = (i + 0) * (Height / ThreadCount),
			y_end         = (i + 1) * (Height / ThreadCount),
		}
		render_threads[i] = thread.create_and_start_with_data(
			&render_datas[i],
			proc(data: rawptr) {
				using data := cast(^RenderData)data
				r := rand.create(0) // TODO: generate different seed for each thread
				for !sync.atomic_load(&quit) {
					sync.barrier_wait(start_barrier)
					if sync.atomic_load(&quit) {
						return
					}
					Draw(camera, objects, y_start, y_end, pixels, &r)
					sync.barrier_wait(end_barrier)
				}
			},
		)
	}

	samples: u32 = 0
	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		sync.barrier_wait(&start_barrier)
		sync.barrier_wait(&end_barrier)

		samples += 1
		gl.ProgramUniform1ui(shader, gl.GetUniformLocation(shader, "u_Samples"), samples)
		gl.TextureSubImage2D(texture, 0, 0, 0, Width, Height, gl.RGB, gl.FLOAT, &pixels[0][0])
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
		glfw.SwapBuffers(window)
	}
	glfw.HideWindow(window)

	sync.atomic_store(&quit, true)
	sync.barrier_wait(&start_barrier)
	for render_thread in render_threads {
		thread.join(render_thread)
	}
}
