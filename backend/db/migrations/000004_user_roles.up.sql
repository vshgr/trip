ALTER TABLE users
ADD COLUMN role TEXT NOT NULL DEFAULT 'user';

ALTER TABLE users
ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'user'));

UPDATE users
SET role = 'admin'
WHERE id = '11111111-1111-1111-1111-111111111111';
