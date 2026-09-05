import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import {
  GeneratorFailure, GeneratorOptions, PasswordGenerationError, PasswordResult, generatePasswordFromSource
} from './GeneratorCore';

export function generatePassword(options: GeneratorOptions): PasswordResult {
  let failure: GeneratorFailure = GeneratorFailure.UNAVAILABLE;
  try {
    // API 12+ exposes random generation through the dedicated Rand capability.
    if (canIUse('SystemCapability.Security.CryptoFramework.Rand')) {
      const random: cryptoFramework.Random = cryptoFramework.createRandom();
      return generatePasswordFromSource(options, (length: number): Uint8Array => {
        // Keep the check in the callback's scope for the SDK's SysCap analysis.
        if (canIUse('SystemCapability.Security.CryptoFramework.Rand')) {
          return random.generateRandomSync(length).data;
        }
        failure = GeneratorFailure.UNSUPPORTED;
        throw new Error('Secure password generation failed.');
      });
    }
    // Never substitute a noncryptographic source on unsupported devices.
    failure = GeneratorFailure.UNSUPPORTED;
  } catch (_) {
    // A thrown capability query or provider call does not prove a missing capability.
    // Discard exception details; only an explicit false is classified as unsupported.
  }
  throw new PasswordGenerationError(failure);
}
