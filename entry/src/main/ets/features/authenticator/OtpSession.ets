import { OtpKind } from '../../models/AppModels';
import {
  OtpAccount, OtpDraft, OtpError, OtpErrorCode,
  otpCounter, remainingSeconds
} from './OtpCore';
import { OtpCodeProvider } from './OtpCrypto';
import { OtpRepository } from './OtpRepository';

export interface OtpSnapshot {
  id: string;
  issuer: string;
  account: string;
  kind: OtpKind;
  code: string; // Ungrouped display data only. Never contains a seed.
  remaining: number;
  period: number;
  counter: number;
  failed: boolean;
}

class CachedOtp {
  counter: number = -1;
  code: string = '';
  failed: boolean = false;
}

// A foreground, unlocked session. No accounts/seeds are retained in AppStorage or a singleton.
export class OtpSession {
  private repository: OtpRepository;
  private crypto: OtpCodeProvider;
  private now: () => number;
  private publish: (items: OtpSnapshot[]) => void;
  private accounts: OtpAccount[] = [];
  private cache: Map<string, CachedOtp> = new Map<string, CachedOtp>();
  private revision: number = 0;
  private active: boolean = false;
  private refreshing: boolean = false;
  private mutating: boolean = false;
  private mutationTicket: number = 0;

  constructor(repository: OtpRepository, crypto: OtpCodeProvider, now: () => number,
    publish: (items: OtpSnapshot[]) => void) {
    this.repository = repository;
    this.crypto = crypto;
    this.now = now;
    this.publish = publish;
  }

  async open(): Promise<void> {
    const revision: number = ++this.revision;
    this.active = false;
    this.clearMemory();
    const accounts: OtpAccount[] = await this.repository.list();
    if (revision !== this.revision) {
      accounts.forEach((account: OtpAccount) => { account.secret = ''; });
      return;
    }
    this.accounts = accounts;
    this.active = true;
    this.emit();
    await this.refresh();
  }

  close(): void {
    this.revision += 1;
    this.active = false;
    this.clearMemory();
    this.publish([]);
    // Closing waits behind accepted writes. It does not roll them back or reset the database.
    this.repository.close().catch(() => {});
  }

  private clearMemory(): void {
    for (let i: number = 0; i < this.accounts.length; i++) {
      this.accounts[i].secret = '';
    }
    this.accounts = [];
    this.cache.clear();
    this.refreshing = false;
    this.mutating = false;
    this.mutationTicket += 1;
  }

  private requireActive(): void {
    if (!this.active) {
      throw new OtpError(OtpErrorCode.LOCKED);
    }
  }

  private generationCounter(account: OtpAccount): number {
    return account.kind === OtpKind.HOTP ? account.counter : otpCounter(this.now(), account.period);
  }

  draft(id: string): OtpDraft {
    this.requireActive();
    const found: OtpAccount | undefined = this.accounts.find((item: OtpAccount) => item.id === id);
    if (found === undefined) {
      throw new OtpError(OtpErrorCode.NOT_FOUND);
    }
    return {
      issuer: found.issuer, account: found.account, secret: found.secret, kind: found.kind,
      algorithm: found.algorithm, digits: found.digits, period: found.period, counter: found.counter
    };
  }

  private emit(): void {
    if (!this.active) {
      return;
    }
    const now: number = this.now();
    const snapshots: OtpSnapshot[] = [];
    for (let i: number = 0; i < this.accounts.length; i++) {
      const account: OtpAccount = this.accounts[i];
      const generationCounter: number = account.kind === OtpKind.HOTP ?
        account.counter : otpCounter(now, account.period);
      const cached: CachedOtp | undefined = this.cache.get(account.id);
      const current: boolean = cached !== undefined && cached.counter === generationCounter;
      snapshots.push({
        id: account.id, issuer: account.issuer, account: account.account, kind: account.kind,
        code: current && cached !== undefined ? cached.code : '',
        remaining: account.kind === OtpKind.HOTP ? 0 : remainingSeconds(now, account.period),
        period: account.kind === OtpKind.HOTP ? 0 : account.period,
        counter: account.counter,
        failed: current && cached !== undefined ? cached.failed : false
      });
    }
    this.publish(snapshots);
  }

  async refresh(): Promise<void> {
    if (!this.active) {
      return;
    }
    // Immediately hide codes from a previous TOTP step or HOTP counter before native HMAC is in flight.
    this.emit();
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    const revision: number = this.revision;
    try {
      for (let i: number = 0; i < this.accounts.length; i++) {
        if (!this.active || revision !== this.revision) {
          return;
        }
        const account: OtpAccount = this.accounts[i];
        const counter: number = this.generationCounter(account);
        const previous: CachedOtp | undefined = this.cache.get(account.id);
        if (previous !== undefined && previous.counter === counter && !previous.failed) {
          continue;
        }
        const next: CachedOtp = new CachedOtp();
        next.counter = counter;
        try {
          next.code = await this.crypto.generate(account, counter);
        } catch {
          next.failed = true;
        }
        if (!this.active || revision !== this.revision) {
          return;
        }
        this.cache.set(account.id, next);
      }
      this.emit();
    } finally {
      if (revision === this.revision) {
        this.refreshing = false;
      }
    }
  }

  async freshCode(id: string): Promise<string> {
    this.requireActive();
    const revision: number = this.revision;
    const account: OtpAccount | undefined = this.accounts.find((item: OtpAccount) => item.id === id);
    if (account === undefined) {
      throw new OtpError(OtpErrorCode.NOT_FOUND);
    }
    if (account.kind === OtpKind.HOTP) {
      const code: string = await this.crypto.generate(account, account.counter);
      if (!this.active || revision !== this.revision) {
        throw new OtpError(OtpErrorCode.LOCKED);
      }
      return code;
    }
    for (let attempt: number = 0; attempt < 3; attempt++) {
      const counter: number = otpCounter(this.now(), account.period);
      const code: string = await this.crypto.generate(account, counter);
      if (!this.active || revision !== this.revision) {
        throw new OtpError(OtpErrorCode.LOCKED);
      }
      if (counter === otpCounter(this.now(), account.period)) {
        return code;
      }
    }
    throw new OtpError(OtpErrorCode.CRYPTO);
  }

  async save(id: string, draft: OtpDraft): Promise<void> {
    this.requireActive();
    if (this.mutating) {
      throw new OtpError(OtpErrorCode.BUSY);
    }
    this.mutating = true;
    const ticket: number = ++this.mutationTicket;
    const revision: number = this.revision;
    try {
      const stored: OtpAccount = id.length === 0 ?
        await this.repository.add(draft) : await this.repository.update(id, draft);
      if (!this.active || revision !== this.revision) {
        stored.secret = '';
        return;
      }
      // Invalidate older calculations, without changing the stable UI account ID.
      this.revision += 1;
      this.refreshing = false;
      this.cache.delete(stored.id);
      const index: number = this.accounts.findIndex((account: OtpAccount) => account.id === stored.id);
      if (index < 0) {
        this.accounts.push(stored);
      } else {
        this.accounts[index].secret = '';
        this.accounts[index] = stored;
      }
      this.emit();
      await this.refresh();
    } finally {
      if (ticket === this.mutationTicket) { this.mutating = false; }
    }
  }

  async advanceHOTP(id: string): Promise<void> {
    this.requireActive();
    if (this.mutating) {
      throw new OtpError(OtpErrorCode.BUSY);
    }
    const current: OtpAccount | undefined = this.accounts.find((account: OtpAccount) => account.id === id);
    if (current === undefined) {
      throw new OtpError(OtpErrorCode.NOT_FOUND);
    }
    if (current.kind !== OtpKind.HOTP) {
      throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
    }
    this.mutating = true;
    const ticket: number = ++this.mutationTicket;
    const revision: number = this.revision;
    try {
      const stored: OtpAccount = await this.repository.advanceCounter(id);
      if (!this.active || revision !== this.revision) {
        stored.secret = '';
        return;
      }
      this.revision += 1;
      this.refreshing = false;
      this.cache.delete(id);
      const index: number = this.accounts.findIndex((account: OtpAccount) => account.id === id);
      if (index < 0) {
        stored.secret = '';
        throw new OtpError(OtpErrorCode.NOT_FOUND);
      }
      this.accounts[index].secret = '';
      this.accounts[index] = stored;
      this.emit();
      await this.refresh();
    } finally {
      if (ticket === this.mutationTicket) { this.mutating = false; }
    }
  }

  async remove(id: string): Promise<void> {
    this.requireActive();
    if (this.mutating) {
      throw new OtpError(OtpErrorCode.BUSY);
    }
    this.mutating = true;
    const ticket: number = ++this.mutationTicket;
    const revision: number = this.revision;
    try {
      await this.repository.remove(id);
      if (!this.active || revision !== this.revision) {
        return;
      }
      this.revision += 1;
      this.refreshing = false;
      const removed: OtpAccount | undefined = this.accounts.find((account: OtpAccount) => account.id === id);
      if (removed !== undefined) {
        removed.secret = '';
      }
      this.accounts = this.accounts.filter((account: OtpAccount) => account.id !== id);
      this.cache.delete(id);
      this.emit();
    } finally {
      if (ticket === this.mutationTicket) { this.mutating = false; }
    }
  }
}
