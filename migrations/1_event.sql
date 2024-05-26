create table event
(
    event_id text primary key not null,
    name text not null,
    date datetime not null,
    created_at timestamp default (strftime('%y-%m-%d %h:%m:%s', 'now')),
    updated_at timestamp
);
