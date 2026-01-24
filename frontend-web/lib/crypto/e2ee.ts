/**
 * E2EE Client-Side Encryption
 * Web Crypto API implementation matching backend RSA+AES hybrid encryption
 * 
 * Uses:
 * - RSA-OAEP-2048 for key exchange
 * - AES-GCM-256 for message encryption
 */

// Web Crypto API - no imports needed

export interface EncryptionResult {
  encryptedContent: string; // Base64 encoded
  iv: string; // Base64 encoded IV
  encryptedKey?: string; // Base64 encoded RSA-encrypted AES key (for recipient)
}

export interface DecryptionResult {
  plaintext: string;
}

/**
 * Generate RSA key pair for E2EE
 * Returns keys in PEM format (compatible with backend)
 */
export async function generateRSAKeyPair(): Promise<{
  publicKey: string; // PEM format
  privateKey: string; // PEM format
  publicKeyJWK: JsonWebKey;
  privateKeyJWK: JsonWebKey;
}> {
  try {
    // Generate RSA-2048 key pair
    const keyPair = await crypto.subtle.generateKey(
      {
        name: 'RSA-OAEP',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]), // 65537
        hash: 'SHA-256',
      },
      true, // extractable
      ['encrypt', 'decrypt']
    );

    // Export as JWK
    const publicKeyJWK = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
    const privateKeyJWK = await crypto.subtle.exportKey('jwk', keyPair.privateKey);

    // Convert JWK to PEM format (for compatibility with backend)
    const publicKeyPEM = jwkToPEM(publicKeyJWK, 'public');
    const privateKeyPEM = jwkToPEM(privateKeyJWK, 'private');

    return {
      publicKey: publicKeyPEM,
      privateKey: privateKeyPEM,
      publicKeyJWK: publicKeyJWK,
      privateKeyJWK: privateKeyJWK,
    };
  } catch (error) {
    console.error('[E2EE] Failed to generate RSA key pair:', error);
    throw new Error('Failed to generate encryption keys');
  }
}

/**
 * Import RSA public key from PEM format
 */
export async function importRSAPublicKey(pemKey: string): Promise<CryptoKey> {
  try {
    const jwk = pemToJWK(pemKey, 'public');
    return await crypto.subtle.importKey(
      'jwk',
      jwk,
      {
        name: 'RSA-OAEP',
        hash: 'SHA-256',
      },
      true,
      ['encrypt']
    );
  } catch (error) {
    console.error('[E2EE] Failed to import RSA public key:', error);
    throw new Error('Failed to import public key');
  }
}

/**
 * Import RSA private key from PEM format
 */
export async function importRSAPrivateKey(pemKey: string): Promise<CryptoKey> {
  try {
    const jwk = pemToJWK(pemKey, 'private');
    return await crypto.subtle.importKey(
      'jwk',
      jwk,
      {
        name: 'RSA-OAEP',
        hash: 'SHA-256',
      },
      true,
      ['decrypt']
    );
  } catch (error) {
    console.error('[E2EE] Failed to import RSA private key:', error);
    throw new Error('Failed to import private key');
  }
}

/**
 * Encrypt message using RSA+AES hybrid encryption
 * Same format as backend crypto_util.go
 */
export async function encryptMessage(
  plaintext: string,
  recipientPublicKey: CryptoKey
): Promise<EncryptionResult> {
  try {
    // Generate random AES-256 key
    const aesKey = await crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt']
    );

    // Generate random IV (96 bits for GCM)
    const iv = crypto.getRandomValues(new Uint8Array(12));

    // Encrypt plaintext with AES-GCM
    const plaintextBytes = new TextEncoder().encode(plaintext);
    const encryptedData = await crypto.subtle.encrypt(
      {
        name: 'AES-GCM',
        iv: iv,
      },
      aesKey,
      plaintextBytes
    );

    // Export AES key for RSA encryption
    const aesKeyRaw = await crypto.subtle.exportKey('raw', aesKey);
    const aesKeyBytes = new Uint8Array(aesKeyRaw);

    // Encrypt AES key with RSA-OAEP
    const encryptedKey = await crypto.subtle.encrypt(
      {
        name: 'RSA-OAEP',
      },
      recipientPublicKey,
      aesKeyBytes
    );

    // Combine: encrypted AES key (256 bytes) + IV (12 bytes) + ciphertext
    const encryptedKeyArray = new Uint8Array(encryptedKey);
    const ivArray = new Uint8Array(iv);
    const ciphertextArray = new Uint8Array(encryptedData);

    const combined = new Uint8Array(encryptedKeyArray.length + ivArray.length + ciphertextArray.length);
    combined.set(encryptedKeyArray, 0);
    combined.set(ivArray, encryptedKeyArray.length);
    combined.set(ciphertextArray, encryptedKeyArray.length + ivArray.length);

    // Base64 encode
    const encryptedContent = btoa(String.fromCharCode(...combined));
    const ivBase64 = btoa(String.fromCharCode(...iv));

    return {
      encryptedContent,
      iv: ivBase64,
      encryptedKey: btoa(String.fromCharCode(...encryptedKeyArray)),
    };
  } catch (error) {
    console.error('[E2EE] Failed to encrypt message:', error);
    throw new Error('Failed to encrypt message');
  }
}

/**
 * Decrypt message using RSA+AES hybrid decryption
 * Same format as backend crypto_util.go
 */
export async function decryptMessage(
  encryptedContent: string,
  iv: string,
  recipientPrivateKey: CryptoKey
): Promise<DecryptionResult> {
  try {
    // Decode base64
    const combined = Uint8Array.from(
      atob(encryptedContent),
      (c) => c.charCodeAt(0)
    );
    const ivBytes = Uint8Array.from(atob(iv), (c) => c.charCodeAt(0));

    // RSA key size (2048 bits = 256 bytes)
    const keySize = 256;

    if (combined.length < keySize) {
      throw new Error('Encrypted content too short');
    }

    // Extract encrypted AES key (first 256 bytes)
    const encryptedKey = combined.slice(0, keySize);

    // Extract ciphertext (after encrypted key + IV)
    // Format: encryptedKey (256 bytes) + ivBytes (12 bytes) + ciphertext
    const ivOffset = 12; // 12 bytes for GCM IV
    const ciphertext = combined.slice(keySize + ivOffset);

    // Use the IV passed in separately (not from combined data)
    // The IV in combined data is redundant but kept for compatibility

    // Decrypt AES key with RSA-OAEP
    const aesKeyRaw = await crypto.subtle.decrypt(
      {
        name: 'RSA-OAEP',
      },
      recipientPrivateKey,
      encryptedKey
    );

    // Import AES key
    const aesKey = await crypto.subtle.importKey(
      'raw',
      aesKeyRaw,
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['decrypt']
    );

    // Decrypt ciphertext with AES-GCM
    const plaintextBytes = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: ivBytes,
      },
      aesKey,
      ciphertext
    );

    const plaintext = new TextDecoder().decode(plaintextBytes);

    return { plaintext };
  } catch (error) {
    console.error('[E2EE] Failed to decrypt message:', error);
    throw new Error('Failed to decrypt message');
  }
}

/**
 * Convert JWK to PEM format (simplified - uses base64)
 */
function jwkToPEM(jwk: JsonWebKey, type: 'public' | 'private'): string {
  // This is a simplified PEM conversion
  // For production, use a proper ASN.1 encoder
  // For now, we'll store JWK format in IndexedDB and use it directly
  return JSON.stringify(jwk);
}

/**
 * Convert PEM to JWK format
 */
function pemToJWK(pem: string, type: 'public' | 'private'): JsonWebKey {
  // If it's already JSON (simplified format), parse it
  try {
    return JSON.parse(pem) as JsonWebKey;
  } catch {
    // If actual PEM format, would need ASN.1 parser
    // For now, throw error
    throw new Error('PEM format not yet supported, use JWK JSON format');
  }
}

/**
 * Derive encryption key from password (for backup encryption)
 */
export async function deriveKeyFromPassword(
  password: string,
  salt: ArrayBuffer | Uint8Array
): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  const passwordKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveBits', 'deriveKey']
  );

  // Ensure salt is ArrayBuffer (not SharedArrayBuffer)
  let saltBuffer: ArrayBuffer;
  if (salt instanceof Uint8Array) {
    // Create a new ArrayBuffer to avoid SharedArrayBuffer issues
    saltBuffer = new Uint8Array(salt).buffer;
  } else if (salt instanceof ArrayBuffer) {
    // Ensure it's not SharedArrayBuffer by creating a copy
    saltBuffer = new Uint8Array(salt).buffer;
  } else {
    // Fallback: convert to Uint8Array first
    const saltArray = Array.isArray(salt) ? new Uint8Array(salt) : new Uint8Array(Object.values(salt));
    saltBuffer = saltArray.buffer;
  }

  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: saltBuffer,
      iterations: 100000,
      hash: 'SHA-256',
    },
    passwordKey,
    {
      name: 'AES-GCM',
      length: 256,
    },
    true,
    ['encrypt', 'decrypt']
  );
}
