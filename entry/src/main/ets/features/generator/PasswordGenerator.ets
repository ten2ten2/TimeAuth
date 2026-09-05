import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { GeneratorOptions, PasswordResult, generatePasswordFromSource } from './GeneratorCore';

export function generatePassword(options: GeneratorOptions): PasswordResult {
  try {
    // API 12+ exposes random generation through the dedicated Rand capability.
    if (canIUse('SystemCapability.Security.CryptoFramework.Rand')) {
      const random: cryptoFramework.Random = cryptoFramework.createRandom();
      return generatePasswordFromSource(options, (length: number): Uint8Array => {
        // Keep the check in the callback's scope for the SDK's SysCap analysis.
        if (canIUse('SystemCapability.Security.CryptoFramework.Rand')) {
          return random.generateRandomSync(length).data;
        }
        throw new Error('Secure password generation failed.');
      });
    }
    // Never substitute a noncryptographic source on unsupported devices.
    throw new Error('Secure password generation failed.');
  } catch (error) {
    throw new Error('Secure password generation failed.');
  }
}
