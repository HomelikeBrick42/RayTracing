use num::traits::real::Real;

use crate::{Material, Vector3, SDF};

pub struct Cutout<T, C> {
    pub object: Box<dyn SDF<T, C> + Send + Sync>,
    pub cutout: Box<dyn SDF<T, C> + Send + Sync>,
}

impl<T, C> SDF<T, C> for Cutout<T, C>
where
    T: Real,
{
    fn get_sdf(&self, point: Vector3<T>) -> (T, Material<T, C>) {
        let object = self.object.get_sdf(point);
        let cutout = self.cutout.get_sdf(point);
        (object.0.max(-cutout.0), object.1)
    }
}
