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
use time::{Date, format_description};
use uuid::Uuid;
use serde::Deserialize;

use crate::http::{ApiContext, Result, types::HtmlTemplate};

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
struct EventPartTemp {
    event_id: Uuid,
    name: String,
    date: String,
}

#[derive(Template)]
#[template(path = "base.html")]
struct EventBaseTemp {
    content: EventPartTemp
}

#[derive(Template)]
#[template(path = "event/form/new.html")]
struct NewEventFormTemplate {}

pub struct Event {
    pub id: Uuid,
    pub name: String,
    pub date: Date,
}

#[derive(Debug)]
struct EventFromQuery {
    event_id: String,
    name: String,
    date: Date,
}

impl EventFromQuery {
    fn into_event(self) -> Event {
        Event {
            id: Uuid::try_parse(self.event_id.as_str()).unwrap(),
            name: self.name,
            date: self.date,
        }
    }
}

async fn get_event(
    ctx: Extension<ApiContext>,
    HxBoosted(partial): HxBoosted,
    Path(event_id): Path<Uuid>
) -> Result<impl IntoResponse> {
    let event = sqlx::query_as!(
        EventFromQuery,
        "select event_id, name, date from event where event_id = ?",
        event_id
    )
    .map(EventFromQuery::into_event)
    .fetch_one(&ctx.db)
    .await
    .context("database error")?;

    tracing::debug!("{:?}", &event.date);

    if partial {        
        Ok(HtmlTemplate(EventPartTemp { event_id: event.id, name: event.name, date: event.date.format(&format_description::parse("[weekday], [day].[month].[year]").unwrap()).unwrap() }).into_response())
    } else {
        Ok(HtmlTemplate(EventBaseTemp { content: EventPartTemp { event_id: event.id, name: event.name, date: event.date.format(&format_description::parse("[weekday], [day].[month].[year]").unwrap()).unwrap() }}).into_response()) 
    }
}

#[derive(Template)]
#[template(path = "base.html")]
struct NewEventFormBaseTemp {
    content: NewEventFormTemplate,
}

async fn index( ) -> Result<impl IntoResponse> {
    Ok(HtmlTemplate(NewEventFormBaseTemp { content: NewEventFormTemplate {} }).into_response())
}

async fn create_event(
    ctx: Extension<ApiContext>,
    Form(event): Form<CreateEvent>,
) -> Result<impl IntoResponse> {
    let event_id = sqlx::query_scalar!(
        r#"insert into event (name, date) values ($1, $2) returning event_id"#,
        event.name,
        event.date
    )
    .fetch_one(&ctx.db)
    .await
    .context("could not insert new event into database")?;

    Ok((
        // HxPushUrl(format!("/event/{event_id}").parse::<Uri>().unwrap()),
        HxRedirect(format!("/event/{event_id}").parse::<Uri>().unwrap()),
        ""
        // HtmlTemplate(EventPartTemp { event_id, name: event.name, date: event.date.map(|d| d.format(&format_description::parse("[day].[month].[year]").unwrap()).unwrap()), guests: vec![]})
    ).into_response())
}
