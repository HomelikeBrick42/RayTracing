package main

// import "core:math"
// import "core:math/rand"
// import "core:math/linalg/glsl"

// RayMarch :: proc(
// 	ray: Ray,
// 	objects: []Object,
// 	r: ^rand.Rand,
// 	depth := uint(0),
// ) -> glsl.dvec3 {
// 	MaxDistance :: 1000.0
// 	MinDistance :: 0.01
// 	MaxBounces :: 500

// 	GetDistance :: #force_inline proc(point: glsl.dvec3, object: Object) -> f64 {
// 		switch o in object {
// 		case Sphere:
// 			return glsl.length_dvec3(point - o.position) - o.radius
// 		case Plane:
// 			return abs(point.y - o.y_position)
// 		case:
// 			return math.INF_F64
// 		}
// 	}

// 	DE :: #force_inline proc(point: glsl.dvec3, objects: []Object) -> f64 {
// 		distance := math.INF_F64
// 		for object in objects {
// 			distance = min(distance, GetDistance(point, object))
// 		}
// 		return distance
// 	}

// 	GetClosestObject :: #force_inline proc(point: glsl.dvec3, objects: []Object) -> (
// 		distance: f64,
// 		closest_object: ^Object,
// 	) {
// 		objects := objects

// 		distance = math.INF_F64
// 		for object in &objects {
// 			new_distance := GetDistance(point, object)
// 			if new_distance < distance {
// 				distance = new_distance
// 				closest_object = &object
// 			}
// 		}

// 		return
// 	}

// 	if depth > MaxBounces do return {}

// 	totalDistance := 0.0
// 	for {
// 		point := ray.origin + ray.direction * totalDistance
// 		distance := DE(point, objects)
// 		totalDistance += distance
// 		if abs(totalDistance) > MaxDistance do break
// 		if abs(distance) < MinDistance {
// 			XDir :: glsl.dvec3{MinDistance, 0.0, 0.0}
// 			YDir :: glsl.dvec3{0.0, MinDistance, 0.0}
// 			ZDir :: glsl.dvec3{0.0, 0.0, MinDistance}
// 			normal := glsl.normalize_dvec3(
// 				{
// 					DE(point + XDir, objects) - DE(point - XDir, objects),
// 					DE(point + YDir, objects) - DE(point - YDir, objects),
// 					DE(point + ZDir, objects) - DE(point - ZDir, objects),
// 				},
// 			)

// 			_, object := GetClosestObject(point, objects)
// 			assert(object != nil)

// 			material := Object_GetMaterial(object^)

// 			return glsl.lerp(
// 				material.color,
// 				1.0,
// 				material.reflectiveness,
// 			) * RayMarch(
// 				Ray{
// 					origin = point + normal * MinDistance,
// 					direction = glsl.lerp(
// 						glsl.reflect(ray.direction, normal),
// 						glsl.normalize(RandomInHemisphere(normal, r)),
// 						material.scatter,
// 					),
// 				},
// 				objects,
// 				r,
// 				depth + 1,
// 			) + material.emission_color
// 		}
// 	}

// 	return 0.0
// 	// return glsl.lerp_dvec3({1.0, 1.0, 1.0}, {0.5, 0.7, 1.0}, ray.direction.y * 0.5 + 0.5)
// }
