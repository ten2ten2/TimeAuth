import { OtpItem, OtpKind, VaultItem, VaultItemKind } from '../models/AppModels';
import { TimeAuthRepository } from './Repository';

export class MockTimeAuthRepository implements TimeAuthRepository {
  getOtpItems(): OtpItem[] {
    return [
      { id: 'otp-alibaba-cloud', issuer: '阿里云', account: 'demo@aliyun.com', code: '184 027', remainingSeconds: 27, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#FF6A00', isFavorite: true },
      { id: 'otp-tencent-cloud', issuer: '腾讯云', account: 'demo@qq.com', code: '592 314', remainingSeconds: 25, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#0052D9', isFavorite: false },
      { id: 'otp-huawei-cloud', issuer: '华为云', account: 'demo@huawei.com', code: '731 805', remainingSeconds: 23, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#CF0A2C', isFavorite: false },
      { id: 'otp-baidu-ai-cloud', issuer: '百度智能云', account: 'demo@baidu.com', code: '405 269', remainingSeconds: 21, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#2932E1', isFavorite: false },
      { id: 'otp-volcano-engine', issuer: '火山引擎', account: 'demo@volcengine.com', code: '823 146', remainingSeconds: 19, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#1664FF', isFavorite: false },
      { id: 'otp-google', issuer: 'Google', account: 'demo@gmail.com', code: '248 193', remainingSeconds: 18, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#4285F4', isFavorite: true },
      { id: 'otp-microsoft', issuer: 'Microsoft', account: 'demo@outlook.com', code: '735 420', remainingSeconds: 17, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#5E5E5E', isFavorite: false },
      { id: 'otp-github', issuer: 'GitHub', account: 'demo@timeauth.app', code: '610 284', remainingSeconds: 16, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#24292F', isFavorite: true },
      { id: 'otp-apple', issuer: 'Apple', account: 'demo@icloud.com', code: '903 571', remainingSeconds: 15, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#111111', isFavorite: false },
      { id: 'otp-aws', issuer: 'AWS', account: 'demo@example.com', code: '367 925', remainingSeconds: 14, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#232F3E', isFavorite: false },
      { id: 'otp-cloudflare', issuer: 'Cloudflare', account: 'admin@example.com', code: '802 491', remainingSeconds: 13, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#F38020', isFavorite: false },
      { id: 'otp-steam', issuer: 'Steam', account: 'TimeAuthDemo', code: 'R9K4Q', remainingSeconds: 12, periodSeconds: 30, kind: OtpKind.STEAM, accentColor: '#1B2838', isFavorite: false },
      { id: 'otp-discord', issuer: 'Discord', account: 'demo#0001', code: '126 738', remainingSeconds: 11, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#5865F2', isFavorite: false },
      { id: 'otp-dropbox', issuer: 'Dropbox', account: 'demo@example.com', code: '574 208', remainingSeconds: 10, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#0061FF', isFavorite: false },
      { id: 'otp-slack', issuer: 'Slack', account: 'demo@workspace.com', code: '341 962', remainingSeconds: 9, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#611F69', isFavorite: false },
      { id: 'otp-bitwarden', issuer: 'Bitwarden', account: 'demo@example.com', code: '714 350', remainingSeconds: 8, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#175DDC', isFavorite: false },
      { id: 'otp-1password', issuer: '1Password', account: 'demo@example.com', code: '452 681', remainingSeconds: 7, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#0572EC', isFavorite: false },
      { id: 'otp-gitlab', issuer: 'GitLab', account: 'demo@example.com', code: '089 437', remainingSeconds: 6, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#FC6D26', isFavorite: false },
      { id: 'otp-proton', issuer: 'Proton', account: 'demo@proton.me', code: '268 519', remainingSeconds: 5, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#6D4AFF', isFavorite: false },
      { id: 'otp-openai', issuer: 'OpenAI', account: 'demo@example.com', code: '946 073', remainingSeconds: 4, periodSeconds: 30, kind: OtpKind.TOTP, accentColor: '#10A37F', isFavorite: false }
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
