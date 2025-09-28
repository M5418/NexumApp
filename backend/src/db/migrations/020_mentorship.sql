-- Mentorship relations (mentor <-> mentee)
CREATE TABLE IF NOT EXISTS mentorship_relations (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  mentor_user_id VARCHAR(12) NOT NULL,
  mentee_user_id VARCHAR(12) NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT mentorship_relations_fk_mentor FOREIGN KEY (mentor_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT mentorship_relations_fk_mentee FOREIGN KEY (mentee_user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE KEY mentorship_unique (mentor_user_id, mentee_user_id),
  KEY mentorship_mentor (mentor_user_id),
  KEY mentorship_mentee (mentee_user_id)
);