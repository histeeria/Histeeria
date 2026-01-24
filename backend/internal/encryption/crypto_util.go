package encryption

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
)

// ============================================
// RSA+AES HYBRID ENCRYPTION
// ============================================

// EncryptMessage encrypts a message using RSA+AES hybrid encryption
// RSA encrypts the AES key, AES encrypts the message content
func EncryptMessage(plaintext string, recipientPublicKey *rsa.PublicKey) (encryptedContent string, iv string, err error) {
	// Generate random AES-256 key
	aesKey := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, aesKey); err != nil {
		return "", "", fmt.Errorf("failed to generate AES key: %w", err)
	}

	// Generate random IV for AES
	ivBytes := make([]byte, aes.BlockSize)
	if _, err := io.ReadFull(rand.Reader, ivBytes); err != nil {
		return "", "", fmt.Errorf("failed to generate IV: %w", err)
	}

	// Encrypt plaintext with AES-GCM
	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", "", fmt.Errorf("failed to create AES cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", "", fmt.Errorf("failed to create GCM: %w", err)
	}

	ciphertext := gcm.Seal(nil, ivBytes, []byte(plaintext), nil)

	// Encrypt AES key with RSA-OAEP
	encryptedKey, err := rsa.EncryptOAEP(
		sha256.New(),
		rand.Reader,
		recipientPublicKey,
		aesKey,
		nil,
	)
	if err != nil {
		return "", "", fmt.Errorf("failed to encrypt AES key: %w", err)
	}

	// Combine encrypted key + IV + ciphertext (base64 encoded)
	combined := append(encryptedKey, ivBytes...)
	combined = append(combined, ciphertext...)

	return base64.StdEncoding.EncodeToString(combined), base64.StdEncoding.EncodeToString(ivBytes), nil
}

// DecryptMessage decrypts a message using RSA+AES hybrid decryption
func DecryptMessage(encryptedContent string, iv string, recipientPrivateKey *rsa.PrivateKey) (plaintext string, err error) {
	// Decode base64
	combined, err := base64.StdEncoding.DecodeString(encryptedContent)
	if err != nil {
		return "", fmt.Errorf("failed to decode encrypted content: %w", err)
	}

	ivBytes, err := base64.StdEncoding.DecodeString(iv)
	if err != nil {
		return "", fmt.Errorf("failed to decode IV: %w", err)
	}

	// RSA key size (e.g., 2048 bits = 256 bytes)
	keySize := recipientPrivateKey.Size()

	if len(combined) < keySize {
		return "", fmt.Errorf("encrypted content too short")
	}

	// Extract encrypted AES key (first keySize bytes)
	encryptedKey := combined[:keySize]

	// Extract ciphertext (rest of bytes)
	ciphertext := combined[keySize:]

	// Decrypt AES key with RSA-OAEP
	aesKey, err := rsa.DecryptOAEP(
		sha256.New(),
		rand.Reader,
		recipientPrivateKey,
		encryptedKey,
		nil,
	)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt AES key: %w", err)
	}

	// Decrypt ciphertext with AES-GCM
	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", fmt.Errorf("failed to create AES cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	plaintextBytes, err := gcm.Open(nil, ivBytes, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt message: %w", err)
	}

	return string(plaintextBytes), nil
}

// ============================================
// PROFILE FIELD ENCRYPTION
// ============================================

// EncryptProfileField encrypts a profile field (display name, email, etc.)
// Uses AES-GCM with a user-specific encryption key
func EncryptProfileField(plaintext string, userEncryptionKey []byte) (encrypted string, iv string, err error) {
	if len(userEncryptionKey) != 32 {
		return "", "", fmt.Errorf("encryption key must be 32 bytes (AES-256)")
	}

	// Generate random IV
	ivBytes := make([]byte, aes.BlockSize)
	if _, err := io.ReadFull(rand.Reader, ivBytes); err != nil {
		return "", "", fmt.Errorf("failed to generate IV: %w", err)
	}

	// Encrypt with AES-GCM
	block, err := aes.NewCipher(userEncryptionKey)
	if err != nil {
		return "", "", fmt.Errorf("failed to create AES cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", "", fmt.Errorf("failed to create GCM: %w", err)
	}

	ciphertext := gcm.Seal(nil, ivBytes, []byte(plaintext), nil)

	return base64.StdEncoding.EncodeToString(ciphertext), base64.StdEncoding.EncodeToString(ivBytes), nil
}

// DecryptProfileField decrypts a profile field
func DecryptProfileField(encrypted string, iv string, userEncryptionKey []byte) (plaintext string, err error) {
	if len(userEncryptionKey) != 32 {
		return "", fmt.Errorf("encryption key must be 32 bytes (AES-256)")
	}

	// Decode base64
	ciphertext, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", fmt.Errorf("failed to decode encrypted content: %w", err)
	}

	ivBytes, err := base64.StdEncoding.DecodeString(iv)
	if err != nil {
		return "", fmt.Errorf("failed to decode IV: %w", err)
	}

	// Decrypt with AES-GCM
	block, err := aes.NewCipher(userEncryptionKey)
	if err != nil {
		return "", fmt.Errorf("failed to create AES cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	plaintextBytes, err := gcm.Open(nil, ivBytes, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt profile field: %w", err)
	}

	return string(plaintextBytes), nil
}

// ============================================
// RSA KEY UTILITIES
// ============================================

// ParseRSAPublicKey parses a PEM-encoded RSA public key
func ParseRSAPublicKey(pemData []byte) (*rsa.PublicKey, error) {
	block, _ := pem.Decode(pemData)
	if block == nil {
		return nil, errors.New("failed to parse PEM block")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse public key: %w", err)
	}

	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return nil, errors.New("not an RSA public key")
	}

	return rsaPub, nil
}

// ParseRSAPublicKeyFromBase64 parses a base64-encoded RSA public key
func ParseRSAPublicKeyFromBase64(base64Key string) (*rsa.PublicKey, error) {
	keyBytes, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return nil, fmt.Errorf("failed to decode base64 key: %w", err)
	}

	return ParseRSAPublicKey(keyBytes)
}

// ParseRSAPrivateKey parses a PEM-encoded RSA private key
func ParseRSAPrivateKey(pemData []byte) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode(pemData)
	if block == nil {
		return nil, errors.New("failed to parse PEM block")
	}

	priv, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		// Try PKCS1 format
		priv, err = x509.ParsePKCS1PrivateKey(block.Bytes)
		if err != nil {
			return nil, fmt.Errorf("failed to parse private key: %w", err)
		}
	}

	rsaPriv, ok := priv.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("not an RSA private key")
	}

	return rsaPriv, nil
}

// ParseRSAPrivateKeyFromBase64 parses a base64-encoded RSA private key
func ParseRSAPrivateKeyFromBase64(base64Key string) (*rsa.PrivateKey, error) {
	keyBytes, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil {
		return nil, fmt.Errorf("failed to decode base64 key: %w", err)
	}

	return ParseRSAPrivateKey(keyBytes)
}

// EncodeRSAPublicKeyToBase64 encodes an RSA public key to base64 PEM format
func EncodeRSAPublicKeyToBase64(pubKey *rsa.PublicKey) (string, error) {
	pubBytes, err := x509.MarshalPKIXPublicKey(pubKey)
	if err != nil {
		return "", fmt.Errorf("failed to marshal public key: %w", err)
	}

	pemBlock := &pem.Block{
		Type:  "PUBLIC KEY",
		Bytes: pubBytes,
	}

	pemBytes := pem.EncodeToMemory(pemBlock)
	return base64.StdEncoding.EncodeToString(pemBytes), nil
}

// EncodeRSAPrivateKeyToBase64 encodes an RSA private key to base64 PEM format
func EncodeRSAPrivateKeyToBase64(privKey *rsa.PrivateKey) (string, error) {
	privBytes, err := x509.MarshalPKCS8PrivateKey(privKey)
	if err != nil {
		return "", fmt.Errorf("failed to marshal private key: %w", err)
	}

	pemBlock := &pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: privBytes,
	}

	pemBytes := pem.EncodeToMemory(pemBlock)
	return base64.StdEncoding.EncodeToString(pemBytes), nil
}

// ============================================
// ENCRYPTION KEY GENERATION
// ============================================

// GenerateUserEncryptionKey generates a random 32-byte key for profile field encryption
func GenerateUserEncryptionKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, fmt.Errorf("failed to generate encryption key: %w", err)
	}
	return key, nil
}

// ============================================
// SIMPLIFIED E2EE (For Quick Implementation)
// ============================================

// EncryptMessageSimple encrypts a message using recipient's public key (simplified)
// Returns encrypted content and IV separately for database storage
func EncryptMessageSimple(plaintext string, recipientPublicKeyBase64 string) (encryptedContent string, iv string, err error) {
	// Parse public key
	pubKey, err := ParseRSAPublicKeyFromBase64(recipientPublicKeyBase64)
	if err != nil {
		return "", "", fmt.Errorf("failed to parse public key: %w", err)
	}

	return EncryptMessage(plaintext, pubKey)
}

// DecryptMessageSimple decrypts a message using recipient's private key (simplified)
func DecryptMessageSimple(encryptedContent string, iv string, recipientPrivateKeyBase64 string) (plaintext string, err error) {
	// Parse private key
	privKey, err := ParseRSAPrivateKeyFromBase64(recipientPrivateKeyBase64)
	if err != nil {
		return "", fmt.Errorf("failed to parse private key: %w", err)
	}

	return DecryptMessage(encryptedContent, iv, privKey)
}
