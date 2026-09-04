export enum OtpKind {
  TOTP = 'TOTP',
  HOTP = 'HOTP',
  STEAM = 'STEAM'
}

export interface OtpItem {
  id: string;
  issuer: string;
  account: string;
  code: string;
  remainingSeconds: number;
  periodSeconds: number;
  kind: OtpKind;
  accentColor: string;
  isFavorite: boolean;
}

export enum VaultItemKind {
  LOGIN = 'LOGIN',
  SECURE_NOTE = 'SECURE_NOTE'
}

export interface VaultItem {
  id: string;
  title: string;
  username: string;
  website: string;
  passwordPreview: string;
  kind: VaultItemKind;
  accentColor: string;
  isFavorite: boolean;
  linkedOtpIssuer?: string;
}

export enum GeneratorMode {
  PASSWORD = 'PASSWORD',
  PASSPHRASE = 'PASSPHRASE',
  PIN = 'PIN'
}

export enum ThemePreference {
  SYSTEM = 'SYSTEM',
  LIGHT = 'LIGHT',
  DARK = 'DARK'
}

export enum LanguagePreference {
  SYSTEM = 'SYSTEM',
  SIMPLIFIED_CHINESE = 'SIMPLIFIED_CHINESE',
  TRADITIONAL_CHINESE = 'TRADITIONAL_CHINESE',
  ENGLISH = 'ENGLISH'
}
