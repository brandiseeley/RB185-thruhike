DROP TABLE IF EXISTS goals;
DROP TABLE IF EXISTS points;
DROP TABLE IF EXISTS hikes;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id serial PRIMARY KEY,
  name text NOT NULL CHECK(LENGTH(name) BETWEEN 1 AND 50),
  user_name text UNIQUE NOT NULL CHECK(LENGTH(user_name) BETWEEN 8 AND 50)
);

CREATE TABLE hikes (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_mileage numeric NOT NULL DEFAULT 0.0 CHECK(start_mileage >= 0.0),
  finish_mileage numeric NOT NULL CHECK(finish_mileage < 100000),
  name text NOT NULL CHECK(LENGTH(name) BETWEEN 1 AND 100)
);

CREATE TABLE points (
  id serial PRIMARY KEY,
  hike_id integer NOT NULL REFERENCES hikes(id) ON DELETE CASCADE,
  mileage numeric NOT NULL CHECK(mileage >= 0.0),
  date date NOT NULL DEFAULT NOW()
);

CREATE TABLE goals (
  id serial PRIMARY KEY,
  hike_id integer NOT NULL REFERENCES hikes(id) ON DELETE CASCADE,
  mileage numeric NOT NULL CHECK(mileage > 0),
  description varchar(150) NOT NULL,
  date date NOT NULL
);
