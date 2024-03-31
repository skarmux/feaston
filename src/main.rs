use anyhow::Context;
use clap::Parser;
use sqlx::{SqlitePool, migrate::Migrator};

use feaston::config::Config;
use feaston::http;

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv::dotenv().ok();

    env_logger::init();

    let config = Config::parse();

    let db = SqlitePool::connect(&config.database_url)
        .await
        .context("could not connect to database")?;

    MIGRATOR
        .run(&mut conn)
        .await
        .expect("failed to run migrations");

    http::serve(/*config,*/ db).await?;

    Ok(())
}
