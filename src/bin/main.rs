use std::{io::Write, sync::Arc};

use image::Rgb;
use num::Zero;

use rand::Rng;
use raytracer::*;
use threadpool::ThreadPool;

fn get_nearest_hit<T, C>(
    ray: &Ray<T>,
    objects: &[Box<dyn Intersectable<T, C> + Send + Sync>],
) -> Option<RayHit<T, C>>
where
    T: PartialOrd + Zero,
{
    objects
        .iter()
        .map(|object| object.intersect(ray))
        .flatten()
        .filter(|hit| hit.distance > T::zero())
        .min_by(|a, b| {
            a.distance
                .partial_cmp(&b.distance)
                .unwrap_or(std::cmp::Ordering::Equal)
        })
}

fn rand_in_hemisphere(normal: Vector3<f64>, rng: &mut impl rand::Rng) -> Vector3<f64> {
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

fn trace_ray(
    ray: Ray<f64>,
    objects: &[Box<dyn Intersectable<f64, f64> + Send + Sync>],
    rng: &mut impl rand::Rng,
    depth: usize,
) -> Vector3<f64> {
    if depth == 0 {
        return Vector3::zero();
    }
    if let Some(hit) = get_nearest_hit(&ray, objects) {
        trace_ray(
            Ray {
                origin: hit.position,
                direction: rand_in_hemisphere(hit.normal, rng)
                    .lerp(hit.normal, hit.material.smoothness)
                    .normalized(),
            },
            objects,
            rng,
            depth - 1,
        ) * hit.material.diffuse_color
            + hit.material.emissive_color
    } else {
        Vector3::one().lerp(
            Vector3 {
                x: 0.4,
                y: 0.6,
                z: 0.8,
            },
            ray.direction.y * 0.5 + 0.5,
        )
    }
}

fn main() {
    const WIDTH: usize = 1080;
    const HEIGHT: usize = 720;
    const SAMPLES: usize = 512;
    const MAX_BOUNCES: usize = 128;
    const THREAD_COUNT: usize = 8;

    let objects: Arc<[Box<dyn Intersectable<_, _> + Send + Sync>]> = Arc::new([
        Box::new(Sphere {
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
                        (x as f64 / WIDTH as f64) * 2.0 - 1.0
                            + ((rng.gen::<f64>() * 2.0 - 1.0) / WIDTH as f64),
                        -((y as f64 / HEIGHT as f64) * 2.0 - 1.0
                            + ((rng.gen::<f64>() * 2.0 - 1.0) / HEIGHT as f64)),
                    );
                    row[x] += trace_ray(ray, &*objects, &mut rng, MAX_BOUNCES);
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
