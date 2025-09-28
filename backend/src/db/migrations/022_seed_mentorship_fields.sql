INSERT INTO mentorship_fields (id, name, icon, description)
VALUES
  ('mfinan001', 'Finance', '📈', 'Investing, financial planning, budgeting, and wealth management.'),
  ('mbusin001', 'Business', '💼', 'Entrepreneurship, business strategy, leadership, and operations.'),
  ('mtech0001', 'Tech',    '💻', 'Software development, AI/ML, cloud, and emerging technologies.'),
  ('mmarkt001', 'Marketing','📣', 'Digital marketing, brand building, content and growth.')
ON DUPLICATE KEY UPDATE name = VALUES(name), icon = VALUES(icon), description = VALUES(description);