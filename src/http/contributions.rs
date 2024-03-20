use crate::http::{ApiContext, Result, HtmlTemplate};
use anyhow::Context;
use askama::Template;
use axum::{
    routing::get,
    Router, Extension, response::IntoResponse, extract::{Query, Path}, Form,
};
// use axum_htmx::HxResponseTrigger;
use uuid::Uuid;

pub fn router() -> Router {
    Router::new()
        .route("/contributions", get(get_contributions).post(create_contribution))
        .route("/contributions/:id", get(get_contribution))
        .route("/contributions/:id/edit", get(get_contribution_edit))
}

#[derive(Template,serde::Serialize)]
#[template(path = "contribution/list.html")]
struct ContributionsTableTemplate {
    contributions: Vec<Contribution>,
}

#[derive(serde::Deserialize)]
struct Createcontribution {
    event_id: Uuid,
    name: String,
    food: String,
}

#[derive(serde::Deserialize, serde::Serialize)]
pub struct Contribution {
    pub id: i64,
    pub event_id: Uuid,
    pub guest_name: String,
    pub food_name: String,
}

#[derive(Debug)]
pub struct ContributionFromQuery {
    pub contribution_id: i64,
    pub event_id: String,
    pub guest_name: String,
    pub food_name: String,
}

impl ContributionFromQuery {
    pub fn into_contribution(self) -> Contribution {
        Contribution {
            id: self.contribution_id,
            event_id: Uuid::try_parse(self.event_id.as_str()).unwrap(),
            guest_name: self.guest_name,
            food_name: self.food_name,
        }
    }
}

async fn get_contribution(ctx: Extension<ApiContext>, Path(contribution_id): Path<i32>) -> Result<impl IntoResponse> {
    let contribution = sqlx::query_as!(
        ContributionFromQuery,
        r#"SELECT contribution_id, event_id, guest_name, food_name 
FROM contribution 
WHERE contribution_id = ?;
"#,
        contribution_id
    ).map(ContributionFromQuery::into_contribution).fetch_one(&ctx.db).await.context("Failed to load contribution from database")?;

    Ok(HtmlTemplate(ContributionsTableTemplate { contributions: vec![contribution]}))
}

#[derive(serde::Deserialize)]
struct Params {
    event_id: String
}

async fn get_contributions(
    ctx: Extension<ApiContext>,
    params: Query<Params>
) -> Result<impl IntoResponse> {
    let contributions = sqlx::query_as!(
        ContributionFromQuery,
        r#"
            select
                contribution_id,
                event_id,
                guest_name,
                food_name
            from contribution
            where event_id = ?
            order by created_at
        "#,
        params.event_id
    )
    .map(|row| row.into_contribution())
    .fetch_all(&ctx.db)
    .await
    .unwrap();

    Ok(HtmlTemplate(ContributionsTableTemplate { contributions }))
}

async fn create_contribution(
    ctx: Extension<ApiContext>,
    Form(contribution): Form<Createcontribution>,
) -> Result<impl IntoResponse> {
    let _contribution_id = sqlx::query!(
        r#"insert into contribution (event_id, guest_name, food_name) VALUES (?,?,?) returning contribution_id"#,
        contribution.event_id,
        contribution.name,
        contribution.food,
    )
    .fetch_one(&ctx.db)
    .await
    .context("could not add new contribution")?;

    let contributions = sqlx::query_as!(
        ContributionFromQuery,
        r#"
            select
                contribution_id,
                event_id,
                guest_name,
                food_name
            from contribution
            where event_id = ?
            order by created_at
        "#,
        contribution.event_id
    )
    .map(|row| row.into_contribution())
    .fetch_all(&ctx.db)
    .await?;

    Ok(HtmlTemplate(ContributionsTableTemplate { contributions }))
}

#[derive(Template)]
#[template(path = "contribution/edit.html")]
struct ContributionEditTemplate {
    contribution: Contribution
}

async fn get_contribution_edit(
    ctx: Extension<ApiContext>,
    Path(contribution_id): Path<i32>
) -> Result<impl IntoResponse> {
    let contribution = sqlx::query_as!(
        ContributionFromQuery,
        r#"select contribution_id, event_id, guest_name, food_name from contribution where contribution_id = ?"#,
        contribution_id
    ).map(ContributionFromQuery::into_contribution).fetch_one(&ctx.db).await.context("Failed to load contribution from database")?;

    Ok(HtmlTemplate(ContributionEditTemplate { contribution }))
}
