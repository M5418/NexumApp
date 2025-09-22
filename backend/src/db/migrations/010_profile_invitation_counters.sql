-- 010_profile_invitation_counters.sql
-- Adds invitation counter columns expected by Prisma schema/Profile model

ALTER TABLE profiles ADD COLUMN invitations_sent INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN invitations_received INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN invitations_accepted INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN invitations_refused INT DEFAULT 0;
ALTER TABLE profiles ADD COLUMN pending_invitations INT DEFAULT 0;
