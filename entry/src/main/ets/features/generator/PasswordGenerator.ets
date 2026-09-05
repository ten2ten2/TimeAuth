import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { GeneratorOptions, PasswordResult, generatePasswordFromSource } from './GeneratorCore';

export function generatePassword(options: GeneratorOptions): PasswordResult {
  try {
    // Use the system CSPRNG, with no application seed or insecure fallback.
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    return generatePasswordFromSource(options, (length: number): Uint8Array => {
      return random.generateRandomSync(length).data;
    });
  } catch (error) {
    throw new Error('Secure password generation failed.');
  }
}
