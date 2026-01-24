
# Database Configuration

DATA_PROVIDER=
SUPABASE_URL=
SUPABASE_ANON_KEY=
Publishable_API_Key=
SUPABASE_SERVICE_ROLE_KEY=
DATABASE_URL=


# JWT Configuration
JWT_SECRET=
JWT_EXPIRY=15m
REFRESH_TOKEN_EXPIRY=7d

# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_NAME=Histeeria
SMTP_FROM_EMAIL=noreply@histeeria.com

# Server Configuration
PORT=8081
GIN_MODE=release
CORS_ALLOWED_ORIGINS=https://www.histeeria.com
FRONTEND_URL=https://www.histeeria.com

# Rate Limiting
RATE_LIMIT_LOGIN=5
RATE_LIMIT_REGISTER=5
RATE_LIMIT_RESET=3
RATE_LIMIT_WINDOW=1m

# Redis Configuration
REDIS_HOST=
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# Google OAuth Configuration
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URL=http://localhost:8081/api/v1/auth/google/callback

# GitHub OAuth Configuration
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GITHUB_REDIRECT_URL=http://localhost:8081/api/v1/auth/github/callback

LINKEDIN_CLIENT_ID=
LINKEDIN_CLIENT_SECRET=
LINKEDIN_REDIRECT_URL=http://localhost:8081/api/v1/auth/linkedin/callback

# Defaults are already implemented but this is for profile-pictures:
STORAGE_BUCKET_NAME=profile-pictures
STORAGE_MAX_FILE_SIZE=5242880
STORAGE_ALLOWED_FILE_TYPES=image/jpeg,image/png,image/gif,image/webp