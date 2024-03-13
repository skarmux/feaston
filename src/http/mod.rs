// use crate::config::Config;
// use std::sync::Arc;
use anyhow::Context;
use askama::Template;
use axum::{Router, response::IntoResponse, routing::get};
use sqlx::PgPool;

/// Define common error type.
mod error;

/// General purpose common type definitions.
mod types;
pub use types::HtmlTemplate;

/// Modules introducing API routes.
mod contributions;
mod events;

pub use error::{Error, ResultExt};

pub type Result<T, E = Error> = std::result::Result<T, E>;

use tower::ServiceBuilder;
use tower_http::{trace::TraceLayer, add_extension::AddExtensionLayer, services::ServeDir};

#[derive(Clone)]
struct ApiContext {
    // config: Arc<Config>,
    db: PgPool,
}

pub async fn serve(/*config: Config,*/ db: PgPool) -> anyhow::Result<()> {
    let assets_path = std::env::current_dir().unwrap();

    let app = api_router().layer(
        ServiceBuilder::new()
            .layer(AddExtensionLayer::new(ApiContext {
                // config: Arc::new(config),
                db,
            }))
            .layer(TraceLayer::new_for_http())
    ).nest_service("/assets", ServeDir::new(format!("{}/assets", assets_path.to_str().unwrap())))
    .nest_service("/favicon.ico", ServeDir::new(format!("{}/assets/favicon.ico", assets_path.to_str().unwrap())));

    let listener = tokio::net::TcpListener::bind("127.0.0.1:4040")
        .await
        .unwrap();

    axum::serve(listener, app.into_make_service())
        .await
        .context("error running HTTP server")
}

fn api_router() -> Router {
    // This is the order that the modules were authored in.
    Router::new()
        .route("/contact", get(contact))
        .route("/privacy", get(privacy))
        .merge(events::router())
        .merge(contributions::router())
}

#[derive(Template)]
#[template(path = "contact.html")]
struct Contact;

async fn contact() -> Result<impl IntoResponse> {
    Ok(HtmlTemplate(Contact {}))
}

#[derive(Template)]
#[template(path = "privacy.html")]
struct Privacy;

async fn privacy() -> Result<impl IntoResponse> {
    Ok(HtmlTemplate(Privacy {}))
}
