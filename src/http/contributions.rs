use crate::http::{ApiContext, Result, HtmlTemplate};
use anyhow::Context;
use askama::Template;
use axum::{
    routing::post,
    Router, Extension, response::IntoResponse, extract::{Query, Path}, Form,
};
use uuid::Uuid;

pub fn router() -> Router {
    Router::new()
        //.route("/contributions", post(create_contribution))
}

#[derive(serde::Deserialize)]
struct CreateContribution {
    event_id: Uuid,
    name: String,
    food: String,
}

#[derive(serde::Deserialize, serde::Serialize)]
pub struct Contribution {
    pub id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

#[derive(Debug)]
pub struct ContributionFromQuery {
    pub contribution_id: i64,
    pub event_id: Uuid,
    pub name: String,
    pub guest: String,
}

impl ContributionFromQuery {
    pub fn into_contribution(self) -> Contribution {
        Contribution {
            id: self.contribution_id,
            event_id: self.event_id,
            name: self.name,
            guest: self.guest,
        }
    }
}

#[derive(serde::Deserialize)]
struct Params {
    event_id: String
}

// async fn create_contribution(
//     ctx: Extension<ApiContext>,
//     Form(contribution): Form<CreateContribution>,
// ) -> Result<impl IntoResponse> {
//     let contribution_id = sqlx::query!(
//         r#"insert into contribution (event_id, guest_name, food_name) VALUES (?,?,?) returning contribution_id"#,
//         contribution.event_id,
//         contribution.name,
//         contribution.food,
//     )
//     .fetch_one(&ctx.db)
//     .await
//     .context("could not add new contribution")?;

//     Ok(HtmlTemplate(ContributionTemplate { food_name: contribution.food, guest_name: contribution.name }))
// }
