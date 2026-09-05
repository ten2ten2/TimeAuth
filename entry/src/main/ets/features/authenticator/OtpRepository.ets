import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { isAppSessionUnlocked } from '../../security/AppSession';
import {
  accountFromDraft, credentialIdentity, OtpAccount, OtpDraft, OtpError, OtpErrorCode,
  OTP_MAX_ACCOUNTS, validateDraft
} from './OtpCore';
import { newOtpId } from './OtpCrypto';

export interface OtpRepository {
  list(): Promise<OtpAccount[]>;
  add(draft: OtpDraft): Promise<OtpAccount>;
  update(id: string, draft: OtpDraft): Promise<OtpAccount>;
  remove(id: string): Promise<void>;
  close(): Promise<void>;
}

// Whole-database encryption covers secrets AND issuer/account metadata, including SQL indexes.
// ArkData manages the database key. Do not supply a hard-coded cryptoParam or a plaintext fallback.
const CONFIG: relationalStore.StoreConfig = {
  name: 'timeauth_authenticator_v1.db',
  securityLevel: relationalStore.SecurityLevel.S3,
  encrypt: true
};
const TABLE: string = 'otp_accounts';

export class EncryptedOtpRepository implements OtpRepository {
  private context: common.Context;
  private store: relationalStore.RdbStore | undefined = undefined;
  private tail: Promise<void> = Promise.resolve();

  constructor(context: common.Context) {
    this.context = context;
  }

  private requireUnlocked(): void {
    if (!isAppSessionUnlocked()) {
      throw new OtpError(OtpErrorCode.LOCKED);
    }
  }

  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const result: Promise<T> = this.tail.then(operation).catch((error: Error) => {
      if (error instanceof OtpError) { throw error; }
      throw new OtpError(OtpErrorCode.STORAGE);
    });
    // A failed write must not poison the queue or turn later reads into an empty database.
    this.tail = result.then(() => {}, () => {});
    return result;
  }

  private async database(): Promise<relationalStore.RdbStore> {
    this.requireUnlocked();
    if (this.store !== undefined) {
      return this.store;
    }
    let opened: relationalStore.RdbStore | undefined = undefined;
    try {
      opened = await relationalStore.getRdbStore(this.context, CONFIG);
      if (opened.version !== 0 && opened.version !== 1) {
        throw new OtpError(OtpErrorCode.STORAGE);
      }
      // Never DROP, replace, or automatically rebuild an unreadable database.
      await opened.executeSql('CREATE TABLE IF NOT EXISTS otp_accounts (' +
        'id TEXT PRIMARY KEY NOT NULL, credential_key TEXT UNIQUE NOT NULL, ' +
        'payload TEXT NOT NULL, created_at INTEGER NOT NULL)');
      opened.version = 1;
      this.requireUnlocked();
      this.store = opened;
      return opened;
    } catch {
      if (opened !== undefined) {
        try { await opened.close(); } catch {}
      }
      throw new OtpError(OtpErrorCode.STORAGE);
    }
  }

  private async readAll(store: relationalStore.RdbStore): Promise<OtpAccount[]> {
    const result: relationalStore.ResultSet = await store.querySql(
      'SELECT id, payload, created_at FROM otp_accounts ORDER BY created_at ASC, id ASC');
    const accounts: OtpAccount[] = [];
    try {
      if (result.rowCount > OTP_MAX_ACCOUNTS) {
        throw new OtpError(OtpErrorCode.STORAGE);
      }
      while (result.goToNextRow()) {
        const payload: string = result.getString(result.getColumnIndex('payload'));
        if (payload.length > 8192) {
          throw new OtpError(OtpErrorCode.STORAGE);
        }
        const parsed: OtpDraft = JSON.parse(payload) as OtpDraft;
        accounts.push(accountFromDraft(parsed,
          result.getString(result.getColumnIndex('id')),
          result.getLong(result.getColumnIndex('created_at'))));
      }
      return accounts;
    } finally {
      result.close();
    }
  }

  list(): Promise<OtpAccount[]> {
    return this.enqueue(async (): Promise<OtpAccount[]> => {
      try {
        const accounts: OtpAccount[] = await this.readAll(await this.database());
        this.requireUnlocked();
        return accounts;
      } catch {
        throw new OtpError(OtpErrorCode.STORAGE);
      }
    });
  }

  private assertUnique(accounts: OtpAccount[], draft: OtpDraft, exceptId: string): void {
    const identity: string = credentialIdentity(draft);
    for (let i: number = 0; i < accounts.length; i++) {
      if (accounts[i].id !== exceptId && credentialIdentity(accounts[i]) === identity) {
        throw new OtpError(OtpErrorCode.DUPLICATE);
      }
    }
  }

  add(input: OtpDraft): Promise<OtpAccount> {
    const draft: OtpDraft = validateDraft(input);
    return this.enqueue(async (): Promise<OtpAccount> => {
      const store: relationalStore.RdbStore = await this.database();
      const accounts: OtpAccount[] = await this.readAll(store);
      if (accounts.length >= OTP_MAX_ACCOUNTS) {
        throw new OtpError(OtpErrorCode.INVALID_PARAMETERS);
      }
      this.assertUnique(accounts, draft, '');
      const account: OtpAccount = accountFromDraft(draft, newOtpId(), Date.now());
      const values: relationalStore.ValuesBucket = {
        id: account.id, credential_key: credentialIdentity(account),
        payload: JSON.stringify(draft), created_at: account.createdAt
      };
      this.requireUnlocked();
      // One atomic INSERT. Publish in-memory changes only after native commit succeeds.
      await store.insert(TABLE, values);
      return account;
    });
  }

  update(id: string, input: OtpDraft): Promise<OtpAccount> {
    const draft: OtpDraft = validateDraft(input);
    return this.enqueue(async (): Promise<OtpAccount> => {
      const store: relationalStore.RdbStore = await this.database();
      const accounts: OtpAccount[] = await this.readAll(store);
      const previous: OtpAccount | undefined = accounts.find((account: OtpAccount) => account.id === id);
      if (previous === undefined) {
        throw new OtpError(OtpErrorCode.NOT_FOUND);
      }
      this.assertUnique(accounts, draft, id);
      const updated: OtpAccount = accountFromDraft(draft, id, previous.createdAt);
      const values: relationalStore.ValuesBucket = {
        credential_key: credentialIdentity(updated), payload: JSON.stringify(draft)
      };
      this.requireUnlocked();
      const rows: number = await store.update(values, new relationalStore.RdbPredicates(TABLE).equalTo('id', id));
      if (rows !== 1) {
        throw new OtpError(OtpErrorCode.NOT_FOUND);
      }
      return updated;
    });
  }

  remove(id: string): Promise<void> {
    return this.enqueue(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await this.database();
      this.requireUnlocked();
      const rows: number = await store.delete(new relationalStore.RdbPredicates(TABLE).equalTo('id', id));
      if (rows !== 1) {
        throw new OtpError(OtpErrorCode.NOT_FOUND);
      }
    });
  }

  close(): Promise<void> {
    return this.enqueue(async (): Promise<void> => {
      const previous: relationalStore.RdbStore | undefined = this.store;
      this.store = undefined;
      if (previous !== undefined) {
        await previous.close();
      }
    });
  }
}

let repository: EncryptedOtpRepository | undefined = undefined;
export function getOtpRepository(context: common.Context): OtpRepository {
  if (repository === undefined) {
    repository = new EncryptedOtpRepository(context);
  }
  return repository;
}
