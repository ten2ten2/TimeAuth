import { VaultItem, VaultItemKind } from '../models/AppModels';
import { TimeAuthRepository } from './Repository';

// Preview data is limited to Password Vault. No authenticator accounts are seeded.
export class MockTimeAuthRepository implements TimeAuthRepository {
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
