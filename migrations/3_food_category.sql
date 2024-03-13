create table food_category
(
    food_category_id serial primary key not null,
    name varchar(255) not null,
    created_at timestamp not null default now(),
    updated_at timestamp
);

select trigger_updated_at('food_category');
