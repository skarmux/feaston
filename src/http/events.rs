use anyhow::Context;
use axum::{
    extract::Path, http::StatusCode, routing::{get, post, delete}, Extension, Json, Router
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::http::{ApiContext, Result};

pub fn router() -> Router {
    Router::new()
        .route("/event/:id", get(get_event))
        .route("/event/:id/contribution", post(create_contribution))
        .route("/event/:event_id/contribution/:contribution_id", delete(delete_contribution))
        .route("/event", post(create_event))
}

#[derive(Deserialize, Debug)]
struct CreateEvent {
    name: String,
    date: String,
}

#[derive(serde::Deserialize, serde::Serialize)]
pub struct Contribution {
    pub id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

#[derive(Debug)]
pub struct ContributionFromQuery {
    pub contribution_id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

impl ContributionFromQuery {
    pub fn into_contribution(self) -> Contribution {
        Contribution {
            id: self.contribution_id,
            event_id: self.event_id,
            name: self.name,
            guest: self.guest,
        }
    }
}

#[derive(Serialize)]
pub struct Event {
    pub id: Uuid,
    pub name: String,
    #[serde(with = "time::serde::rfc3339")]
    pub date: OffsetDateTime,
    pub contributions: Vec<Contribution>,
}

#[derive(FromRow, Debug)]
struct EventFromQuery {
    event_id: Uuid,
    name: String,
    date: OffsetDateTime,
}

impl EventFromQuery {
    fn into_event(self) -> Event {
        Event {
            id: self.event_id,
            name: self.name,
            date: self.date,
            contributions: vec![],
        }
    }
}

async fn get_event(ctx: Extension<ApiContext>, Path(event_id): Path<Uuid>) -> Result<Json<Event>> {
    let mut event: Event = sqlx::query_as!(
        EventFromQuery,
        r#"select event_id as "event_id: uuid::Uuid", name, date from event where event_id = ?;"#,
        event_id
    )
    .map(EventFromQuery::into_event)
    .fetch_one(&ctx.db)
    .await
    .context("database error")?;

    event.contributions = sqlx::query_as!(
        ContributionFromQuery,
        r#"select contribution_id, event_id as "event_id: uuid::Uuid", name, guest from contribution where event_id = ? order by created_at;"#,
        event_id
    )
    .map(ContributionFromQuery::into_contribution)
    .fetch_all(&ctx.db)
    .await
    .context("database error while fetching guests for event")?;

    tracing::debug!("{:?}", &event.date);

    Ok(Json(event))
}

async fn create_event(
    ctx: Extension<ApiContext>,
    Json(event): Json<CreateEvent>,
) -> Result<String> {
    let uuid = Uuid::new_v4();
    sqlx::query!(
        r#"insert into event (event_id, name, date) values (?, ?, ?)"#,
        uuid,
        event.name,
        event.date
    )
    .execute(&ctx.db)
    .await
    .context("could not insert new event into database")?;

    Ok(uuid.into())
}

#[derive(serde::Deserialize)]
struct CreateContribution {
    name: String,
    guest: String,
}

async fn create_contribution(
    ctx: Extension<ApiContext>,
    Path(event_id): Path<Uuid>,
    Json(contribution): Json<CreateContribution>,
) -> Result<String> {
    let contribution_id: i64 = sqlx::query!(
        r#"insert into contribution (event_id, name, guest) VALUES (?,?,?)"#,
        event_id,
        contribution.name,
        contribution.guest,
    )
    .execute(&ctx.db)
    .await
    .context("could not add new contribution")?
    .last_insert_rowid();

    Ok(contribution_id.to_string())
}

async fn delete_contribution(
    ctx: Extension<ApiContext>,
    Path((event_id, contribution_id)): Path<(Uuid, i64)>,
) -> Result<StatusCode> {
    sqlx::query!(
        r#"delete from contribution where contribution_id = ? and event_id = ?"#,
        contribution_id,
        event_id
    )
    .execute(&ctx.db)
    .await
    .context("could not deletet contribution")?;

    Ok(StatusCode::OK)
}
