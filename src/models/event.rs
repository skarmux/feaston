use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::models::contribution::Contribution;

#[derive(Serialize)]
pub struct Event {
    pub id: Uuid,
    pub name: String,
    #[serde(with = "time::serde::rfc3339")]
    pub date: OffsetDateTime,
    pub contributions: Vec<Contribution>,
}

#[derive(Deserialize, Debug)]
#[cfg_attr(feature = "test", derive(Serialize))]
pub struct FromForm {
    pub name: String,
    pub date: String,
}

#[derive(FromRow, Debug)]
pub struct FromQuery {
    pub event_id: Uuid,
    pub name: String,
    pub date: OffsetDateTime,
}

impl FromQuery {
    pub fn into_event(self) -> Event {
        Event {
            id: self.event_id,
            name: self.name,
            date: self.date,
            contributions: vec![],
        }
    }
}
