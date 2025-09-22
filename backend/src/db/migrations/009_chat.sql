-- 009_chat.sql: conversations and chat tables (string IDs)

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  user_a_id VARCHAR(12) NOT NULL,
  user_b_id VARCHAR(12) NOT NULL,
  last_message_type ENUM('text','image','video','voice','file') NULL,
  last_message_text TEXT NULL,
  last_message_at TIMESTAMP NULL,
  user_a_last_read_at TIMESTAMP NULL,
  user_b_last_read_at TIMESTAMP NULL,
  user_a_muted TINYINT(1) NOT NULL DEFAULT 0,
  user_b_muted TINYINT(1) NOT NULL DEFAULT 0,
  user_a_deleted TINYINT(1) NOT NULL DEFAULT 0,
  user_b_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT conversations_fk_user_a FOREIGN KEY (user_a_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT conversations_fk_user_b FOREIGN KEY (user_b_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE KEY conversations_unique_pair (user_a_id, user_b_id),
  KEY conversations_user_a (user_a_id),
  KEY conversations_user_b (user_b_id),
  KEY conversations_last_message_at (last_message_at)
);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  conversation_id VARCHAR(12) NOT NULL,
  sender_id VARCHAR(12) NOT NULL,
  receiver_id VARCHAR(12) NOT NULL,
  type ENUM('text','image','video','voice','file') NOT NULL,
  text TEXT NULL,
  reply_to_message_id VARCHAR(12) NULL,
  read_at TIMESTAMP NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chat_messages_fk_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chat_messages_fk_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chat_messages_fk_receiver FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chat_messages_fk_reply FOREIGN KEY (reply_to_message_id) REFERENCES chat_messages (id) ON DELETE SET NULL ON UPDATE NO ACTION,
  KEY chat_messages_conversation (conversation_id),
  KEY chat_messages_sender (sender_id),
  KEY chat_messages_receiver (receiver_id),
  KEY chat_messages_reply_to (reply_to_message_id),
  KEY chat_messages_created_at (created_at)
);

-- Chat attachments table
CREATE TABLE IF NOT EXISTS chat_attachments (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  message_id VARCHAR(12) NOT NULL,
  type ENUM('image','video','voice','document') NOT NULL,
  url TEXT NOT NULL,
  thumbnail TEXT NULL,
  durationSec INT NULL,
  fileSize INT NULL,
  fileName VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chat_attachments_fk_message FOREIGN KEY (message_id) REFERENCES chat_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY chat_attachments_message (message_id)
);

-- Chat reactions table
CREATE TABLE IF NOT EXISTS chat_reactions (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  message_id VARCHAR(12) NOT NULL,
  user_id VARCHAR(12) NOT NULL,
  emoji VARCHAR(16) NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chat_reactions_fk_message FOREIGN KEY (message_id) REFERENCES chat_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chat_reactions_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE KEY chat_reactions_unique (message_id, user_id),
  KEY chat_reactions_user (user_id)
);
