import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { counterBytes, decodeBase32, OtpDraft, OtpError, OtpErrorCode, truncateOtp } from './OtpCore';

export interface OtpCodeProvider {
  generate(account: OtpDraft, counter: number): Promise<string>;
}

export class NativeOtpCrypto implements OtpCodeProvider {
  async generate(account: OtpDraft, counter: number): Promise<string> {
    const bytes: Uint8Array = decodeBase32(account.secret);
    let key: cryptoFramework.SymKey | undefined = undefined;
    let digest: cryptoFramework.DataBlob | undefined = undefined;
    try {
      // HMAC (without a fixed hash suffix) accepts variable-length provisioning keys.
      // SHA1 is retained for RFC 6238 interoperability, not used for password hashing.
      key = await cryptoFramework.createSymKeyGenerator('HMAC').convertKey({ data: bytes });
      const mac: cryptoFramework.Mac = cryptoFramework.createMac(account.algorithm);
      await mac.init(key);
      await mac.update({ data: counterBytes(counter) });
      digest = await mac.doFinal();
      return truncateOtp(digest.data, account.kind, account.digits);
    } catch {
      throw new OtpError(OtpErrorCode.CRYPTO);
    } finally {
      bytes.fill(0);
      if (digest !== undefined) {
        digest.data.fill(0);
      }
      if (key !== undefined) {
        key.clearMem();
      }
    }
  }
}

export function newOtpId(): string {
  const bytes: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
  let result: string = '';
  for (let i: number = 0; i < bytes.length; i++) {
    result += bytes[i].toString(16).padStart(2, '0');
  }
  bytes.fill(0);
  return result;
}
