use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Deserialize, Serialize)]
pub struct Contribution {
    pub id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

#[derive(Debug, Deserialize)]
pub struct FromForm {
    pub name: String,
    pub guest: String,
}

#[derive(Debug)]
pub struct FromQuery {
    pub contribution_id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

impl FromQuery {
    pub fn into_contribution(self) -> Contribution {
        Contribution {
            id: self.contribution_id,
            event_id: self.event_id,
            name: self.name,
            guest: self.guest,
        }
    }
}
