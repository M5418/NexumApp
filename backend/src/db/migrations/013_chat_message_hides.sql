-- 013_chat_message_hides.sql: per-user "delete for me" visibility
CREATE TABLE IF NOT EXISTS chat_message_hides (
  message_id VARCHAR(12) NOT NULL,
  user_id VARCHAR(12) NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (message_id, user_id),
  CONSTRAINT chat_message_hides_fk_message FOREIGN KEY (message_id) REFERENCES chat_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chat_message_hides_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY chat_message_hides_user (user_id)
);