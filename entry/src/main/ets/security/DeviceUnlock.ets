import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { userAuth } from '@kit.UserAuthenticationKit';

// Uses the system widget only; the app never receives a lock-screen password or biometric template.
export class DeviceUnlock {
  private instance: userAuth.UserAuthInstance | undefined = undefined;
  private callback: userAuth.IAuthCallback | undefined = undefined;
  private finish: ((success: boolean) => void) | undefined = undefined;
  private timeout: number = -1;

  verify(title: string): Promise<boolean> {
    this.cancel();
    return new Promise<boolean>((resolve) => {
      let completed: boolean = false;
      const finish: (success: boolean) => void = (success: boolean): void => {
        if (completed) { return; }
        completed = true;
        this.finish = undefined;
        if (this.timeout >= 0) {
          clearTimeout(this.timeout);
          this.timeout = -1;
        }
        if (this.instance !== undefined && this.callback !== undefined) {
          try { this.instance.off('result', this.callback); } catch {}
        }
        this.instance = undefined;
        this.callback = undefined;
        resolve(success);
      };
      this.finish = finish;
      try {
        const types: userAuth.UserAuthType[] = [];
        const candidates: userAuth.UserAuthType[] = [
          userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.FACE, userAuth.UserAuthType.PIN
        ];
        for (let i: number = 0; i < candidates.length; i++) {
          try {
            userAuth.getAvailableStatus(candidates[i], userAuth.AuthTrustLevel.ATL2);
            types.push(candidates[i]);
          } catch {}
        }
        if (types.length === 0) { finish(false); return; }
        const params: userAuth.AuthParam = {
          challenge: cryptoFramework.createRandom().generateRandomSync(32).data,
          authType: types, authTrustLevel: userAuth.AuthTrustLevel.ATL2
        };
        this.instance = userAuth.getUserAuthInstance(params, { title: title });
        this.callback = {
          onResult: (result: userAuth.UserAuthResult): void => {
            finish(result.result === userAuth.UserAuthResultCode.SUCCESS);
          }
        };
        this.instance.on('result', this.callback);
        this.timeout = setTimeout(() => { this.cancel(); }, 90000);
        this.instance.start();
      } catch {
        finish(false);
      }
    });
  }

  cancel(): void {
    const instance: userAuth.UserAuthInstance | undefined = this.instance;
    const finish: ((success: boolean) => void) | undefined = this.finish;
    if (finish !== undefined) { finish(false); }
    if (instance !== undefined) {
      try { instance.cancel(); } catch {}
    }
  }
}
