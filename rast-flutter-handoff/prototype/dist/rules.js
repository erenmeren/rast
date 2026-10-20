/** Pure demo rules. No location collection, identity checks, or network calls. */
export const MIN_AGE = 18;
export const MAX_PLAUSIBLE_AGE = 130;
export const ENCOUNTER_RADIUS_METERS = 20;
export const DEFAULT_DELAY_HOURS = 2;
export const UPDATE_INTERVAL_SECONDS = Object.freeze([15, 30, 45, 60, 75, 90, 105, 120]);
export const REVEAL_DELAY_HOURS = Object.freeze([0, 1, 2, 4, 6, 12, 18, 24]);

/** Shuffle a copy once per discovery session; encounter times are not inputs. */
export function shuffleIds(ids, random = Math.random) {
  const shuffled = [...ids];
  for (let i = shuffled.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

/**
 * Calculate completed years using UTC calendar dates, independent of timezone.
 * A malformed, impossible, or future birth date returns null.
 */
export function ageFromBirthDate(birthDate, today = new Date()) {
  if (typeof birthDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
    return null;
  }
  if (!(today instanceof Date) || !Number.isFinite(today.getTime())) return null;

  const [year, month, day] = birthDate.split('-').map(Number);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;

  // setUTCFullYear avoids Date.UTC's special handling of years 0–99.
  const birth = new Date(0);
  birth.setUTCHours(0, 0, 0, 0);
  birth.setUTCFullYear(year, month - 1, day);
  if (
    birth.getUTCFullYear() !== year ||
    birth.getUTCMonth() !== month - 1 ||
    birth.getUTCDate() !== day
  ) return null;

  const currentYear = today.getUTCFullYear();
  const currentMonth = today.getUTCMonth() + 1;
  const currentDay = today.getUTCDate();
  let age = currentYear - year;
  if (currentMonth < month || (currentMonth === month && currentDay < day)) age -= 1;
  return age >= 0 ? age : null;
}

export function ageLabel(age) {
  return age >= 99 ? '99+' : String(age);
}

export function isAdultDate(birthDate, today = new Date()) {
  const age = ageFromBirthDate(birthDate, today);
  return age !== null && age >= MIN_AGE && age <= MAX_PLAUSIBLE_AGE;
}

/** A maximum of 99 represents the open-ended “99+” preference. */
export function ageInRange(age, min, max) {
  if (![age, min, max].every(Number.isInteger)) return false;
  if (age < 0 || min < 0 || max < min) return false;
  return age >= min && (max === 99 || age <= max);
}

function validDelay(hours) {
  return REVEAL_DELAY_HOURS.includes(hours) ? hours : DEFAULT_DELAY_HOURS;
}

/** Honor the longer of both people's privacy delays. */
export function effectiveDelay(a, b) {
  return Math.max(validDelay(a), validDelay(b));
}

function timestamp(value) {
  if (value instanceof Date) return value.getTime();
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '') return Date.parse(value);
  return NaN;
}

function adultAge(age) {
  return Number.isInteger(age) && age >= MIN_AGE && age <= MAX_PLAUSIBLE_AGE;
}

/**
 * Evaluate a simulated encounter. Times may be Date, ISO string, or epoch ms.
 * Visibility, accuracy, and mutual preferences require explicit true values.
 * distanceMeters is the distance between people, not the sum of their radii.
 */
export function canRevealEncounter({
  distanceMeters,
  encounterAt,
  now = Date.now(),
  delayA,
  delayB,
  ageA,
  ageB,
  visibleA,
  visibleB,
  mutualPreferences,
  blocked = false,
  disconnected = false,
  accurate,
} = {}) {
  if (!Number.isFinite(distanceMeters) || distanceMeters < 0 || distanceMeters > ENCOUNTER_RADIUS_METERS) {
    return false;
  }
  if (!adultAge(ageA) || !adultAge(ageB)) return false;
  if (visibleA !== true || visibleB !== true || mutualPreferences !== true || accurate !== true || blocked !== false || disconnected !== false) {
    return false;
  }

  const encountered = timestamp(encounterAt);
  const current = timestamp(now);
  if (!Number.isFinite(encountered) || !Number.isFinite(current)) return false;
  const elapsed = current - encountered;
  return elapsed >= effectiveDelay(delayA, delayB) * 60 * 60 * 1000;
}
