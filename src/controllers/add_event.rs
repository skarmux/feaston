use crate::error::Result;
use crate::models;
// use anyhow::Context;
use axum::{Extension, Json};
use sqlx::SqlitePool;
use uuid::Uuid;

pub async fn create_event(name: &str, date: &str, pool: &SqlitePool) -> Result<Uuid> {
    let uuid = Uuid::new_v4();

    sqlx::query!(
        r#"insert into event (event_id, name, date) values (?, ?, ?)"#,
        uuid,
        name,
        date
    )
    .execute(pool)
    .await?;
    // .context("could not insert new event into database")?;

    Ok(uuid)
}

pub async fn add_event_handler(
    Extension(pool): Extension<SqlitePool>,
    Json(event): Json<models::event::FromForm>,
) -> Result<String> {
    let event_uuid = create_event(&event.name, &event.date, &pool).await?;

    Ok(event_uuid.into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ::axum::routing::post;
    use axum::{body::Body, http::Request};
    use http_body_util::BodyExt;
    use tower::util::ServiceExt; // for `collect`

    #[tokio::test]
    async fn add_event() {
        let pool = crate::tests::create_connection_pool().await;

        let app = axum::routing::Router::new()
            .route("/event", post(add_event_handler))
            .layer(Extension(pool));

        let request = Request::builder()
            .method(axum::http::Method::POST)
            .uri("/event")
            .header("content-type", "application/json")
            .body(Body::from(
                r#"{
                    "name": "Test Event",
                    "date": "2024-06-17T13:46:35Z"
                }"#,
            ))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), axum::http::StatusCode::OK);

        let body = response.into_body().collect().await.unwrap().to_bytes();
        dbg!(String::from_utf8_lossy(&body[..]));
        assert!(Uuid::try_parse_ascii(&body[..]).is_ok());
    }
}
