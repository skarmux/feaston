use anyhow::Context;
use askama::Template;
use axum::{
    Extension,
    Router,
    Form,
    routing::{get,post},
    extract::Path,
    response::IntoResponse, http::Uri
};
use axum_htmx::{HxBoosted, HxRedirect};
use sqlx::FromRow;
use time::{Date, format_description};
use uuid::Uuid;
use serde::Deserialize;

use crate::http::{contributions::ContributionFromQuery, types::HtmlTemplate, ApiContext, Result};

use super::contributions::Contribution;

pub fn router() -> Router {
    Router::new()
        .route("/", get(index))
        .route("/event/:id", get(get_event))
        .route("/events", post(create_event))
}

#[derive(Deserialize, Debug)]
struct CreateEvent {
    name: String,
    date: Date,
}

#[derive(Template)]
#[template(path = "event/event.html")]
struct EventTemp {
    // For linking new contributions
    event_id: Uuid,
    name: String,
    date: String,
    contributions: Vec<Contribution>,
}

#[derive(Template)]
#[template(path = "event/created.html")]
struct EventCreatedTemp {
    event_id: Uuid,
}

#[derive(Template)]
#[template(path = "event/form/new.html")]
struct NewEventFormTemplate {}

pub struct Event {
    pub id: Uuid,
    pub name: String,
    pub date: Date,
}

#[derive(FromRow, Debug)]
struct EventFromQuery {
    event_id: Uuid,
    name: String,
    date: Date,
}

impl EventFromQuery {
    fn into_event(self) -> Event {
        Event {
            id: self.event_id,
            name: self.name,
            date: self.date,
        }
    }
}

async fn index( ) -> Result<impl IntoResponse> {
    Ok(HtmlTemplate(NewEventFormTemplate {}).into_response())
}

async fn get_event(
    ctx: Extension<ApiContext>,
    Path(event_id): Path<Uuid>
) -> Result<impl IntoResponse> {
    let event: Event = sqlx::query_as!(
        EventFromQuery,
        r#"select event_id as "event_id: uuid::Uuid", name, date from event where event_id = ?;"#,
        event_id
    )
    .map(EventFromQuery::into_event)
    .fetch_one(&ctx.db)
    .await
    .context("database error")?;

    let contributions: Vec<Contribution> = sqlx::query_as!(
        ContributionFromQuery,
        r#"select contribution_id, event_id as "event_id: uuid::Uuid", guest_name, food_name from contribution where event_id = ?;"#,
        event_id
    )
    .map(ContributionFromQuery::into_contribution)
    .fetch_all(&ctx.db)
    .await
    .context("database error while fetching guests for event")?;

    tracing::debug!("{:?}", &event.date);

    Ok(HtmlTemplate(EventTemp { 
        event_id: event.id,
         name: event.name,
         date: event.date.format(&format_description::parse("[weekday], [day].[month].[year]").unwrap()).unwrap(),
         contributions 
    }).into_response()) 
}

async fn create_event(
    ctx: Extension<ApiContext>,
    Form(event): Form<CreateEvent>,
) -> Result<impl IntoResponse> {
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

    Ok(HtmlTemplate(EventCreatedTemp { event_id: uuid }).into_response())
}
