package main

import "core:fmt"
import "core:thread"
import "core:sync"
import "core:math"
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
	v_fov:    f64,
}

main :: proc() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.VISIBLE, 0)
	window := glfw.CreateWindow(Width, Height, "Ray Tracing", nil, nil)
	defer glfw.DestroyWindow(window)
	glfw.MakeContextCurrent(window)

	gl.load_up_to(4, 6, glfw.gl_set_proc_address)

	texture: u32
	gl.GenTextures(1, &texture)
	defer gl.DeleteTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TextureParameteri(texture, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(texture, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TextureStorage2D(texture, 1, gl.RGBA32F, Width, Height)
	gl.BindImageTexture(0, texture, 0, false, 0, gl.READ_WRITE, gl.RGBA32F)

	texture_index := u32(0)
	gl.BindTextureUnit(texture_index, texture)

	shader, _ := gl.load_shaders_source(
		string(#load("./VertexShader.glsl")),
		string(#load("./FragmentShader.glsl")),
	)
	gl.ProgramUniform1i(
		shader,
		gl.GetUniformLocation(shader, "u_Texture"),
		i32(texture_index),
	)

	compute_shader, _ := gl.load_compute_source(string(#load("./ComputeShader.glsl")))

	planes := [?]Plane{
		Plane{
			material = Material{
				color = {0.2, 0.8, 0.3},
				emission_color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				scatter = 1.0,
			},
			y_position = 0.0,
		},
	}

	spheres := [?]Sphere{
		Sphere{
			material = Material{
				color = {0.1, 0.3, 0.8},
				reflectiveness = 0.0,
				emission_color = {0.0, 0.0, 0.0},
				scatter = 1.0,
			},
			position = {-1.1, 1.0, 0.0},
			radius = 1.0,
		},
		Sphere{
			material = Material{
				color = {0.0, 0.0, 0.0},
				reflectiveness = 0.0,
				emission_color = glsl.dvec3{0.8, 0.4, 0.2} * 2.0,
				scatter = 0.0,
			},
			position = {0.5, 0.5, -0.75},
			radius = 0.5,
		},
	}

	plane_buffer: u32
	gl.GenBuffers(1, &plane_buffer)
	defer gl.DeleteBuffers(1, &plane_buffer)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, plane_buffer)
	gl.BufferData(
		gl.SHADER_STORAGE_BUFFER,
		len(planes) * size_of(planes[0]),
		&planes[0],
		gl.STATIC_DRAW,
	)
	gl.ProgramUniform1ui(
		compute_shader,
		gl.GetUniformLocation(compute_shader, "u_PlaneCount"),
		len(planes),
	)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, plane_buffer)

	sphere_buffer: u32
	gl.GenBuffers(1, &sphere_buffer)
	defer gl.DeleteBuffers(1, &sphere_buffer)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, sphere_buffer)
	gl.BufferData(
		gl.SHADER_STORAGE_BUFFER,
		len(spheres) * size_of(spheres[0]),
		&spheres[0],
		gl.STATIC_DRAW,
	)
	gl.ProgramUniform1ui(
		compute_shader,
		gl.GetUniformLocation(compute_shader, "u_SphereCount"),
		len(spheres),
	)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 2, sphere_buffer)

	camera := Camera {
		position = {0.0, 1.0, -3.0},
		forward = {0.0, 0.0, 1.0},
		right = {1.0, 0.0, 0.0},
		up = {0.0, 1.0, 0.0},
		v_fov = 45.0,
	}

	samples: u32 = 0
	last_time := glfw.GetTime()
	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		time := glfw.GetTime()
		delta := time - last_time
		defer last_time = time

		gl.UseProgram(compute_shader)
		gl.ProgramUniform3dv(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Camera.position"),
			1,
			&camera.position[0],
		)
		gl.ProgramUniform3dv(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Camera.forward"),
			1,
			&camera.forward[0],
		)
		gl.ProgramUniform3dv(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Camera.right"),
			1,
			&camera.right[0],
		)
		gl.ProgramUniform3dv(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Camera.up"),
			1,
			&camera.up[0],
		)
		gl.ProgramUniform1d(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Camera.v_fov"),
			camera.v_fov,
		)

		gl.ProgramUniform1f(
			compute_shader,
			gl.GetUniformLocation(compute_shader, "u_Time"),
			f32(time),
		)

		#assert(Width % 8 == 0)
		#assert(Height % 4 == 0)
		gl.DispatchCompute(Width / 8, Height / 4, 1)
		gl.MemoryBarrier(gl.ALL_BARRIER_BITS)

		samples += 1
		gl.UseProgram(shader)
		gl.ProgramUniform1ui(shader, gl.GetUniformLocation(shader, "u_Samples"), samples)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
		glfw.SwapBuffers(window)

		fmt.printf("FPS: %.3f, Samples: %i                \r", 1.0 / delta, samples)
	}
	glfw.HideWindow(window)
}
