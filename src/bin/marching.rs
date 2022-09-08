use std::{io::Write, sync::Arc};

use image::Rgb;

use num::traits::real::Real;
use rand::Rng;
use raytracer::*;
use threadpool::ThreadPool;

fn main() {
    const WIDTH: usize = 640;
    const HEIGHT: usize = 480;
    const SAMPLES: usize = 2048;
    const MAX_BOUNCES: usize = 64;
    const THREAD_COUNT: usize = 8;

    let objects: Arc<[Box<dyn SDF<f64, f64> + Send + Sync>]> = Arc::new([
        Box::new(Cutout {
            object: Box::new(Sphere {
                position: Vector3 {
                    x: 0.0,
                    y: 0.9,
                    z: 0.0,
                },
                radius: 1.0,
                material: Material {
                    diffuse_color: Vector3 {
                        x: 0.2,
                        y: 0.3,
                        z: 0.8,
                    },
                    emissive_color: Vector3::zero(),
                    smoothness: 0.0,
                },
            }),
            cutout: Box::new(Sphere {
                position: Vector3 {
                    x: 0.4,
                    y: 1.0,
                    z: -0.5,
                },
                radius: 0.7,
                material: Material {
                    diffuse_color: Vector3 {
                        x: 0.2,
                        y: 0.3,
                        z: 0.8,
                    },
                    emissive_color: Vector3::zero(),
                    smoothness: 0.0,
                },
            }),
        }),
        Box::new(Sphere {
            position: Vector3 {
                x: 0.0,
                y: -1e10,
                z: 0.0,
            },
            radius: 1e10,
            material: Material {
                diffuse_color: Vector3 {
                    x: 0.2,
                    y: 0.8,
                    z: 0.3,
                },
                emissive_color: Vector3::zero(),
                smoothness: 0.0,
            },
        }),
    ]);
    let camera = Camera {
        position: Vector3 {
            x: 0.0,
            y: 1.0,
            z: -3.0,
        },
        forward: Vector3 {
            x: 0.0,
            y: 0.0,
            z: 1.0,
        },
        right: Vector3 {
            x: 1.0,
            y: 0.0,
            z: 0.0,
        },
        up: Vector3 {
            x: 0.0,
            y: 1.0,
            z: 0.0,
        },
        aspect: WIDTH as f64 / HEIGHT as f64,
    };

    let (sender, receiver) = std::sync::mpsc::channel::<(usize, Vec<Vector3<f64>>)>();

    let pool = ThreadPool::new(THREAD_COUNT);
    for y in 0..HEIGHT {
        let sender = sender.clone();
        let objects = objects.clone();
        let camera = camera.clone();
        pool.execute(move || {
            let mut rng = rand::thread_rng();
            let mut row = vec![Vector3::zero(); WIDTH];
            for x in 0..WIDTH {
                for _ in 0..SAMPLES {
                    let ray = camera.get_ray(
                        ((x as f64 + 0.5) / WIDTH as f64) * 2.0 - 1.0
                            + ((rng.gen::<f64>() * 2.0 - 1.0) / WIDTH as f64),
                        -(((y as f64 + 0.5) / HEIGHT as f64) * 2.0 - 1.0
                            + ((rng.gen::<f64>() * 2.0 - 1.0) / HEIGHT as f64)),
                    );
                    row[x] += march_ray(ray, &objects, &mut rng, MAX_BOUNCES);
                }
            }
            sender.send((y, row)).unwrap();
        });
    }

    let mut image = image::RgbImage::new(WIDTH as _, HEIGHT as _);
    let mut row_count = 0usize;
    let mut rows = image
        .enumerate_rows_mut()
        .map(|(_, row)| Some(row))
        .collect::<Vec<_>>();
    for (y, pixels) in receiver.iter().take(HEIGHT) {
        print!("\r{:.3}%", (row_count as f64 / HEIGHT as f64) * 100.0);
        std::io::stdout().flush().unwrap();
        for (x, (_, _, pixel)) in rows[y].take().unwrap().enumerate() {
            *pixel = Rgb([
                ((pixels[x].x / SAMPLES as f64).sqrt() * 255.0)
                    .clamp(0.0, 255.0)
                    .round() as u8,
                ((pixels[x].y / SAMPLES as f64).sqrt() * 255.0)
                    .clamp(0.0, 255.0)
                    .round() as u8,
                ((pixels[x].z / SAMPLES as f64).sqrt() * 255.0)
                    .clamp(0.0, 255.0)
                    .round() as u8,
            ]);
        }
        row_count += 1;
    }
    println!("\rDone.        ");

    const FILEPATH: &'static str = "output.png";
    image
        .save_with_format(FILEPATH, image::ImageFormat::Png)
        .unwrap();
    println!("Saved {FILEPATH}");
}

fn get_object<T, C>(
    point: Vector3<T>,
    objects: &[Box<dyn SDF<T, C> + Send + Sync>],
) -> Option<(T, Material<T, C>)>
where
    T: Real,
{
    objects
        .iter()
        .map(|object| object.get_sdf(point.clone()))
        .min_by(|(a_dist, _), (b_dist, _)| {
            a_dist
                .abs()
                .partial_cmp(&b_dist.abs())
                .unwrap_or(std::cmp::Ordering::Equal)
        })
}

pub fn march_ray(
    mut ray: Ray<f64>,
    objects: &[Box<dyn SDF<f64, f64> + Send + Sync>],
    rng: &mut impl rand::Rng,
    depth: usize,
) -> Vector3<f64> {
    const MIN_DISTANCE: f64 = 0.001;
    const MAX_DISTANCE: f64 = 10000.0;
    if depth == 0 {
        return Vector3::zero();
    }
    loop {
        match get_object(ray.origin, objects) {
            Some((distance, material)) if distance <= MAX_DISTANCE => {
                ray.origin += ray.direction * distance.into();
                if distance < MIN_DISTANCE {
                    let normal = -ray.direction;
                    return march_ray(
                        Ray {
                            origin: ray.origin + normal * MIN_DISTANCE.into() * 2.0.into(),
                            direction: rand_in_hemisphere(normal, rng)
                                .lerp(normal, material.smoothness)
                                .normalized(),
                        },
                        objects,
                        rng,
                        depth - 1,
                    ) * material.diffuse_color
                        + material.emissive_color;
                }
            }
            _ => {
                return Vector3::one().lerp(
                    Vector3 {
                        x: 0.4,
                        y: 0.6,
                        z: 0.8,
                    },
                    ray.direction.y * 0.5 + 0.5,
                );
            }
        }
    }
}
