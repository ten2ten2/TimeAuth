import { mockRepository } from '../../data/MockRepository';
import { OtpItem } from '../../models/AppModels';

export const OTP_ISSUER_MAX_LENGTH: number = 128;
export const OTP_ACCOUNT_MAX_LENGTH: number = 256;

// Presentation-only state. Never accept/store OTP secrets in this preview store.
// Keep edits across tab reconstruction, but reset them on a fresh app process.
function cloneItem(item: OtpItem): OtpItem {
  return {
    id: item.id,
    issuer: item.issuer,
    account: item.account,
    code: item.code,
    remainingSeconds: item.remainingSeconds,
    periodSeconds: item.periodSeconds,
    kind: item.kind,
    accentColor: item.accentColor,
    isFavorite: item.isFavorite
  };
}

export function validOtpPreviewLabels(issuer: string, account: string): boolean {
  return issuer.trim().length > 0 && issuer.length <= OTP_ISSUER_MAX_LENGTH &&
    account.length <= OTP_ACCOUNT_MAX_LENGTH;
}

export function otpClipboardValue(code: string): string {
  // Display grouping is not part of an OTP. Preserve leading zeroes and Steam letters.
  return code.replace(/\s/g, '');
}

export function otpPreviewRenderKey(item: OtpItem): string {
  // ForEach with plain @Prop objects must get a new key when a snapshot changes.
  // The preview has no ticking clock; recreate only the changed card after editing.
  return JSON.stringify(cloneItem(item));
}

export class AuthenticatorPreviewStore {
  private items: OtpItem[];

  constructor(initialItems: OtpItem[]) {
    this.items = initialItems.map((item: OtpItem) => cloneItem(item));
  }

  readItems(): OtpItem[] {
    return this.items.map((item: OtpItem) => cloneItem(item));
  }

  findItem(id: string): OtpItem | undefined {
    const item: OtpItem | undefined = this.items.find((entry: OtpItem) => entry.id === id);
    return item === undefined ? undefined : cloneItem(item);
  }

  updateLabels(id: string, issuer: string, account: string): boolean {
    if (!validOtpPreviewLabels(issuer, account)) {
      return false;
    }
    const index: number = this.items.findIndex((item: OtpItem) => item.id === id);
    if (index < 0) {
      return false;
    }
    const updated: OtpItem = cloneItem(this.items[index]);
    updated.issuer = issuer.trim();
    updated.account = account.trim();
    this.items = this.items.map((item: OtpItem) => item.id === id ? updated : item);
    return true;
  }

  removeItem(id: string): boolean {
    const remaining: OtpItem[] = this.items.filter((item: OtpItem) => item.id !== id);
    if (remaining.length === this.items.length) {
      return false;
    }
    this.items = remaining;
    return true;
  }
}

export const authenticatorPreviewStore: AuthenticatorPreviewStore =
  new AuthenticatorPreviewStore(mockRepository.getOtpItems());
