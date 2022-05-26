package main

import "core:fmt"
import "core:thread"
import "core:sync"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
when ODIN_OS == .Windows {
	import "core:sys/windows"
}

import "vendor:glfw"
import gl "vendor:opengl"

Width :: 640
Height :: 480
FOV :: 45.0

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
			uv *= math.tan_f64(FOV * math.RAD_PER_DEG * 0.5) * 2.0

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
	gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
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
	gl.ProgramUniform2ui(shader, gl.GetUniformLocation(shader, "u_ImageSize"), Width, Height)

	camera := Camera {
		position = {0.0, 1.0, -3.0},
		forward = {0.0, 0.0, 1.0},
		right = {1.0, 0.0, 0.0},
		up = {0.0, 1.0, 0.0},
	}

	objects := [?]Object{
		Plane{
			material = Material{
				color = {0.2, 0.8, 0.3},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			y_position = 0.0,
		},
		Sphere{
			material = Material{
				color = {0.1, 0.3, 0.8},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			position = {-1.1, 1.0, 0.0},
			radius = 1.0,
		},
		Sphere{
			material = Material{
				color = {0.0, 0.0, 0.0},
				emission_color = glsl.dvec3{0.8, 0.4, 0.2} * 2.0,
				reflectiveness = 0.0,
				scatter = 0.0,
			},
			position = {0.5, 0.5, -0.75},
			radius = 0.5,
		},
	}

	thread_count: u64 = 8
	when ODIN_OS == .Windows {
		system_info: windows.SYSTEM_INFO
		windows.GetSystemInfo(&system_info)
		thread_count = u64(system_info.dwNumberOfProcessors)
	}
	fmt.printf("Using %d threads\n", thread_count)
	assert(Height % thread_count == 0)

	@(static)
	quit := false

	RenderData :: struct {
		camera:   ^Camera,
		objects:  []Object,
		pixels:   []glsl.vec3,
		y_start:  int,
		y_end:    int,
		seed:     u64,
		finished: bool,
	}

	render_threads := make([]^thread.Thread, thread_count)
	render_datas := make([]RenderData, thread_count)
	for i in 0 .. thread_count - 1 {
		render_datas[i] = RenderData {
			camera   = &camera,
			objects  = objects[:],
			pixels   = pixels[:],
			y_start  = int((i + 0) * (Height / thread_count)),
			y_end    = int((i + 1) * (Height / thread_count)),
			seed     = rand.uint64(),
			finished = false,
		}
		render_threads[i] = thread.create_and_start_with_data(
			&render_datas[i],
			proc(data: rawptr) {
				using data := cast(^RenderData)data
				r := rand.create(seed)
				for !sync.atomic_load(&quit) {
					if sync.atomic_load(&finished) do continue
					Draw(camera, objects, y_start, y_end, pixels, &r)
					sync.atomic_store(&finished, true)
				}
			},
		)
	}

	glfw.SwapInterval(1)

	gl.ClearColor(0.1, 0.1, 0.1, 1.0)

	glfw.SetKeyCallback(
		window,
		proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
			if action == glfw.PRESS && key == glfw.KEY_R {
				glfw.SetWindowSize(window, Width, Height)
			}
		},
	)

	samples: u32 = 0
	last_sample_time := glfw.GetTime()
	seconds_per_sample := 0.0
	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		all_finished := true
		for render_data in &render_datas {
			if !sync.atomic_load(&render_data.finished) {
				all_finished = false
				break
			}
		}
		if all_finished {
			time := glfw.GetTime()
			seconds_per_sample = time - last_sample_time
			last_sample_time = time

			samples += 1
			gl.ProgramUniform1ui(shader, gl.GetUniformLocation(shader, "u_Samples"), samples)
			gl.TextureSubImage2D(texture, 0, 0, 0, Width, Height, gl.RGB, gl.FLOAT, &pixels[0][0])
			for render_data in &render_datas {
				sync.atomic_store(&render_data.finished, false)
			}
		}

		window_width, window_height := glfw.GetWindowSize(window)
		gl.ProgramUniform2ui(
			shader,
			gl.GetUniformLocation(shader, "u_ScreenSize"),
			u32(window_width),
			u32(window_height),
		)
		gl.Viewport(0, 0, window_width, window_height)

		gl.Clear(gl.COLOR_BUFFER_BIT)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
		glfw.SwapBuffers(window)

		fmt.printf(
			"Samples: %i, Samples Per Second: %.3f                \r",
			samples,
			1.0 / seconds_per_sample,
		)
	}
	glfw.HideWindow(window)

	sync.atomic_store(&quit, true)
	for render_thread in render_threads {
		thread.join(render_thread)
	}
}
