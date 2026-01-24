package cache

import (
	"context"
	"crypto/tls"
	"fmt"

	"github.com/go-redis/redis/v8"
)

// InitializeRedis creates and returns a new Redis client
func InitializeRedis(host, port, password string, db int) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", host, port),
		Password: password,
		DB:       db,
		PoolSize: 10, // Connection pool size
		// Enable TLS for Upstash and other cloud Redis providers
		TLSConfig: &tls.Config{
			MinVersion: tls.VersionTLS12,
		},
	})

	// Test the connection
	ctx := context.Background()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return client, nil
}
