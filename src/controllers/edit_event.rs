use crate::error::Result;
use crate::models;
// use anyhow::Context;
use axum::{extract::Path, http::StatusCode, Extension, Json};
use sqlx::SqlitePool;
use uuid::Uuid;

async fn create_contribution(
    event_id: &Uuid,
    name: &String,
    guest: &String,
    pool: &SqlitePool,
) -> Result<i64> {
    let contribution_id: i64 = sqlx::query!(
        r#"insert into contribution (event_id, name, guest) VALUES (?,?,?)"#,
        event_id,
        name,
        guest,
    )
    .execute(pool)
    .await?
    // .context("could not add new contribution")?
    .last_insert_rowid();

    Ok(contribution_id)
}

pub async fn add_contribution_handler(
    Extension(pool): Extension<SqlitePool>,
    Path(event_id): Path<Uuid>,
    Json(contribution): Json<models::contribution::FromForm>,
) -> Result<String> {
    let contribution_id =
        create_contribution(&event_id, &contribution.name, &contribution.guest, &pool).await?;

    Ok(contribution_id.to_string())
}

pub async fn delete_contribution_handler(
    Extension(pool): Extension<SqlitePool>,
    Path((event_id, contribution_id)): Path<(Uuid, i64)>,
) -> Result<StatusCode> {
    sqlx::query!(
        r#"delete from contribution where contribution_id = ? and event_id = ?"#,
        contribution_id,
        event_id
    )
    .execute(&pool)
    .await?;
    // .context("could not deletet contribution")?;

    Ok(StatusCode::OK)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ::axum::routing::post;
    use axum::{body::Body, http::Request};
    use tower::util::ServiceExt; // for `collect`

    #[tokio::test]
    async fn add_contribution() {
        let pool = crate::tests::create_connection_pool().await;

        // TODO: illegal input - only use validated instances of event for database queries...
        let event_uuid = crate::controllers::add_event::create_event("", "", &pool)
            .await
            .unwrap();

        let app = axum::routing::Router::new()
            .route("/event/:id/contribution", post(add_contribution_handler))
            .layer(Extension(pool));

        let request = Request::builder()
            .method(axum::http::Method::POST)
            .uri(format!("/event/{}/contribution", event_uuid))
            .header("content-type", "application/json")
            .body(Body::from(
                r#"{
                    "name": "Beer",
                    "guest": "John Doe"
                }"#,
            ))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();

        assert_eq!(response.status(), axum::http::StatusCode::OK);
    }
}
