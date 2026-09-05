// Transient app-wide authentication state. No credentials, OTPs or persistent flags here.
let unlocked: boolean = false;
let foreground: boolean = true;
let epoch: number = 0;

export function appSessionEpoch(): number {
  return epoch;
}

export function isAppSessionUnlocked(): boolean {
  return unlocked && foreground;
}

export function lockAppSession(): void {
  unlocked = false;
  epoch += 1;
  AppStorage.setOrCreate<boolean>('timeauth.sessionUnlocked', false);
}

export function setAppSessionForeground(value: boolean): void {
  foreground = value;
  if (!value) {
    lockAppSession();
  }
}

export function unlockAppSession(expectedEpoch: number): boolean {
  if (!foreground || expectedEpoch !== epoch) {
    return false;
  }
  unlocked = true;
  AppStorage.setOrCreate<boolean>('timeauth.sessionUnlocked', true);
  return true;
}
