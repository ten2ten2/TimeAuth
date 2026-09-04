import { OtpItem, VaultItem } from '../models/AppModels';

export interface TimeAuthRepository {
  getOtpItems(): OtpItem[];
  getVaultItems(): VaultItem[];
}

