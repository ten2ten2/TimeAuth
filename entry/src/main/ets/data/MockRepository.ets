import { OtpItem, OtpKind, VaultItem, VaultItemKind } from '../models/AppModels';
import { TimeAuthRepository } from './Repository';

export class MockTimeAuthRepository implements TimeAuthRepository {
  getOtpItems(): OtpItem[] {
    return [
      {
        id: 'otp-github',
        issuer: 'GitHub',
        account: 'demo@timeauth.app',
        code: '248 193',
        remainingSeconds: 22,
        periodSeconds: 30,
        kind: OtpKind.TOTP,
        accentColor: '#24292F',
        isFavorite: true
      },
      {
        id: 'otp-microsoft',
        issuer: 'Microsoft',
        account: 'demo@outlook.com',
        code: '735 420',
        remainingSeconds: 11,
        periodSeconds: 30,
        kind: OtpKind.TOTP,
        accentColor: '#0067B8',
        isFavorite: false
      },
      {
        id: 'otp-steam',
        issuer: 'Steam',
        account: 'TimeAuthDemo',
        code: 'R9K4Q',
        remainingSeconds: 4,
        periodSeconds: 30,
        kind: OtpKind.STEAM,
        accentColor: '#1B2838',
        isFavorite: false
      }
    ];
  }

  getVaultItems(): VaultItem[] {
    return [
      {
        id: 'vault-github',
        title: 'GitHub',
        username: 'demo@timeauth.app',
        website: 'github.com',
        passwordPreview: 'Demo-Only-2026!',
        kind: VaultItemKind.LOGIN,
        accentColor: '#24292F',
        isFavorite: true,
        linkedOtpIssuer: 'GitHub'
      },
      {
        id: 'vault-email',
        title: 'Work email',
        username: 'demo@company.example',
        website: 'mail.example.com',
        passwordPreview: 'Preview-Not-A-Secret',
        kind: VaultItemKind.LOGIN,
        accentColor: '#2768D9',
        isFavorite: false
      },
      {
        id: 'vault-recovery',
        title: 'Recovery codes (demo)',
        username: '8 items',
        website: '',
        passwordPreview: '',
        kind: VaultItemKind.SECURE_NOTE,
        accentColor: '#197A4A',
        isFavorite: false
      }
    ];
  }
}

export const mockRepository: TimeAuthRepository = new MockTimeAuthRepository();
