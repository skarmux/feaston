use crate::config::Config;
use anyhow::Context;
use axum::Router;
use clap::Parser;
use sqlx::SqlitePool;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};

/// Define common error type.
mod error;

/// Modules introducing API routes.
mod events;

pub use error::{Error, ResultExt};

pub type Result<T, E = Error> = std::result::Result<T, E>;

use tower::ServiceBuilder;
use tower_http::{add_extension::AddExtensionLayer, trace::TraceLayer};

#[derive(Clone)]
struct ApiContext {
    db: SqlitePool,
}

pub async fn serve(/*config: Config,*/ db: SqlitePool) -> anyhow::Result<()> {
    let app = api_router().layer(
        ServiceBuilder::new()
            .layer(AddExtensionLayer::new(ApiContext { db }))
            .layer(TraceLayer::new_for_http()),
    );

    let config = Config::parse();

    let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), config.port);

    let listener = tokio::net::TcpListener::bind(socket).await.unwrap();

    axum::serve(listener, app.into_make_service())
        .await
        .context("error running HTTP server")
}

fn api_router() -> Router {
    // This is the order that the modules were authored in.
    Router::new().merge(events::router())
}
