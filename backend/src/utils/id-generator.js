/**
 * Generate a random 12-character alphanumeric ID
 * Uses uppercase letters, lowercase letters, and digits
 * Example: "aB3xY9mK2pQ1"
 */
export function generateUserId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  
  for (let i = 0; i < 12; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  
  return result;
}

/**
 * Generate a random 12-character alphanumeric ID (alias for consistency)
 */
export function generateId() {
  return generateUserId();
}
