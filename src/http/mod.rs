use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use clap::Parser;
use crate::config::Config;
use anyhow::Context;
use askama::Template;
use axum::{Router, response::IntoResponse, routing::get};
use sqlx::SqlitePool;

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
    db: SqlitePool,
}

pub async fn serve(/*config: Config,*/ db: SqlitePool) -> anyhow::Result<()> {
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

    let config = Config::parse();

    let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), config.port);

    let listener = tokio::net::TcpListener::bind(socket)
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
