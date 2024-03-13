create table event
(
	event_id uuid primary key default uuid_generate_v1mc(),
	name varchar(255) not null,
	date date,
	created_at timestamp not null default now(),
	updated_at timestamp
);

select trigger_updated_at('event');
