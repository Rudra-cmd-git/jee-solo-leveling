/**
 * Task input validation functions
 * Used by backend API to validate user input before database operations
 */

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Validate task title
 * - Must be a non-empty string
 * - After trimming, must contain at least 1 character
 * - Maximum 255 characters
 */
export function validateTitle(title: unknown): string {
  if (typeof title !== 'string') {
    throw new ValidationError('Title must be a string');
  }

  const trimmed = title.trim();

  if (trimmed.length === 0) {
    throw new ValidationError('Title cannot be empty or whitespace-only');
  }

  if (trimmed.length > 255) {
    throw new ValidationError('Title cannot exceed 255 characters');
  }

  return trimmed;
}

/**
 * Validate task subject
 * - Must be a non-empty string
 * - After trimming, must contain at least 1 character
 * - Maximum 255 characters
 */
export function validateSubject(subject: unknown): string {
  if (typeof subject !== 'string') {
    throw new ValidationError('Subject must be a string');
  }

  const trimmed = subject.trim();

  if (trimmed.length === 0) {
    throw new ValidationError('Subject cannot be empty or whitespace-only');
  }

  if (trimmed.length > 255) {
    throw new ValidationError('Subject cannot exceed 255 characters');
  }

  return trimmed;
}

/**
 * Validate task XP value
 * - Must be a number (or numeric string)
 * - Must be an integer
 * - Must be between 1 and 1000 inclusive
 */
export function validateXpValue(xpValue: unknown): number {
  let num: number;

  if (typeof xpValue === 'number') {
    num = xpValue;
  } else if (typeof xpValue === 'string') {
    const parsed = parseInt(xpValue, 10);
    if (Number.isNaN(parsed)) {
      throw new ValidationError('XP value must be a valid number');
    }
    num = parsed;
  } else {
    throw new ValidationError('XP value must be a number');
  }

  if (!Number.isInteger(num)) {
    throw new ValidationError('XP value must be an integer');
  }

  if (num < 1 || num > 1000) {
    throw new ValidationError('XP value must be between 1 and 1000');
  }

  return num;
}
