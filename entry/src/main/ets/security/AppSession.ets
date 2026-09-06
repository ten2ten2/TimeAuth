// Transient app-wide authentication state. No credentials or OTPs are persisted here.
// Fail closed until EntryAbility loads the user's persisted app-unlock preference.
let unlockRequired: boolean = true;
let unlocked: boolean = false;
let foreground: boolean = true;
let epoch: number = 0;

function publish(): void {
  AppStorage.setOrCreate<boolean>('timeauth.sessionUnlocked', unlocked && foreground);
}

export function appSessionEpoch(): number {
  return epoch;
}

export function isAppUnlockRequired(): boolean {
  return unlockRequired;
}

export function isAppSessionUnlocked(): boolean {
  return unlocked && foreground;
}

export function configureAppUnlock(required: boolean, authenticatedCurrentSession: boolean = false): void {
  unlockRequired = required;
  epoch += 1;
  unlocked = foreground && (!required || authenticatedCurrentSession);
  publish();
}

export function lockAppSession(): void {
  unlocked = false;
  epoch += 1;
  publish();
}

export function setAppSessionForeground(value: boolean): void {
  if (foreground === value) {
    if (value && !unlockRequired && !unlocked) {
      unlocked = true;
      epoch += 1;
      publish();
    }
    return;
  }
  foreground = value;
  epoch += 1;
  if (!foreground) {
    unlocked = false;
  } else if (!unlockRequired) {
    unlocked = true;
  } else {
    unlocked = false;
  }
  publish();
}

export function unlockAppSession(expectedEpoch: number): boolean {
  if (!foreground || expectedEpoch !== epoch) {
    return false;
  }
  unlocked = true;
  publish();
  return true;
}
