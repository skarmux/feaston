use anyhow::Context;
use clap::Parser;
use sqlx::SqlitePool;

use feaston::config::Config;
use feaston::http;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv::dotenv().ok();

    env_logger::init();

    let config = Config::parse();

    let db = SqlitePool::connect(&config.database_url)
        .await
        .context("could not connect to database")?;

    sqlx::migrate!().run(&db).await?;

    http::serve(db).await?;

    Ok(())
}
