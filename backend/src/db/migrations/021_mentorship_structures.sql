CREATE TABLE IF NOT EXISTS mentorship_fields (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  name VARCHAR(64) NOT NULL,
  icon VARCHAR(8) NULL,
  description TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS mentorship_requests (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  requester_user_id VARCHAR(12) NOT NULL,
  field_id VARCHAR(12) NOT NULL,
  message TEXT NOT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_requests_fk_user FOREIGN KEY (requester_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_requests_fk_field FOREIGN KEY (field_id) REFERENCES mentorship_fields (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY mentorship_requests_user (requester_user_id),
  KEY mentorship_requests_field (field_id),
  KEY mentorship_requests_status (status)
);

CREATE TABLE IF NOT EXISTS mentorship_sessions (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  mentor_user_id VARCHAR(12) NOT NULL,
  mentee_user_id VARCHAR(12) NOT NULL,
  scheduled_at DATETIME NOT NULL,
  duration_minutes INT NOT NULL,
  topic VARCHAR(255) NOT NULL,
  status ENUM('scheduled','in_progress','completed','cancelled') NOT NULL DEFAULT 'scheduled',
  meeting_link TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_sessions_fk_mentor FOREIGN KEY (mentor_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_sessions_fk_mentee FOREIGN KEY (mentee_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY mentorship_sessions_mentor (mentor_user_id),
  KEY mentorship_sessions_mentee (mentee_user_id),
  KEY mentorship_sessions_status (status),
  KEY mentorship_sessions_scheduled (scheduled_at)
);

CREATE TABLE IF NOT EXISTS mentorship_reviews (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  session_id VARCHAR(12) NOT NULL,
  mentor_user_id VARCHAR(12) NOT NULL,
  mentee_user_id VARCHAR(12) NOT NULL,
  rating INT NOT NULL,
  comment TEXT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_reviews_fk_session FOREIGN KEY (session_id) REFERENCES mentorship_sessions (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_reviews_fk_mentor FOREIGN KEY (mentor_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_reviews_fk_mentee FOREIGN KEY (mentee_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  KEY mentorship_reviews_session (session_id),
  KEY mentorship_reviews_mentor (mentor_user_id)
);