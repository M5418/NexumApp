CREATE TABLE IF NOT EXISTS connections (
  from_user_id BIGINT NOT NULL,
  to_user_id BIGINT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (from_user_id, to_user_id),
  FOREIGN KEY (from_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (to_user_id) REFERENCES users(id) ON DELETE CASCADE
);
