package config

import (
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"github.com/spf13/viper"
)

// Config holds all configuration for our application
type Config struct {
	Database  DatabaseConfig  `mapstructure:"database"`
	JWT       JWTConfig       `mapstructure:"jwt"`
	Email     EmailConfig     `mapstructure:"email"`
	Server    ServerConfig    `mapstructure:"server"`
	RateLimit RateLimitConfig `mapstructure:"rate_limit"`
	Google    GoogleConfig    `mapstructure:"google"`
	GitHub    GitHubConfig    `mapstructure:"github"`
	LinkedIn  LinkedInConfig  `mapstructure:"linkedin"`
	Storage   StorageConfig   `mapstructure:"storage"`
	Redis     RedisConfig     `mapstructure:"redis"`
	R2        R2Config        `mapstructure:"r2"`
	Logging   LoggingConfig   `mapstructure:"logging"`
}

// R2Config holds Cloudflare R2 storage configuration
// R2 free tier: 10GB storage, 10M Class A ops, 1M Class B ops, 0 egress!
type R2Config struct {
	AccountID       string `mapstructure:"account_id"`
	AccessKeyID     string `mapstructure:"access_key_id"`
	SecretAccessKey string `mapstructure:"secret_access_key"`
	BucketName      string `mapstructure:"bucket_name"`
	PublicURL       string `mapstructure:"public_url"`
	Enabled         bool   `mapstructure:"enabled"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level  string `mapstructure:"level"`  // debug, info, warn, error
	Format string `mapstructure:"format"` // json, text
}

type DatabaseConfig struct {
	SupabaseURL        string `mapstructure:"supabase_url"`
	SupabaseAnonKey    string `mapstructure:"supabase_anon_key"`
	SupabaseServiceKey string `mapstructure:"supabase_service_role_key"`
}

type StorageConfig struct {
	BucketName       string `mapstructure:"bucket_name"`
	MaxFileSize      int64  `mapstructure:"max_file_size"`
	AllowedFileTypes string `mapstructure:"allowed_file_types"`
}

type JWTConfig struct {
	Secret        string `mapstructure:"secret"`
	Expiry        string `mapstructure:"expiry"`
	RefreshExpiry string `mapstructure:"refresh_expiry"`
}

type EmailConfig struct {
	Host        string `mapstructure:"host"`
	Port        int    `mapstructure:"port"`
	Username    string `mapstructure:"username"`
	Password    string `mapstructure:"password"`
	FromName    string `mapstructure:"from_name"`
	FromEmail   string `mapstructure:"from_email"`
	FrontendURL string `mapstructure:"frontend_url"`
}

type ServerConfig struct {
	Port               string `mapstructure:"port"`
	GinMode            string `mapstructure:"gin_mode"`
	CORSAllowedOrigins string `mapstructure:"cors_allowed_origins"`
	DataProvider       string `mapstructure:"data_provider"`
}

type RateLimitConfig struct {
	Login       int    `mapstructure:"login"`
	Register    int    `mapstructure:"register"`
	Reset       int    `mapstructure:"reset"`
	Window      string `mapstructure:"window"`
	Forgiveness int    `mapstructure:"forgiveness"`
}

type GoogleConfig struct {
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
	RedirectURL  string `mapstructure:"redirect_url"`
}

type GitHubConfig struct {
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
	RedirectURL  string `mapstructure:"redirect_url"`
}

type LinkedInConfig struct {
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
	RedirectURL  string `mapstructure:"redirect_url"`
}

type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     string `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

// LoadConfig loads configuration from environment variables and .env file
func LoadConfig() (*Config, error) {
	// Load .env file if it exists
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using environment variables")
	}

	// Set default values
	viper.SetDefault("server.port", "8080")
	viper.SetDefault("server.gin_mode", "debug")
	viper.SetDefault("jwt.expiry", "720h")         // 30 days (720 hours)
	viper.SetDefault("jwt.refresh_expiry", "720h") // Same as expiry for sliding window
	viper.SetDefault("email.host", "smtp.gmail.com")
	viper.SetDefault("email.port", 587)
	viper.SetDefault("rate_limit.login", 5)
	viper.SetDefault("rate_limit.register", 3)
	viper.SetDefault("rate_limit.reset", 3)
	viper.SetDefault("rate_limit.window", "1m")
	viper.SetDefault("rate_limit.forgiveness", 2)
	viper.SetDefault("email.frontend_url", "http://localhost:3001")
	viper.SetDefault("storage.bucket_name", "profile-pictures")
	viper.SetDefault("storage.max_file_size", 5242880) // 5MB
	viper.SetDefault("storage.allowed_file_types", "image/jpeg,image/png,image/gif,image/webp")
	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", "6379")
	viper.SetDefault("redis.password", "")
	viper.SetDefault("redis.db", 0)

	// R2 defaults
	viper.SetDefault("r2.bucket_name", "histeeria-media")
	viper.SetDefault("r2.enabled", false)

	// Logging defaults
	viper.SetDefault("logging.level", "info")
	viper.SetDefault("logging.format", "json")

	// Set environment variable prefix
	viper.SetEnvPrefix("")
	viper.AutomaticEnv()

	// Map environment variables to config structure
	viper.BindEnv("database.supabase_url", "SUPABASE_URL")
	viper.BindEnv("database.supabase_anon_key", "SUPABASE_ANON_KEY")
	viper.BindEnv("database.supabase_service_role_key", "SUPABASE_SERVICE_ROLE_KEY")
	viper.BindEnv("jwt.secret", "JWT_SECRET")
	viper.BindEnv("jwt.expiry", "JWT_EXPIRY")
	viper.BindEnv("jwt.refresh_expiry", "REFRESH_TOKEN_EXPIRY")
	viper.BindEnv("email.host", "SMTP_HOST")
	viper.BindEnv("email.port", "SMTP_PORT")
	viper.BindEnv("email.username", "SMTP_USERNAME")
	viper.BindEnv("email.password", "SMTP_PASSWORD")
	viper.BindEnv("email.from_name", "SMTP_FROM_NAME")
	viper.BindEnv("email.from_email", "SMTP_FROM_EMAIL")
	viper.BindEnv("email.frontend_url", "FRONTEND_URL")
	viper.BindEnv("server.port", "PORT")
	viper.BindEnv("server.gin_mode", "GIN_MODE")
	viper.BindEnv("server.cors_allowed_origins", "CORS_ALLOWED_ORIGINS")
	viper.BindEnv("rate_limit.login", "RATE_LIMIT_LOGIN")
	viper.BindEnv("rate_limit.register", "RATE_LIMIT_REGISTER")
	viper.BindEnv("rate_limit.reset", "RATE_LIMIT_RESET")
	viper.BindEnv("rate_limit.window", "RATE_LIMIT_WINDOW")
	viper.BindEnv("rate_limit.forgiveness", "RATE_LIMIT_FORGIVENESS")
	viper.BindEnv("google.client_id", "GOOGLE_CLIENT_ID")
	viper.BindEnv("google.client_secret", "GOOGLE_CLIENT_SECRET")
	viper.BindEnv("google.redirect_url", "GOOGLE_REDIRECT_URL")
	viper.BindEnv("github.client_id", "GITHUB_CLIENT_ID")
	viper.BindEnv("github.client_secret", "GITHUB_CLIENT_SECRET")
	viper.BindEnv("github.redirect_url", "GITHUB_REDIRECT_URL")
	viper.BindEnv("linkedin.client_id", "LINKEDIN_CLIENT_ID")
	viper.BindEnv("linkedin.client_secret", "LINKEDIN_CLIENT_SECRET")
	viper.BindEnv("linkedin.redirect_url", "LINKEDIN_REDIRECT_URL")
	viper.BindEnv("storage.bucket_name", "STORAGE_BUCKET_NAME")
	viper.BindEnv("storage.max_file_size", "STORAGE_MAX_FILE_SIZE")
	viper.BindEnv("storage.allowed_file_types", "STORAGE_ALLOWED_FILE_TYPES")
	viper.BindEnv("redis.host", "REDIS_HOST")
	viper.BindEnv("redis.port", "REDIS_PORT")
	viper.BindEnv("redis.password", "REDIS_PASSWORD")
	viper.BindEnv("redis.db", "REDIS_DB")

	// R2 environment variables
	viper.BindEnv("r2.account_id", "R2_ACCOUNT_ID")
	viper.BindEnv("r2.access_key_id", "R2_ACCESS_KEY_ID")
	viper.BindEnv("r2.secret_access_key", "R2_SECRET_ACCESS_KEY")
	viper.BindEnv("r2.bucket_name", "R2_BUCKET_NAME")
	viper.BindEnv("r2.public_url", "R2_PUBLIC_URL")
	viper.BindEnv("r2.enabled", "R2_ENABLED")

	// Logging environment variables
	viper.BindEnv("logging.level", "LOG_LEVEL")
	viper.BindEnv("logging.format", "LOG_FORMAT")

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, err
	}

	// Validate required configuration
	if err := validateConfig(&config); err != nil {
		return nil, err
	}

	return &config, nil
}

// validateConfig validates that all required configuration is present
func validateConfig(config *Config) error {
	requiredFields := map[string]string{
		"SUPABASE_URL":              config.Database.SupabaseURL,
		"SUPABASE_ANON_KEY":         config.Database.SupabaseAnonKey,
		"SUPABASE_SERVICE_ROLE_KEY": config.Database.SupabaseServiceKey,
		"JWT_SECRET":                config.JWT.Secret,
		"SMTP_USERNAME":             config.Email.Username,
		"SMTP_PASSWORD":             config.Email.Password,
	}

	for field, value := range requiredFields {
		if value == "" {
			return &ConfigError{
				Field: field,
				Msg:   "required configuration field is missing",
			}
		}
	}

	// Validate JWT secret length
	if len(config.JWT.Secret) < 32 {
		return &ConfigError{
			Field: "JWT_SECRET",
			Msg:   "JWT secret must be at least 32 characters long",
		}
	}

	return nil
}

// GetCORSOrigins returns a slice of allowed CORS origins
func (c *Config) GetCORSOrigins() []string {
	if c.Server.CORSAllowedOrigins == "" {
		// Default to common development ports: Next.js (3000) and Flutter web (43873)
		return []string{"http://localhost:3000", "http://localhost:43873"}
	}
	// Split by comma and trim whitespace from each origin
	origins := strings.Split(c.Server.CORSAllowedOrigins, ",")
	result := make([]string, 0, len(origins))
	for _, origin := range origins {
		trimmed := strings.TrimSpace(origin)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

// ConfigError represents a configuration error
type ConfigError struct {
	Field string
	Msg   string
}

func (e *ConfigError) Error() string {
	return "config error: " + e.Field + " - " + e.Msg
}

// GetEnv returns an environment variable with a fallback
func GetEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
