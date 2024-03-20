create table contribution
(
    contribution_id integer primary key autoincrement not null,
    event_id text not null,
    guest_name text not null,
    food_name text not null,
    food_category_id integer,
    created_at timestamp default (strftime('%y-%m-%d %h:%m:%s', 'now')) not null,
    updated_at timestamp,
    foreign key (event_id) references event (event_id) on delete cascade,
    foreign key (food_category_id) references food_category (food_category_id) on delete set null
);
