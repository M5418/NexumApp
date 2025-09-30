export function generateFiveDigitCode() {
    return Math.floor(Math.random() * 100000).toString().padStart(5, '0');
  }