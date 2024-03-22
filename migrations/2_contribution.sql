create table contribution
(
    contribution_id integer primary key,
    event_id text not null,
    guest_name text not null,
    food_name text not null,
    created_at timestamp default (strftime('%y-%m-%d %h:%m:%s', 'now')),
    updated_at timestamp,
    foreign key (event_id) references event (event_id) on delete cascade
);
