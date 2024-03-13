create table contribution
(
    contribution_id serial primary key not null,
    event_id uuid not null references event (event_id) on delete cascade,
    guest_name varchar(255) not null,
    food_name varchar(255) not null,
    food_category_id int references food_category (food_category_id) on delete set null,
    created_at timestamp not null default now(),
    updated_at timestamp
);

select trigger_updated_at('contribution');
