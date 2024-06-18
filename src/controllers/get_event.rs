use crate::error::Result;
use crate::models;
use anyhow::Context;
use axum::{extract::Path, Extension, Json};
use sqlx::SqlitePool;
use uuid::Uuid;

pub async fn get_event_handler(
    Extension(pool): Extension<SqlitePool>,
    Path(event_id): Path<Uuid>,
) -> Result<Json<models::event::Event>> {
    let mut event: models::event::Event = sqlx::query_as!(
        models::event::FromQuery,
        r#"select event_id as "event_id: uuid::Uuid", name, date from event where event_id = ?;"#,
        event_id
    )
    .map(models::event::FromQuery::into_event)
    .fetch_one(&pool)
    .await
    // .context("database error")
    .map_err(|e| match e {
        sqlx::Error::RowNotFound => crate::error::Error::NotFound,
        e => crate::error::Error::Sqlx(e),
    })?;

    event.contributions = sqlx::query_as!(
        models::contribution::FromQuery,
        r#"select contribution_id, event_id as "event_id: uuid::Uuid", name, guest from contribution where event_id = ? order by created_at;"#,
        event_id
    )
    .map(models::contribution::FromQuery::into_contribution)
    .fetch_all(&pool)
    .await
    .context("database error while fetching guests for event")?;

    // tracing::debug!("{:?}", &event.date);

    Ok(Json(event))
}

#[cfg(test)]
mod tests {
    use super::*;
    use ::axum::routing::get;
    use axum::{body::Body, http::Request};
    use tower::util::ServiceExt;

    #[tokio::test]
    async fn get_event_not_found() {
        let pool = crate::tests::create_connection_pool().await;

        let app = axum::routing::Router::new()
            .route("/event/:id", get(get_event_handler))
            .layer(Extension(pool));

        let request = Request::builder()
            .method(axum::http::Method::GET)
            .uri("/event/3a11487e-ec69-4f12-b091-5991eca26f2a")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), axum::http::StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn get_event_bad_request() {
        let pool = crate::tests::create_connection_pool().await;

        let app = axum::routing::Router::new()
            .route("/event/:id", get(get_event_handler))
            .layer(Extension(pool));

        let request = Request::builder()
            .method(axum::http::Method::GET)
            .uri("/event/12345")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), axum::http::StatusCode::BAD_REQUEST);
    }
}
