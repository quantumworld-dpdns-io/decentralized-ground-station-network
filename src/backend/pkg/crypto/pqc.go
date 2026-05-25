package crypto

/*
#cgo LDFLAGS: -ldgsn_crypto -L/usr/local/lib
#cgo CFLAGS: -I/usr/local/include

#include <stdlib.h>
#include <stdint.h>

typedef struct {
    uint8_t* public_key;
    size_t public_key_len;
    uint8_t* secret_key;
    size_t secret_key_len;
} CryptoKeyPair;

typedef struct {
    uint8_t* data;
    size_t len;
} CryptoBuffer;

int crypto_init(void);
void crypto_shutdown(void);

// ML-KEM (Kyber) key encapsulation
CryptoKeyPair* crypto_kem_keypair_generate(const char* algorithm);
void crypto_kem_keypair_free(CryptoKeyPair* kp);

CryptoBuffer* crypto_kem_encapsulate(const uint8_t* public_key, size_t pk_len, const char* algorithm);
void crypto_kem_buffer_free(CryptoBuffer* buf);

CryptoBuffer* crypto_kem_decapsulate(const uint8_t* secret_key, size_t sk_len, 
                                       const uint8_t* ciphertext, size_t ct_len,
                                       const char* algorithm);

// Digital Signatures (ML-DSA / Falcon)
CryptoKeyPair* crypto_sign_keypair_generate(const char* algorithm);
void crypto_sign_keypair_free(CryptoKeyPair* kp);

CryptoBuffer* crypto_sign(const uint8_t* secret_key, size_t sk_len,
                           const uint8_t* message, size_t msg_len,
                           const char* algorithm);
void crypto_sign_buffer_free(CryptoBuffer* buf);

int crypto_sign_verify(const uint8_t* public_key, size_t pk_len,
                        const uint8_t* message, size_t msg_len,
                        const uint8_t* signature, size_t sig_len,
                        const char* algorithm);

// Hash functions
CryptoBuffer* crypto_hash(const uint8_t* data, size_t len, const char* algorithm);
void crypto_hash_buffer_free(CryptoBuffer* buf);

// Random bytes generation
int crypto_random_bytes(uint8_t* buf, size_t len);
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"unsafe"
)

var (
	ErrNotInitialized = errors.New("crypto kernel not initialized")
	ErrInvalidAlgorithm = errors.New("invalid algorithm")
	ErrKeyGeneration = errors.New("key generation failed")
	ErrSignFailed = errors.New("signing failed")
	ErrVerifyFailed = errors.New("verification failed")
	ErrEncapsulateFailed = errors.New("encapsulation failed")
	ErrDecapsulateFailed = errors.New("decapsulation failed")
)

type Algorithm string

const (
	// KEM Algorithms (Post-Quantum)
	AlgMLKEM512  Algorithm = "ML-KEM-512"
	AlgMLKEM768  Algorithm = "ML-KEM-768"
	AlgMLKEM1024 Algorithm = "ML-KEM-1024"
	
	// Signature Algorithms (Post-Quantum)
	AlgMLDSA44    Algorithm = "ML-DSA-44"
	AlgMLDSA65    Algorithm = "ML-DSA-65"
	AlgMLDSA87    Algorithm = "ML-DSA-87"
	AlgFalcon512  Algorithm = "Falcon-512"
	AlgFalcon1024 Algorithm = "Falcon-1024"
	
	// Hash Algorithms
	AlgSHA256    Algorithm = "SHA-256"
	AlgSHA384    Algorithm = "SHA-384"
	AlgSHA512    Algorithm = "SHA-512"
	AlgSHA3256   Algorithm = "SHA3-256"
	AlgSHA3512   Algorithm = "SHA3-512"
	AlgBLAKE2b   Algorithm = "BLAKE2b"
	AlgBLAKE3    Algorithm = "BLAKE3"
)

type KeyPair struct {
	PublicKey  []byte
	SecretKey  []byte
	Algorithm  Algorithm
}

type PQCClient struct {
	defaultKEMAlgo  Algorithm
	defaultSignAlgo Algorithm
	defaultHashAlgo Algorithm
	mu              sync.RWMutex
}

var globalClient *PQCClient
var initOnce sync.Once

func InitDefault(kernelPath string) error {
	var err error
	initOnce.Do(func() {
		result := C.crypto_init()
		if result != 0 {
			err = fmt.Errorf("crypto_init failed with code %d", result)
			return
		}
		globalClient = &PQCClient{
			defaultKEMAlgo:  AlgMLKEM768,
			defaultSignAlgo: AlgMLDSA65,
			defaultHashAlgo: AlgSHA256,
		}
	})
	return err
}

func Shutdown() {
	C.crypto_shutdown()
}

func DefaultClient() *PQCClient {
	return globalClient
}

func NewPQCClient(kemAlgo, signAlgo, hashAlgo Algorithm) (*PQCClient, error) {
	result := C.crypto_init()
	if result != 0 {
		return nil, fmt.Errorf("crypto_init failed with code %d", result)
	}

	return &PQCClient{
		defaultKEMAlgo:  kemAlgo,
		defaultSignAlgo: signAlgo,
		defaultHashAlgo: hashAlgo,
	}, nil
}

func (c *PQCClient) GenerateKEMKeyPair(ctx context.Context, algo ...Algorithm) (*KeyPair, error) {
	algorithm := c.defaultKEMAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	kp := C.crypto_kem_keypair_generate(algoStr)
	if kp == nil {
		return nil, ErrKeyGeneration
	}
	defer C.crypto_kem_keypair_free(kp)

	keyPair := &KeyPair{
		Algorithm:  algorithm,
		PublicKey:  C.GoBytes(unsafe.Pointer(kp.public_key), C.int(kp.public_key_len)),
		SecretKey:  C.GoBytes(unsafe.Pointer(kp.secret_key), C.int(kp.secret_key_len)),
	}

	return keyPair, nil
}

func (c *PQCClient) Encapsulate(ctx context.Context, publicKey []byte, algo ...Algorithm) (ciphertext, sharedSecret []byte, err error) {
	algorithm := c.defaultKEMAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	if len(publicKey) == 0 {
		return nil, nil, errors.New("public key is empty")
	}

	pkPtr := (*C.uint8_t)(unsafe.Pointer(&publicKey[0]))
	pkLen := C.size_t(len(publicKey))
	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	buf := C.crypto_kem_encapsulate(pkPtr, pkLen, algoStr)
	if buf == nil {
		return nil, nil, ErrEncapsulateFailed
	}
	defer C.crypto_kem_buffer_free(buf)

	data := C.GoBytes(unsafe.Pointer(buf.data), C.int(buf.len))

	ctLen := len(data) / 2
	ciphertext = data[:ctLen]
	sharedSecret = data[ctLen:]

	return ciphertext, sharedSecret, nil
}

func (c *PQCClient) Decapsulate(ctx context.Context, secretKey, ciphertext []byte, algo ...Algorithm) (sharedSecret []byte, err error) {
	algorithm := c.defaultKEMAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	if len(secretKey) == 0 {
		return nil, errors.New("secret key is empty")
	}
	if len(ciphertext) == 0 {
		return nil, errors.New("ciphertext is empty")
	}

	skPtr := (*C.uint8_t)(unsafe.Pointer(&secretKey[0]))
	skLen := C.size_t(len(secretKey))
	ctPtr := (*C.uint8_t)(unsafe.Pointer(&ciphertext[0]))
	ctLen := C.size_t(len(ciphertext))
	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	buf := C.crypto_kem_decapsulate(skPtr, skLen, ctPtr, ctLen, algoStr)
	if buf == nil {
		return nil, ErrDecapsulateFailed
	}
	defer C.crypto_kem_buffer_free(buf)

	return C.GoBytes(unsafe.Pointer(buf.data), C.int(buf.len)), nil
}

func (c *PQCClient) GenerateSignKeyPair(ctx context.Context, algo ...Algorithm) (*KeyPair, error) {
	algorithm := c.defaultSignAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	kp := C.crypto_sign_keypair_generate(algoStr)
	if kp == nil {
		return nil, ErrKeyGeneration
	}
	defer C.crypto_sign_keypair_free(kp)

	keyPair := &KeyPair{
		Algorithm:  algorithm,
		PublicKey:  C.GoBytes(unsafe.Pointer(kp.public_key), C.int(kp.public_key_len)),
		SecretKey:  C.GoBytes(unsafe.Pointer(kp.secret_key), C.int(kp.secret_key_len)),
	}

	return keyPair, nil
}

func (c *PQCClient) Sign(ctx context.Context, secretKey, message []byte, algo ...Algorithm) ([]byte, error) {
	algorithm := c.defaultSignAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	if len(secretKey) == 0 {
		return nil, errors.New("secret key is empty")
	}
	if len(message) == 0 {
		return nil, errors.New("message is empty")
	}

	skPtr := (*C.uint8_t)(unsafe.Pointer(&secretKey[0]))
	skLen := C.size_t(len(secretKey))
	msgPtr := (*C.uint8_t)(unsafe.Pointer(&message[0]))
	msgLen := C.size_t(len(message))
	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	buf := C.crypto_sign(skPtr, skLen, msgPtr, msgLen, algoStr)
	if buf == nil {
		return nil, ErrSignFailed
	}
	defer C.crypto_sign_buffer_free(buf)

	return C.GoBytes(unsafe.Pointer(buf.data), C.int(buf.len)), nil
}

func (c *PQCClient) Verify(ctx context.Context, publicKey, message, signature []byte, algo ...Algorithm) (bool, error) {
	algorithm := c.defaultSignAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	if len(publicKey) == 0 {
		return false, errors.New("public key is empty")
	}
	if len(message) == 0 {
		return false, errors.New("message is empty")
	}
	if len(signature) == 0 {
		return false, errors.New("signature is empty")
	}

	pkPtr := (*C.uint8_t)(unsafe.Pointer(&publicKey[0]))
	pkLen := C.size_t(len(publicKey))
	msgPtr := (*C.uint8_t)(unsafe.Pointer(&message[0]))
	msgLen := C.size_t(len(message))
	sigPtr := (*C.uint8_t)(unsafe.Pointer(&signature[0]))
	sigLen := C.size_t(len(signature))
	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	result := C.crypto_sign_verify(pkPtr, pkLen, msgPtr, msgLen, sigPtr, sigLen, algoStr)
	return result == 0, nil
}

func (c *PQCClient) Hash(ctx context.Context, data []byte, algo ...Algorithm) ([]byte, error) {
	algorithm := c.defaultHashAlgo
	if len(algo) > 0 {
		algorithm = algo[0]
	}

	if len(data) == 0 {
		return nil, errors.New("data is empty")
	}

	dataPtr := (*C.uint8_t)(unsafe.Pointer(&data[0]))
	dataLen := C.size_t(len(data))
	algoStr := C.CString(string(algorithm))
	defer C.free(unsafe.Pointer(algoStr))

	buf := C.crypto_hash(dataPtr, dataLen, algoStr)
	if buf == nil {
		return nil, errors.New("hash failed")
	}
	defer C.crypto_hash_buffer_free(buf)

	return C.GoBytes(unsafe.Pointer(buf.data), C.int(buf.len)), nil
}

func (c *PQCClient) RandomBytes(ctx context.Context, length int) ([]byte, error) {
	if length <= 0 {
		return nil, errors.New("invalid length")
	}

	buf := make([]byte, length)
	bufPtr := (*C.uint8_t)(unsafe.Pointer(&buf[0]))
	bufLen := C.size_t(length)

	result := C.crypto_random_bytes(bufPtr, bufLen)
	if result != 0 {
		return nil, errors.New("random bytes generation failed")
	}

	return buf, nil
}
