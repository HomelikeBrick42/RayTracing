use num::traits::real::Real;

use crate::{Material, Vector3, SDF};

pub struct And<T, C> {
    pub a: Box<dyn SDF<T, C> + Send + Sync>,
    pub b: Box<dyn SDF<T, C> + Send + Sync>,
}

impl<T, C> SDF<T, C> for And<T, C>
where
    T: Real,
{
    fn get_sdf(&self, point: Vector3<T>) -> (T, Material<T, C>) {
        let a = self.a.get_sdf(point);
        let b = self.b.get_sdf(point);
        (a.0.max(b.0), a.1)
    }
}
