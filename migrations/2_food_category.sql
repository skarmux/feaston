create table food_category
(
    food_category_id integer primary key autoincrement not null,
    name text not null,
    created_at timestamp default (strftime('%y-%m-%d %h:%m:%s', 'now')) not null,
    updated_at timestamp
);

