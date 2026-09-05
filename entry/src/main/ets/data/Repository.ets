import { VaultItem } from '../models/AppModels';

// Password vault remains a separate preview milestone. Authenticator uses OtpRepository.
export interface TimeAuthRepository {
  getVaultItems(): VaultItem[];
}
