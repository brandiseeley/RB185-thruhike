DROP TABLE IF EXISTS points;
DROP TABLE IF EXISTS hikes;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE hikes (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_mileage numeric NOT NULL DEFAULT 0.0,
  finish_mileage numeric NOT NULL,
  name text NOT NULL,
  completed boolean NOT NULL
);

CREATE TABLE points (
  id serial PRIMARY KEY,
  hike_id integer NOT NULL REFERENCES hikes(id) ON DELETE CASCADE,
  mileage numeric NOT NULL,
  date date NOT NULL DEFAULT NOW()
);
