use anyhow::Context;
use axum::{
    extract::Path,
    http::StatusCode,
    routing::{delete, get, post},
    Extension, Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use time::OffsetDateTime;
use uuid::Uuid;

use crate::http::{ApiContext, Result};

#[derive(serde::Deserialize)]
struct CreateContribution {
    name: String,
    guest: String,
}

async fn add_contribution(
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

#[cfg(test)]
mod test {

    use super::*;
    use axum::{
        body::Body,
        http::{self, Request, StatusCode},
    };
    // use http_body_util::BodyExt; // for `collect`
    use crate::config::Config;
    use clap::Parser;
    use serde_json::json;
    use sqlx::SqlitePool;
    use tower::ServiceBuilder;
    use tower::ServiceExt; // for `call`, `oneshot`, and `ready`
    use tower_http::{add_extension::AddExtensionLayer, trace::TraceLayer};

    #[derive(Clone)]
    struct ApiContext {
        pool: SqlitePool,
    }

    async fn create_connection_pool() -> SqlitePool {
        // let durl = std::env::var("DATABASE_URL").expect("set DATABASE_URL env variable");

        // let config = Config::parse();

        let pool = SqlitePool::connect("./db.sqlite")
            .await
            .context("could not connect to database")
            .unwrap();

        let _ = sqlx::migrate!().run(&pool).await;

        pool
    }

    #[tokio::test]
    async fn create_event() {
        let pool = create_connection_pool().await;

        let app = router().layer(
            ServiceBuilder::new()
                .layer(AddExtensionLayer::new(ApiContext { pool }))
                .layer(TraceLayer::new_for_http()),
        );

        let response = app
            .oneshot(
                Request::builder()
                    .method(http::Method::POST)
                    .uri("/event")
                    .header(http::header::CONTENT_TYPE, mime::APPLICATION_JSON.as_ref())
                    .body(Body::from(
                        r#"{ "name": "Test Event", "date": "2024-06-16T17:19:58Z" }"#,
                    ))
                    .context("could not build the test request")
                    .unwrap(),
            )
            .await
            .context("could not call api endpoint")
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);

        // let body = response.into_body().collect().await.unwrap().to_bytes();
        // let body: Value = serde_json::from_slice(&body).unwrap();
        // assert_eq!(body, json!({ "data": [1, 2, 3, 4] }));
    }
}
