use crate::{Material, Vector3};

pub trait SDF<T, C> {
    fn get_sdf(&self, point: Vector3<T>) -> (T, Material<T, C>);
}
