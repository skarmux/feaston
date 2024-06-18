use crate::config::Config;
use anyhow::Context;
use axum::{
    routing::{delete, get, post},
    Router,
};
use clap::Parser;
use sqlx::SqlitePool;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};

#[cfg(feature = "serve-static")]
use tower_http::services::ServeDir;

mod config;
mod controllers;
mod error;
mod models;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // env_logger::init();

    let config = Config::parse();

    let pool = SqlitePool::connect(&config.database_url)
        .await
        .context("could not connect to database")?;

    sqlx::migrate!().run(&pool).await?;

    let app = Router::new()
        .route("/event/:id", get(controllers::get_event::get_event_handler))
        .route(
            "/event/:id/contribution",
            post(controllers::edit_event::add_contribution_handler),
        )
        .route(
            "/event/:event_id/contribution/:contribution_id",
            delete(controllers::edit_event::delete_contribution_handler),
        )
        .route("/event", post(controllers::add_event::add_event_handler))
        .layer(axum::Extension(pool));

    #[cfg(feature = "serve-static")]
    let app = Router::new()
        .nest_service("/", ServeDir::new("www"))
        .nest_service("/api", app);

    let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), config.port);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    axum::serve(listener, app.into_make_service())
        .await
        .context("error running http server")
}

#[cfg(test)]
mod tests {
    use super::*;

    pub async fn create_connection_pool() -> SqlitePool {
        // let durl = std::env::var("DATABASE_URL").expect("set DATABASE_URL env variable");

        // let config = Config::parse();

        let pool = SqlitePool::connect("./db.sqlite")
            .await
            .context("could not connect to database")
            .unwrap();

        let _ = sqlx::migrate!().run(&pool).await;

        pool
    }
}
