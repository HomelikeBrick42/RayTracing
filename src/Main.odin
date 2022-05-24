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

import SDL "vendor:sdl2"

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
	SDL_CheckCode(SDL.Init(SDL.INIT_EVERYTHING))
	defer SDL.Quit()

	window := SDL_CheckPointer(
		SDL.CreateWindow(
			"Ray Tracing",
			SDL.WINDOWPOS_UNDEFINED,
			SDL.WINDOWPOS_UNDEFINED,
			Width,
			Height,
			SDL.WINDOW_SHOWN,
		),
	)
	defer SDL.DestroyWindow(window)

	renderer := SDL_CheckPointer(SDL.CreateRenderer(window, -1, SDL.RENDERER_ACCELERATED))
	defer SDL.DestroyRenderer(renderer)

	texture := SDL_CheckPointer(
		SDL.CreateTexture(
			renderer,
			auto_cast SDL.PixelFormatEnum.RGBA32,
			SDL.TextureAccess.STREAMING,
			Width,
			Height,
		),
	)
	defer SDL.DestroyTexture(texture)
	SDL_CheckCode(SDL.SetTextureBlendMode(texture, .BLEND))

	pixels := new([Height * Width][4]u8)
	defer free(pixels)

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

	loop: for {
		for event: SDL.Event; SDL.PollEvent(&event) != 0; {
			#partial switch event.type {
			case .QUIT:
				break loop
			}
		}

		for y in 0 .. Height - 1 {
			for x in 0 .. Width - 1 {
				uv := glsl.dvec2{f64(x) / f64(Width), f64(Height - y - 1) / f64(Height)} * 2.0 - 1.0
				when Width > Height {
					uv.x *= f64(Width) / f64(Height)
				} else {
					uv.y *= f64(Height) / f64(Width)
				}

				ray := Ray {
					origin    = camera.position,
					direction = glsl.normalize_dvec3(
						camera.forward + camera.right * uv.x + camera.up * uv.y,
					),
				}

				pixels[x + y * Width] = RGBToPixel(RayMarch(ray, objects[:], &r), 0.25)
			}
		}

		SDL_CheckCode(SDL.UpdateTexture(texture, nil, pixels, Width * size_of([4]u8)))
		SDL_CheckCode(SDL.RenderCopy(renderer, texture, nil, nil))
		SDL.RenderPresent(renderer)
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

RGBToPixel :: proc(color: glsl.dvec3, alpha := 1.0) -> [4]u8 {
	return {
		u8(math.round(clamp(color.r, 0.0, 1.0) * 255)),
		u8(math.round(clamp(color.g, 0.0, 1.0) * 255)),
		u8(math.round(clamp(color.b, 0.0, 1.0) * 255)),
		u8(math.round(clamp(alpha, 0.0, 1.0) * 255)),
	}
}

SDL_CheckCode :: proc(code: c.int) {
	if code != 0 {
		fmt.eprintf("SDL Error: %s\n", SDL.GetError())
		intrinsics.trap()
	}
}

SDL_CheckPointer :: proc(pointer: ^$T) -> ^T {
	if pointer == nil {
		fmt.eprintf("SDL Error: %s\n", SDL.GetError())
		intrinsics.trap()
	}
	return pointer
}
