-- View: v_user_connections
-- Normalizes connections so each row represents a user and their other user
DROP VIEW IF EXISTS v_user_connections;
CREATE VIEW v_user_connections AS
SELECT
  from_user_id AS user_id,
  to_user_id   AS other_user_id,
  'outbound'   AS direction,
  created_at
FROM connections
UNION ALL
SELECT
  to_user_id   AS user_id,
  from_user_id AS other_user_id,
  'inbound'    AS direction,
  created_at
FROM connections;

-- Optional detailed view including other user's basic profile fields
DROP VIEW IF EXISTS v_user_connections_detailed;
CREATE VIEW v_user_connections_detailed AS
SELECT
  v.user_id,
  v.other_user_id,
  v.direction,
  v.created_at,
  p_other.username AS other_username,
  p_other.first_name AS other_first_name,
  p_other.last_name AS other_last_name
FROM v_user_connections v
LEFT JOIN profiles p_other ON p_other.user_id = v.other_user_id;
