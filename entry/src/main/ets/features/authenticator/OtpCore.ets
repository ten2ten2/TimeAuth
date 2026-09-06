// RFC 4226 / RFC 6238 formatting and strict provisioning validation.
// No platform APIs, persistence, logging, or random/demo credentials in this module.
import { OtpKind } from '../../models/AppModels';

export enum OtpAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512'
}

export enum OtpErrorCode {
  INVALID_SECRET = 'INVALID_SECRET',
  INVALID_LABEL = 'INVALID_LABEL',
  INVALID_PARAMETERS = 'INVALID_PARAMETERS',
  INVALID_URI = 'INVALID_URI',
  UNSUPPORTED_IMPORT = 'UNSUPPORTED_IMPORT',
  ISSUER_MISMATCH = 'ISSUER_MISMATCH',
  DUPLICATE = 'DUPLICATE',
  NOT_FOUND = 'NOT_FOUND',
  STORAGE = 'STORAGE',
  CRYPTO = 'CRYPTO',
  LOCKED = 'LOCKED',
  BUSY = 'BUSY'
}

export class OtpError extends Error {
  readonly code: OtpErrorCode;
  constructor(code: OtpErrorCode) {
    // Error messages deliberately never include labels, URIs or secret material.
    super(code);
    this.code = code;
  }
}

export interface OtpDraft {
  issuer: string;
  account: string;
  secret: string; // Canonical, unpadded Base32, including for Steam.
  kind: OtpKind;
  algorithm: OtpAlgorithm;
  digits: number;
  period: number; // Canonical 30 for HOTP; not used to generate HOTP codes.
  counter?: number; // Required semantically for HOTP; omitted legacy TOTP rows hydrate as 0.
}

export interface OtpAccount extends OtpDraft {
  id: string;
  createdAt: number;
  counter: number;
}

export const OTP_ISSUER_MAX_LENGTH: number = 128;
export const OTP_ACCOUNT_MAX_LENGTH: number = 256;
export const OTP_SECRET_MAX_LENGTH: number = 2048;
export const OTP_MAX_ACCOUNTS: number = 500;
const BASE32: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const STEAM_ALPHABET: string = '23456789BCDFGHJKMNPQRTVWXY';

export function decodeBase32(value: string): Uint8Array {
  if (typeof value !== 'string' || value.length > OTP_SECRET_MAX_LENGTH) {
    throw new OtpError(OtpErrorCode.INVALID_SECRET);
  }
  const compact: string = value.replace(/[\s-]/g, '').toUpperCase();
  const text: string = compact.replace(/=+$/, '');
  const remainder: number = text.length % 8;
  if (text.length === 0 || !/^[A-Z2-7]+$/.test(text) ||
    [0, 2, 4, 5, 7].indexOf(remainder) < 0 ||
    (compact.length !== text.length &&
      (compact.length % 8 !== 0 || compact.length - text.length !== (8 - remainder) % 8))) {
    throw new OtpError(OtpErrorCode.INVALID_SECRET);
  }
  const result: Uint8Array = new Uint8Array(Math.floor(text.length * 5 / 8));
  let bits: number = 0;
  let accumulator: number = 0;
  let index: number = 0;
  for (let i: number = 0; i < text.length; i++) {
    accumulator = (accumulator << 5) | BASE32.indexOf(text.charAt(i));
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      result[index++] = (accumulator >>> bits) & 255;
      accumulator &= (1 << bits) - 1;
    }
  }
  if (accumulator !== 0) {
    result.fill(0);
    throw new OtpError(OtpErrorCode.INVALID_SECRET);
  }
  return result;
}

export function encodeBase32(bytes: Uint8Array): string {
  let result: string = '';
  let bits: number = 0;
  let accumulator: number = 0;
  for (let i: number = 0; i < bytes.length; i++) {
    accumulator = (accumulator << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      result += BASE32.charAt((accumulator >>> bits) & 31);
    }
    accumulator &= (1 << bits) - 1;
  }
  if (bits > 0) {
    result += BASE32.charAt((accumulator << (5 - bits)) & 31);
  }
  return result;
}

// Steam exports shared_secret as Base64. The editor labels this format explicitly.
export function steamSharedSecretToBase32(input: string): string {
  const alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const value: string = input.trim();
  // A Steam shared_secret is exactly 20 bytes: 27 symbols and one '='.
  if (!/^[A-Za-z0-9+/]{27}=$/.test(value)) {
    throw new OtpError(OtpErrorCode.INVALID_SECRET);
  }
  const bytes: Uint8Array = new Uint8Array(20);
  let accumulator: number = 0;
  let bits: number = 0;
  let index: number = 0;
  try {
    for (let i: number = 0; i < 27; i++) {
      accumulator = (accumulator << 6) | alphabet.indexOf(value.charAt(i));
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        bytes[index++] = (accumulator >>> bits) & 255;
        accumulator &= (1 << bits) - 1;
      }
    }
    if (accumulator !== 0 || index !== 20) {
      throw new OtpError(OtpErrorCode.INVALID_SECRET);
    }
    return encodeBase32(bytes);
  } finally {
    bytes.fill(0);
  }
}

export function validateDraft(input: OtpDraft): OtpDraft {
  if (input === null || typeof input !== 'object' || typeof input.issuer !== 'string' ||
    typeof input.account !== 'string' || input.issuer.trim().length === 0 ||
    input.issuer.length > OTP_ISSUER_MAX_LENGTH || input.account.length > OTP_ACCOUNT_MAX_LENGTH ||
    /[\u0000-\u001f\u007f\u202a-\u202e\u2066-\u2069]/.test(input.issuer + input.account)) {
    throw new OtpError(OtpErrorCode.INVALID_LABEL);
  }
  const counter: number = input.counter ?? 0;
  if ((input.kind !== OtpKind.TOTP && input.kind !== OtpKind.HOTP && input.kind !== OtpKind.STEAM) ||
    (input.algorithm !== OtpAlgorithm.SHA1 && input.algorithm !== OtpAlgorithm.SHA256 &&
      input.algorithm !== OtpAlgorithm.SHA512) ||
    !Number.isInteger(input.period) || input.period < 1 || input.period > 86400 ||
    !Number.isSafeInteger(counter) || counter < 0 ||
    ((input.kind === OtpKind.TOTP || input.kind === OtpKind.HOTP) && input.digits !== 6 && input.digits !== 8) ||
    (input.kind === OtpKind.TOTP && counter !== 0) ||
    (input.kind === OtpKind.HOTP && input.period !== 30) ||
    (input.kind === OtpKind.STEAM &&
      (input.algorithm !== OtpAlgorithm.SHA1 || input.digits !== 5 || input.period !== 30 || counter !== 0))) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  const bytes: Uint8Array = decodeBase32(input.secret);
  try {
    if (bytes.length < 10 || bytes.length > 512 || (input.kind === OtpKind.STEAM && bytes.length !== 20)) {
      throw new OtpError(OtpErrorCode.INVALID_SECRET);
    }
    return {
      issuer: input.issuer.trim(), account: input.account.trim(), secret: encodeBase32(bytes),
      kind: input.kind, algorithm: input.algorithm, digits: input.digits, period: input.period,
      counter: counter
    };
  } finally {
    bytes.fill(0);
  }
}

export function accountFromDraft(draft: OtpDraft, id: string, createdAt: number): OtpAccount {
  const checked: OtpDraft = validateDraft(draft);
  if (typeof id !== 'string' || !/^[a-f0-9]{32}$/.test(id) ||
    !Number.isSafeInteger(createdAt) || createdAt < 0) {
    throw new OtpError(OtpErrorCode.STORAGE);
  }
  return {
    id: id, createdAt: createdAt, issuer: checked.issuer, account: checked.account, secret: checked.secret,
    kind: checked.kind, algorithm: checked.algorithm, digits: checked.digits, period: checked.period,
    counter: checked.counter ?? 0
  };
}

// HOTP counter is mutable state, not credential identity. The same key/configuration must not be duplicated at another counter.
export function credentialIdentity(value: OtpDraft): string {
  return `${value.kind}:${value.algorithm}:${value.digits}:${value.period}:${value.secret}`;
}

function decodeUriPart(value: string, query: boolean): string {
  try {
    return decodeURIComponent(query ? value.replace(/\+/g, ' ') : value);
  } catch {
    throw new OtpError(OtpErrorCode.INVALID_URI);
  }
}

function uriInteger(value: string | undefined, fallback: number): number {
  if (value === undefined) {
    return fallback;
  }
  if (!/^[0-9]{1,6}$/.test(value)) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  return Number(value);
}

function uriCounter(value: string | undefined): number {
  if (value === undefined || !/^[0-9]{1,16}$/.test(value)) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  const counter: number = Number(value);
  if (!Number.isSafeInteger(counter) || counter < 0) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  return counter;
}

export function parseOtpAuthUri(input: string): OtpDraft {
  if (typeof input !== 'string' || input.length > 8192) {
    throw new OtpError(OtpErrorCode.INVALID_URI);
  }
  const uri: string = input.trim();
  if (/^otpauth-migration:\/\//i.test(uri)) {
    throw new OtpError(OtpErrorCode.UNSUPPORTED_IMPORT);
  }
  const match: RegExpMatchArray | null = uri.match(/^otpauth:\/\/([^/?#]+)\/([^?#]+)\?([^#]+)$/i);
  if (match === null) {
    throw new OtpError(OtpErrorCode.INVALID_URI);
  }
  const type: string = match[1].toLowerCase();
  if (type !== 'totp' && type !== 'hotp') {
    throw new OtpError(OtpErrorCode.UNSUPPORTED_IMPORT);
  }
  const hotp: boolean = type === 'hotp';
  const params: Map<string, string> = new Map<string, string>();
  const parts: string[] = match[3].split('&');
  for (let i: number = 0; i < parts.length; i++) {
    const equal: number = parts[i].indexOf('=');
    if (equal < 1) {
      throw new OtpError(OtpErrorCode.INVALID_URI);
    }
    const key: string = decodeUriPart(parts[i].substring(0, equal), true).toLowerCase();
    if (params.has(key)) {
      throw new OtpError(OtpErrorCode.INVALID_URI);
    }
    params.set(key, decodeUriPart(parts[i].substring(equal + 1), true));
  }
  if ((!hotp && params.has('counter')) || (hotp && params.has('period'))) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  const label: string = decodeUriPart(match[2], false);
  const separator: number = label.indexOf(':');
  const prefix: string = separator < 0 ? '' : label.substring(0, separator).trim();
  const account: string = (separator < 0 ? label : label.substring(separator + 1)).trim();
  const queryIssuer: string = (params.get('issuer') ?? '').trim();
  if (prefix.length > 0 && queryIssuer.length > 0 && prefix.toLowerCase() !== queryIssuer.toLowerCase()) {
    throw new OtpError(OtpErrorCode.ISSUER_MISMATCH);
  }
  const issuer: string = queryIssuer || prefix || account;
  const encoder: string = (params.get('encoder') ?? '').toLowerCase();
  if (encoder !== '' && encoder !== 'steam') {
    throw new OtpError(OtpErrorCode.UNSUPPORTED_IMPORT);
  }
  if (hotp && encoder.length > 0) {
    throw new OtpError(OtpErrorCode.UNSUPPORTED_IMPORT);
  }
  const steam: boolean = encoder === 'steam';
  const algorithm: string = (params.get('algorithm') ?? 'SHA1').toUpperCase();
  if (algorithm !== 'SHA1' && algorithm !== 'SHA256' && algorithm !== 'SHA512') {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  return validateDraft({
    issuer: issuer, account: account, secret: params.get('secret') ?? '',
    kind: steam ? OtpKind.STEAM : hotp ? OtpKind.HOTP : OtpKind.TOTP,
    algorithm: algorithm as OtpAlgorithm,
    digits: uriInteger(params.get('digits'), steam ? 5 : 6),
    period: hotp ? 30 : uriInteger(params.get('period'), 30),
    counter: hotp ? uriCounter(params.get('counter')) : 0
  });
}

export function otpCounter(now: number, period: number): number {
  if (!Number.isSafeInteger(now) || now < 0 || !Number.isInteger(period) || period < 1 || period > 86400) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  return Math.floor(now / 1000 / period);
}

export function counterBytes(counter: number): Uint8Array {
  if (!Number.isSafeInteger(counter) || counter < 0) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  const bytes: Uint8Array = new Uint8Array(8);
  let remaining: number = counter;
  for (let i: number = 7; i >= 0; i--) {
    bytes[i] = remaining % 256;
    remaining = Math.floor(remaining / 256);
  }
  return bytes;
}

export function remainingSeconds(now: number, period: number): number {
  const counter: number = otpCounter(now, period);
  return Math.ceil(((counter + 1) * period * 1000 - now) / 1000);
}

export function truncateOtp(mac: Uint8Array, kind: OtpKind, digits: number): string {
  if (mac.length < 20) {
    throw new OtpError(OtpErrorCode.CRYPTO);
  }
  const offset: number = mac[mac.length - 1] & 15;
  let value: number = ((mac[offset] & 127) << 24) | ((mac[offset + 1] & 255) << 16) |
    ((mac[offset + 2] & 255) << 8) | (mac[offset + 3] & 255);
  if (kind === OtpKind.STEAM && digits === 5) {
    let result: string = '';
    for (let i: number = 0; i < 5; i++) {
      result += STEAM_ALPHABET.charAt(value % STEAM_ALPHABET.length);
      value = Math.floor(value / STEAM_ALPHABET.length);
    }
    return result;
  }
  if ((kind !== OtpKind.TOTP && kind !== OtpKind.HOTP) || (digits !== 6 && digits !== 8)) {
    throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
  }
  return (value % Math.pow(10, digits)).toString().padStart(digits, '0');
}

export function displayOtp(code: string): string {
  if (/^\d{6}$/.test(code)) {
    return `${code.substring(0, 3)} ${code.substring(3)}`;
  }
  if (/^\d{8}$/.test(code)) {
    return `${code.substring(0, 4)} ${code.substring(4)}`;
  }
  return code;
}

export function emptyOtpDraft(): OtpDraft {
  return { issuer: '', account: '', secret: '', kind: OtpKind.TOTP,
    algorithm: OtpAlgorithm.SHA1, digits: 6, period: 30, counter: 0 };
}
