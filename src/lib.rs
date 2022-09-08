mod and;
mod camera;
mod cutout;
mod hit;
mod material;
mod ray;
mod sdf;
mod sphere;
mod vector2;
mod vector3;

pub use and::*;
pub use camera::*;
pub use cutout::*;
pub use hit::*;
pub use material::*;
pub use ray::*;
pub use sdf::*;
pub use sphere::*;
pub use vector2::*;
pub use vector3::*;

pub fn rand_in_hemisphere(normal: Vector3<f64>, rng: &mut impl rand::Rng) -> Vector3<f64> {
    let rand = Vector3 {
        x: rng.gen::<f64>() * 2.0 - 1.0,
        y: rng.gen::<f64>() * 2.0 - 1.0,
        z: rng.gen::<f64>() * 2.0 - 1.0,
    };
    if rand.dot(normal) > 0.0 {
        return rand;
    } else {
        return -rand;
    }
}
