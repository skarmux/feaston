use clap::Parser;

/// The configuration parameters for the application
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Config {
    /// The connection URL for the database this application should use.
    #[arg(long, env)]
    pub database_url: String,
    // /// The HMAC signing and verification key used for login tokens (JWTs).
    // #[arg(long)]
    // pub hmac_key: String,
}
