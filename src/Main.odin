package main

import "core:c"
import "core:os"
import "core:fmt"
import "core:thread"
import "core:sync"
import "core:intrinsics"
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

Sphere :: struct {
	color:    glsl.dvec3,
	position: glsl.dvec3,
	radius:   f64,
}

Plane :: struct {
	color:      glsl.dvec3,
	y_position: f64,
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
		Plane{color = {0.2, 0.8, 0.3}, y_position = 0.0},
		Sphere{color = {0.1, 0.3, 0.8}, position = {0.0, 1.0, 0.0}, radius = 1.0},
	}

	r := rand.create(0)

	samples: u32 = 0

	glfw.ShowWindow(window)
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()

		for y in 0 .. Height - 1 {
			for x in 0 .. Width - 1 {
				uv := glsl.dvec2{f64(x) / f64(Width), f64(y) / f64(Height)} * 2.0 - 1.0
				when Width > Height {
					uv.x *= f64(Width) / f64(Height)
				} else {
					uv.y *= f64(Height) / f64(Width)
				}
				uv += RandomDirectionInUnitCircle(&r) / {f64(Width), f64(Height)}

				ray := Ray {
					origin    = camera.position,
					direction = glsl.normalize_dvec3(
						camera.forward + camera.right * uv.x + camera.up * uv.y,
					),
				}

				color := RayMarch(ray, objects[:], &r)
				pixels[x + y * Width] += {cast(f32)color.r, cast(f32)color.g, cast(f32)color.b}
			}
		}

		samples += 1

		gl.ProgramUniform1ui(shader, gl.GetUniformLocation(shader, "u_Samples"), samples)
		gl.TextureSubImage2D(texture, 0, 0, 0, Width, Height, gl.RGB, gl.FLOAT, &pixels[0][0])
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
		glfw.SwapBuffers(window)
	}
	glfw.HideWindow(window)
}

RandomDirectionInUnitCircle :: proc(r: ^rand.Rand) -> glsl.dvec2 {
	for {
		direction := glsl.dvec2{
			rand.float64_range(-1.0, 1.0, r),
			rand.float64_range(-1.0, 1.0, r),
		}
		if glsl.dot(direction, direction) > 1.0 do continue
		return direction
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

RayMarch :: proc(
	ray: Ray,
	objects: []Object,
	r: ^rand.Rand,
	depth := uint(0),
) -> glsl.dvec3 {
	MaxDistance :: 1000.0
	MinDistance :: 0.01
	MaxBounces :: 500

	GetDistance :: #force_inline proc(point: glsl.dvec3, object: Object) -> f64 {
		switch o in object {
		case Sphere:
			return glsl.length_dvec3(point - o.position) - o.radius
		case Plane:
			return abs(point.y - o.y_position)
		case:
			return math.INF_F64
		}
	}

	DE :: #force_inline proc(point: glsl.dvec3, objects: []Object) -> f64 {
		distance := math.INF_F64
		for object in objects {
			distance = min(distance, GetDistance(point, object))
		}
		return distance
	}

	GetClosestObject :: #force_inline proc(point: glsl.dvec3, objects: []Object) -> (
		distance: f64,
		closest_object: ^Object,
	) {
		objects := objects

		distance = math.INF_F64
		for object in &objects {
			new_distance := GetDistance(point, object)
			if new_distance < distance {
				distance = new_distance
				closest_object = &object
			}
		}

		return
	}

	totalDistance := 0.0
	for {
		point := ray.origin + ray.direction * totalDistance
		distance := DE(point, objects)
		totalDistance += distance
		if abs(totalDistance) > MaxDistance do break
		if abs(distance) < MinDistance {
			XDir :: glsl.dvec3{MinDistance, 0.0, 0.0}
			YDir :: glsl.dvec3{0.0, MinDistance, 0.0}
			ZDir :: glsl.dvec3{0.0, 0.0, MinDistance}
			normal := glsl.normalize_dvec3(
				{
					DE(point + XDir, objects) - DE(point - XDir, objects),
					DE(point + YDir, objects) - DE(point - YDir, objects),
					DE(point + ZDir, objects) - DE(point - ZDir, objects),
				},
			)

			_, object := GetClosestObject(point, objects)
			assert(object != nil)

			target := point + normal + RandomDirectionInUnitSphere(r)
			if depth < MaxBounces {
				new_origin := point + normal * MinDistance
				return Object_GetColor(
					object^,
				) * RayMarch(
					Ray{origin = new_origin, direction = glsl.normalize(target - new_origin)},
					objects,
					r,
					depth + 1,
				)
			} else {
				return Object_GetColor(object^)
			}
		}
	}

	return glsl.lerp_dvec3({1.0, 1.0, 1.0}, {0.5, 0.7, 1.0}, ray.direction.y * 0.5 + 0.5)
}
