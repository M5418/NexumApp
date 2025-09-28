-- 015_mentorship_chat.sql: Dedicated mentorship chat tables (separate from regular chat)

-- Mentorship conversations table
CREATE TABLE IF NOT EXISTS mentorship_conversations (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  mentor_user_id VARCHAR(12) NOT NULL,
  mentee_user_id VARCHAR(12) NOT NULL,
  last_message_type ENUM('text','image','video','voice','file') NULL,
  last_message_text TEXT NULL,
  last_message_at TIMESTAMP NULL,
  mentor_last_read_at TIMESTAMP NULL,
  mentee_last_read_at TIMESTAMP NULL,
  mentor_muted TINYINT(1) NOT NULL DEFAULT 0,
  mentee_muted TINYINT(1) NOT NULL DEFAULT 0,
  mentor_deleted TINYINT(1) NOT NULL DEFAULT 0,
  mentee_deleted TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_conv_fk_mentor FOREIGN KEY (mentor_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_conv_fk_mentee FOREIGN KEY (mentee_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE KEY mentorship_conv_unique_pair (mentor_user_id, mentee_user_id),
  KEY mentorship_conv_mentor (mentor_user_id),
  KEY mentorship_conv_mentee (mentee_user_id),
  KEY mentorship_conv_last_msg (last_message_at)
);

-- Mentorship messages table
CREATE TABLE IF NOT EXISTS mentorship_messages (
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
  CONSTRAINT mentorship_msg_fk_conv FOREIGN KEY (conversation_id) REFERENCES mentorship_conversations (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_msg_fk_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_msg_fk_receiver FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_msg_fk_reply FOREIGN KEY (reply_to_message_id) REFERENCES mentorship_messages (id) ON DELETE SET NULL ON UPDATE NO ACTION,
  KEY mentorship_msg_conv (conversation_id),
  KEY mentorship_msg_sender (sender_id),
  KEY mentorship_msg_receiver (receiver_id),
  KEY mentorship_msg_reply (reply_to_message_id),
  KEY mentorship_msg_created (created_at)
);

-- Mentorship attachments table
CREATE TABLE IF NOT EXISTS mentorship_attachments (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  message_id VARCHAR(12) NOT NULL,
  type ENUM('image','video','voice','document') NOT NULL,
  url TEXT NOT NULL,
  thumbnail TEXT NULL,
  durationSec INT NULL,
  fileSize INT NULL,
  fileName VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_att_fk_msg FOREIGN KEY (message_id) REFERENCES mentorship_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY mentorship_att_msg (message_id)
);

-- Mentorship reactions table
CREATE TABLE IF NOT EXISTS mentorship_reactions (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  message_id VARCHAR(12) NOT NULL,
  user_id VARCHAR(12) NOT NULL,
  emoji VARCHAR(16) NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_react_fk_msg FOREIGN KEY (message_id) REFERENCES mentorship_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_react_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE KEY mentorship_react_unique (message_id, user_id),
  KEY mentorship_react_user (user_id)
);

-- Mentorship message hides table (for delete-for-me functionality)
CREATE TABLE IF NOT EXISTS mentorship_message_hides (
  message_id VARCHAR(12) NOT NULL,
  user_id VARCHAR(12) NOT NULL,
  hidden_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (message_id, user_id),
  CONSTRAINT mentorship_hide_fk_msg FOREIGN KEY (message_id) REFERENCES mentorship_messages (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_hide_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY mentorship_hide_user (user_id)
);