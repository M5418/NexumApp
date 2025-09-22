-- 011_invitations.sql
-- Invitations table to match Prisma model and backend logic

CREATE TABLE IF NOT EXISTS invitations (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  sender_id VARCHAR(12) NOT NULL,
  receiver_id VARCHAR(12) NOT NULL,
  invitation_content TEXT NOT NULL,
  status ENUM('pending','accepted','refused') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT invitations_fk_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT invitations_fk_receiver FOREIGN KEY (receiver_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY invitations_sender_id (sender_id),
  KEY invitations_receiver_id (receiver_id),
  KEY invitations_status (status),
  KEY invitations_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
