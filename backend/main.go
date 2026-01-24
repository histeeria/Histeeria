package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"histeeria-backend/internal/account"
	"histeeria-backend/internal/auth"
	"histeeria-backend/internal/cache"
	"histeeria-backend/internal/config"
	"histeeria-backend/internal/jobs"
	"histeeria-backend/internal/messaging"
	"histeeria-backend/internal/notifications"
	"histeeria-backend/internal/posts"
	"histeeria-backend/internal/queue"
	"histeeria-backend/internal/repository"
	"histeeria-backend/internal/search"
	"histeeria-backend/internal/social"
	"histeeria-backend/internal/status"
	"histeeria-backend/internal/storage"
	"histeeria-backend/internal/utils"
	"histeeria-backend/internal/websocket"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
)

func main() {
	// ============================================
	// 1. LOAD CONFIGURATION
	// ============================================
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Set Gin mode based on configuration
	if cfg.Server.GinMode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// ============================================
	// 2. INITIALIZE CACHE PROVIDER (Redis or In-Memory)
	// ============================================
	var cacheProvider cache.CacheProvider
	var redisClient interface{} // For backward compatibility with existing code

	redisConnected := false
	if cfg.Redis.Host != "" {
		rp, err := cache.NewRedisProvider(&cache.RedisConfig{
			Host:     cfg.Redis.Host,
			Port:     cfg.Redis.Port,
			Password: cfg.Redis.Password,
			DB:       cfg.Redis.DB,
		})
		if err != nil {
			log.Printf("[Warning] Failed to connect to Redis: %v (using in-memory cache)", err)
			cacheProvider = cache.NewMemoryProvider()
		} else if !rp.IsAvailable() {
			log.Printf("[Warning] Redis not available (using in-memory cache)")
			cacheProvider = cache.NewMemoryProvider()
		} else {
			cacheProvider = rp
			redisClient = rp.GetClient()
			redisConnected = true
			log.Println("[Cache] Redis connected successfully")
		}
	} else {
		log.Println("[Cache] No Redis configured, using in-memory cache")
		cacheProvider = cache.NewMemoryProvider()
	}

	// ============================================
	// 3. INITIALIZE STORAGE PROVIDER (R2, Supabase, Local)
	// ============================================
	var storageService *storage.StorageService

	// Check if R2 is configured (primary storage)
	if cfg.R2.AccountID != "" && cfg.R2.AccessKeyID != "" {
		r2Provider := storage.NewR2Provider(storage.R2Config{
			AccountID:       cfg.R2.AccountID,
			AccessKeyID:     cfg.R2.AccessKeyID,
			SecretAccessKey: cfg.R2.SecretAccessKey,
			BucketName:      cfg.R2.BucketName,
			PublicURL:       cfg.R2.PublicURL,
		})
		storageService = storage.NewStorageService(r2Provider)

		// Add Supabase as fallback
		if cfg.Database.SupabaseURL != "" {
			supabaseProvider := storage.NewSupabaseProvider(storage.SupabaseConfig{
				ProjectURL: cfg.Database.SupabaseURL,
				ServiceKey: cfg.Database.SupabaseServiceKey,
				BucketName: "media", // Default bucket name
			})
			storageService.SetFallback(supabaseProvider)
		}

		log.Println("[Storage] R2 configured as primary storage (Supabase fallback)")
	} else if cfg.Database.SupabaseURL != "" {
		// Use Supabase as primary if R2 is not configured
		supabaseProvider := storage.NewSupabaseProvider(storage.SupabaseConfig{
			ProjectURL: cfg.Database.SupabaseURL,
			ServiceKey: cfg.Database.SupabaseServiceKey,
			BucketName: "media",
		})
		storageService = storage.NewStorageService(supabaseProvider)
		log.Println("[Storage] Supabase configured as primary storage")
	} else {
		// Fall back to local storage for development
		localProvider, err := storage.NewLocalProvider(storage.LocalConfig{
			BasePath: "./uploads",
			BaseURL:  "http://localhost:" + cfg.Server.Port + "/uploads",
		})
		if err != nil {
			log.Printf("[Warning] Failed to initialize local storage: %v", err)
		} else {
			storageService = storage.NewStorageService(localProvider)
			log.Println("[Storage] Local filesystem configured (development mode)")
		}
	}

	// Legacy storage service for backward compatibility
	// Only initialize if Supabase URL is configured
	var legacyStorageSvc *utils.StorageService
	if cfg.Database.SupabaseURL != "" {
		// Validate Supabase URL format
		if !strings.HasPrefix(cfg.Database.SupabaseURL, "http://") && !strings.HasPrefix(cfg.Database.SupabaseURL, "https://") {
			log.Printf("[Storage] WARNING: SUPABASE_URL doesn't start with http/https: %s", cfg.Database.SupabaseURL)
			log.Printf("[Storage] Attempting to auto-correct...")
			if strings.Contains(cfg.Database.SupabaseURL, ".supabase.co") {
				cfg.Database.SupabaseURL = "https://" + cfg.Database.SupabaseURL
				log.Printf("[Storage] Auto-corrected to: %s", cfg.Database.SupabaseURL)
			} else {
				log.Printf("[Storage] WARNING: SUPABASE_URL format is invalid. Expected format: https://xxx.supabase.co")
				log.Printf("[Storage] Skipping legacy storage service initialization")
				legacyStorageSvc = nil
			}
		}
		if legacyStorageSvc == nil && cfg.Database.SupabaseURL != "" {
			log.Printf("[Storage] Initializing legacy storage service with Supabase URL: %s", cfg.Database.SupabaseURL)
			legacyStorageSvc = utils.NewStorageService(&cfg.Storage, cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
		}
	} else {
		log.Println("[Storage] SUPABASE_URL not configured - using primary storage service only")
	}

	// ============================================
	// 4. INITIALIZE REPOSITORIES
	// ============================================
	userRepo, err := repository.NewUserRepository(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize user repository: %v", err)
	}

	sessionRepo, err := repository.NewSessionRepository(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize session repository: %v", err)
	}

	// Experience and education repositories
	expRepo := repository.NewSupabaseExperienceRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	eduRepo := repository.NewSupabaseEducationRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)

	// Advanced profile repositories
	companyRepo := repository.NewSupabaseCompanyRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	certRepo := repository.NewSupabaseCertificationRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	skillRepo := repository.NewSupabaseSkillRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	languageRepo := repository.NewSupabaseLanguageRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	volunteeringRepo := repository.NewSupabaseVolunteeringRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	publicationRepo := repository.NewSupabasePublicationRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	interestRepo := repository.NewSupabaseInterestRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	achievementRepo := repository.NewSupabaseAchievementRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)

	// Relationship repository
	relationshipRepo, err := repository.NewRelationshipRepository(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize relationship repository: %v", err)
	}

	// Notification repository
	notificationRepo, err := repository.NewNotificationRepository(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize notification repository: %v", err)
	}

	// Message repository
	messageRepo, err := repository.NewMessageRepository(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize message repository: %v", err)
	}

	// Post repositories
	postRepo := repository.NewSupabasePostRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	pollRepo := repository.NewSupabasePollRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	articleRepo := repository.NewSupabaseArticleRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	commentRepo := repository.NewSupabaseCommentRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)

	// Status repository
	statusRepo := repository.NewSupabaseStatusRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)

	log.Println("[Repositories] All repositories initialized")

	// ============================================
	// 5. INITIALIZE CORE SERVICES
	// ============================================
	emailSvc := utils.NewEmailService(&cfg.Email)
	jwtSvc := utils.NewJWTService(cfg.JWT.Secret, 30*24*time.Hour) // 30 days validity
	tokenBlacklist := utils.NewTokenBlacklist()
	jwtSvc.SetBlacklist(tokenBlacklist)

	// Initialize distributed rate limiter (Redis when available, fallback to in-memory)
	var hybridRateLimiter *cache.HybridRateLimiter
	if redisConnected {
		if rp, ok := cacheProvider.(*cache.RedisProvider); ok {
			hybridRateLimiter = cache.NewHybridRateLimiterFromProvider(rp, cfg.RateLimit.Forgiveness)
			log.Println("[RateLimit] Using distributed (Redis) rate limiting")
		}
	}
	if hybridRateLimiter == nil {
		hybridRateLimiter = cache.NewHybridRateLimiter(nil, cfg.RateLimit.Forgiveness)
		log.Println("[RateLimit] Using in-memory rate limiting (single server only)")
	}

	// Legacy rate limiter for backward compatibility
	legacyRateLimiter := utils.NewRateLimiter(cfg.RateLimit.Forgiveness)

	// Auth service (queue provider will be passed after queue initialization)
	// We'll initialize this after the queue is set up
	var authSvc *auth.AuthService

	// OAuth services
	googleOAuth := auth.NewGoogleOAuthService(&cfg.Google, userRepo, jwtSvc)
	githubOAuth := auth.NewGitHubOAuthService(&cfg.GitHub, userRepo, jwtSvc)
	linkedinOAuth := auth.NewLinkedInOAuthService(&cfg.LinkedIn, userRepo, jwtSvc)

	// Account services
	accountSvc := account.NewAccountService(userRepo, sessionRepo, emailSvc, legacyStorageSvc)
	profileSvc := account.NewProfileService(userRepo)
	expEduSvc := account.NewExperienceEducationService(expRepo, eduRepo)
	advancedProfileSvc := account.NewAdvancedProfileService(
		companyRepo, certRepo, skillRepo, languageRepo,
		volunteeringRepo, publicationRepo, interestRepo, achievementRepo, expRepo,
	)

	// ============================================
	// 6. INITIALIZE WEBSOCKET MANAGER WITH PUB/SUB
	// ============================================
	wsManager := websocket.NewManager()
	go wsManager.Run()

	// Initialize Redis Pub/Sub for multi-instance WebSocket scaling
	var wsPubSub *websocket.PubSubManager
	if redisConnected {
		if rp, ok := cacheProvider.(*cache.RedisProvider); ok {
			wsPubSub = websocket.NewPubSubManager(rp.GetClient(), wsManager)
			wsPubSub.Start()
			log.Println("[WebSocket] Manager started with Redis Pub/Sub for multi-instance scaling")
		}
	}
	if wsPubSub == nil || !wsPubSub.IsEnabled() {
		log.Println("[WebSocket] Manager started (single-instance mode - no Redis Pub/Sub)")
	}

	// ============================================
	// 7. INITIALIZE NOTIFICATION SYSTEM
	// ============================================
	baseURL := cfg.Email.FrontendURL
	if baseURL == "" {
		baseURL = "http://localhost:3001"
	}
	notificationEmailSvc := notifications.NewEmailService(emailSvc, baseURL)
	// Notification service will be initialized after queue (queue provider needed)
	var notificationSvc *notifications.NotificationService

	// ============================================
	// 8. INITIALIZE RELATIONSHIP SERVICE
	// ============================================
	relationshipSvc := social.NewRelationshipService(relationshipRepo, userRepo)
	relationshipSvc.SetNotificationService(notificationSvc)

	// ============================================
	// 9. INITIALIZE SEARCH SERVICE
	// ============================================
	searchSvc := search.NewSearchService(userRepo, postRepo)

	// ============================================
	// 10. INITIALIZE MESSAGING SYSTEM
	// ============================================
	var messageCacheSvc *cache.MessageCacheService
	if redisConnected {
		// Initialize Redis client for the old cache service
		oldRedisClient, err := cache.InitializeRedis(cfg.Redis.Host, cfg.Redis.Port, cfg.Redis.Password, cfg.Redis.DB)
		if err == nil {
			messageCacheSvc = cache.NewMessageCacheService(oldRedisClient)
			// Note: Auth service Redis will be set after queue initialization
		}
	}

	// Create delivery repository adapter (WhatsApp-style store-and-forward)
	deliveryRepoAdapter := repository.NewDeliveryRepositoryAdapter(
		messageRepo,
		cfg.Database.SupabaseURL,
		cfg.Database.SupabaseServiceKey,
	)

	// Create delivery service for WhatsApp-style messaging
	deliverySvc := messaging.NewDeliveryService(deliveryRepoAdapter, wsManager)

	mediaOptimizer := messaging.NewMediaOptimizer()
	messagingSvc := messaging.NewMessagingService(messageRepo, messageCacheSvc, wsManager, userRepo, notificationSvc)
	messageHandlers := messaging.NewMessageHandlers(messagingSvc, deliverySvc, legacyStorageSvc, mediaOptimizer)

	log.Println("[Messaging] Messaging system initialized (DeliveryService ready)")

	// ============================================
	// 11. INITIALIZE FEED CACHE SERVICE
	// ============================================
	feedCacheSvc := cache.NewFeedCacheService(cacheProvider)

	log.Println("[FeedCache] Feed cache service initialized (enabled:", feedCacheSvc.IsEnabled(), ")")

	// ============================================
	// 12. INITIALIZE POSTS & FEED SYSTEM
	// ============================================
	postSvc := posts.NewService(postRepo, pollRepo, articleRepo, commentRepo, userRepo, wsManager)
	feedSvc := posts.NewFeedServiceWithCache(postRepo, relationshipRepo, feedCacheSvc)
	postHandlers := posts.NewHandlers(postSvc, feedSvc, legacyStorageSvc, mediaOptimizer)

	log.Println("[Posts] Post & feed system initialized (caching:", feedCacheSvc.IsEnabled(), ")")

	// ============================================
	// 13. INITIALIZE STATUS SYSTEM
	// ============================================
	statusSvc := status.NewService(statusRepo)
	statusHandlers := status.NewHandlers(statusSvc, legacyStorageSvc, mediaOptimizer)

	log.Println("[Statuses] Status system initialized")

	// ============================================
	// 14. INITIALIZE BACKGROUND JOB SCHEDULER
	// ============================================
	jobScheduler := jobs.NewJobScheduler()

	// Create job factory and register common jobs
	// All services are now ready and wired
	jobFactory := jobs.NewJobFactory(
		messageRepo,      // messageRepo (used for cleanup jobs)
		notificationRepo, // notificationRepo (used for cleanup jobs)
		statusRepo,       // statusRepo (used for cleanup jobs)
		feedCacheSvc,     // feedCacheSvc (used for cache warming)
		deliverySvc,      // deliveryService (used for WhatsApp-style cleanup)
	)
	jobFactory.RegisterCommonJobs(jobScheduler)

	// Start job scheduler
	jobScheduler.Start()

	log.Println("[Jobs] Background job scheduler started")

	// ============================================
	// 14b. INITIALIZE MESSAGE QUEUE SYSTEM
	// ============================================
	var queueProvider queue.QueueProvider
	var emailWorker *queue.EmailWorker

	if redisConnected {
		if rp, ok := cacheProvider.(*cache.RedisProvider); ok {
			queueProvider = queue.NewRedisQueueProvider(rp.GetClient(), &queue.RedisQueueConfig{
				ConsumerName: "histeeria-main",
				GroupName:    "histeeria-workers",
			})
			log.Println("[Queue] Using Redis queue provider")
		}
	}
	if queueProvider == nil {
		queueProvider = queue.NewMemoryQueueProvider()
		log.Println("[Queue] Using in-memory queue provider")
	}

	// Create email worker (implements queue.EmailSender interface via emailSvc)
	emailWorker = queue.NewEmailWorker(queueProvider, &emailSenderAdapter{emailSvc}, 2)
	emailWorker.Start()

	log.Println("[Queue] Message queue system initialized")

	// ============================================
	// 14c. INITIALIZE SERVICES (AFTER QUEUE)
	// ============================================
	// Auth service requires queue provider for async emails
	authSvc = auth.NewAuthService(userRepo, emailSvc, queueProvider, jwtSvc, tokenBlacklist)

	// Set Redis client for auth service OTP caching (if available)
	if redisConnected {
		if oldRedisClient, err := cache.InitializeRedis(cfg.Redis.Host, cfg.Redis.Port, cfg.Redis.Password, cfg.Redis.DB); err == nil {
			authSvc.SetRedis(oldRedisClient)
		}
	}

	// Initialize account group repository and multi-account service
	accountGroupRepo := repository.NewSupabaseAccountGroupRepository(cfg.Database.SupabaseURL, cfg.Database.SupabaseServiceKey)
	multiAccountSvc := auth.NewMultiAccountService(accountGroupRepo, userRepo, jwtSvc, authSvc)

	// Notification service requires queue provider for async emails
	notificationSvc = notifications.NewNotificationService(notificationRepo, userRepo, wsManager, notificationEmailSvc, queueProvider)

	// Set notification service in services that were initialized before it
	relationshipSvc.SetNotificationService(notificationSvc)
	messagingSvc.SetNotificationService(notificationSvc)

	// ============================================
	// 15. INITIALIZE HANDLERS
	// ============================================
	authHandlers := auth.NewAuthHandlers(authSvc, multiAccountSvc, jwtSvc, legacyRateLimiter, hybridRateLimiter, cfg, googleOAuth, githubOAuth, linkedinOAuth, sessionRepo)
	accountHandlers := account.NewAccountHandlers(accountSvc, profileSvc, advancedProfileSvc)
	expEduHandlers := account.NewExperienceEducationHandlers(expEduSvc)
	relationshipHandlers := social.NewRelationshipHandlers(relationshipSvc)
	searchHandlers := search.NewSearchHandlers(searchSvc)
	wsHandlers := websocket.NewHandlers(wsManager, jwtSvc)
	notificationHandlers := notifications.NewHandlers(notificationSvc)

	// ============================================
	// 16. INITIALIZE HEALTH CHECKER
	// ============================================
	var healthChecker *utils.HealthChecker
	if redisConnected {
		if rp, ok := redisClient.(*redis.Client); ok {
			healthChecker = utils.NewHealthChecker(rp)
		}
	}
	if healthChecker == nil {
		healthChecker = utils.NewHealthChecker(nil)
	}

	// Add custom health checks
	healthChecker.AddCheck(utils.HealthCheck{
		Name: "jobs",
		Check: func(ctx context.Context) error {
			if !jobScheduler.IsRunning() {
				return fmt.Errorf("scheduler not running")
			}
			return nil
		},
		Timeout: 5 * time.Second,
	})

	// ============================================
	// 17. CREATE GIN ROUTER WITH MIDDLEWARE
	// ============================================
	// Use gin.New() instead of gin.Default() to have full control over middleware
	r := gin.New()

	// 1. CRITICAL: Panic Recovery Middleware (MUST BE FIRST)
	r.Use(utils.PanicRecoveryMiddleware())

	// 2. Request ID Middleware
	r.Use(utils.RequestIDMiddleware())

	// 3. Gin Logger (after panic recovery)
	r.Use(gin.Logger())

	// 4. Security headers middleware
	r.Use(utils.SecurityHeadersMiddleware())

	// Additional security headers
	r.Use(func(c *gin.Context) {
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		if cfg.Server.GinMode == "release" {
			c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		c.Next()
	})

	// CORS middleware (WebSocket upgrade requests are handled separately)
	allowedOrigins := cfg.GetCORSOrigins()
	log.Printf("[CORS] Allowed origins: %v", allowedOrigins)

	// Create a map for O(1) lookup
	originMap := make(map[string]bool)
	for _, origin := range allowedOrigins {
		originMap[origin] = true
	}

	corsConfig := cors.Config{
		AllowOriginFunc: func(origin string) bool {
			// Allow requests with no origin (like mobile apps or Postman)
			if origin == "" {
				return true
			}
			allowed := originMap[origin]
			if !allowed {
				log.Printf("[CORS] Rejected origin: %s (allowed: %v)", origin, allowedOrigins)
			}
			return allowed
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "Accept", "Upgrade", "Connection", "Sec-WebSocket-Key", "Sec-WebSocket-Version", "Sec-WebSocket-Protocol", "Sec-WebSocket-Extensions"},
		ExposeHeaders:    []string{"Content-Length", "Upgrade", "Connection", "Sec-WebSocket-Accept"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}
	// Apply CORS middleware directly - it handles OPTIONS preflight automatically
	// For WebSocket upgrades, they handle origin checking separately in the upgrader
	// Note: WebSocket upgrade requests won't match CORS anyway, so this is safe
	r.Use(cors.New(corsConfig))

	// Request size limit (8MB for multipart forms)
	r.MaxMultipartMemory = 8 << 20

	// Global rate limiting middleware (100 requests per minute per IP)
	// Skip rate limiting for OPTIONS preflight requests (CORS)
	rateLimitMiddleware := auth.DistributedRateLimitMiddleware(hybridRateLimiter, 100, time.Minute)
	r.Use(func(c *gin.Context) {
		// Skip rate limiting for OPTIONS preflight requests
		if c.Request.Method == "OPTIONS" {
			c.Next()
			return
		}
		rateLimitMiddleware(c)
	})

	// ============================================
	// 18. HEALTH CHECK ENDPOINTS
	// ============================================

	// Simple health check (for load balancers)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "histeeria-backend",
			"version": "1.0.0",
		})
	})

	// Detailed health check (Kubernetes readiness probe)
	r.GET("/health/ready", healthChecker.ReadinessHandler())

	// Liveness probe (Kubernetes)
	r.GET("/health/live", healthChecker.LivenessHandler())

	// Public configuration endpoint - returns Supabase storage URL for frontend
	r.GET("/config/storage-url", func(c *gin.Context) {
		supabaseURL := cfg.Database.SupabaseURL
		if supabaseURL == "" {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error": "Storage URL not configured",
			})
			return
		}
		// Return the storage base URL (frontend will append /storage/v1/object/public/)
		c.JSON(http.StatusOK, gin.H{
			"storage_url": supabaseURL,
		})
	})

	// Welcome endpoint
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Welcome to Histeeria Backend API",
			"service": "histeeria-backend",
			"version": "1.0.0",
		})
	})

	// Serve local uploads in development
	if cfg.Server.GinMode != "release" {
		r.Static("/uploads", "./uploads")
	}

	// ============================================
	// 19. API ROUTES
	// ============================================
	api := r.Group("/api/v1")
	{
		api.GET("/status", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"status": "running",
				"api":    "v1",
			})
		})

		// Debug endpoints (development only)
		if cfg.Server.GinMode == "debug" {
			api.GET("/test-db", func(c *gin.Context) {
				log.Println("[Test] Testing Supabase connection...")
				emailExists, err := userRepo.CheckEmailExists(c.Request.Context(), "test@example.com")
				if err != nil {
					log.Printf("[Test] Database error: %v", err)
					c.JSON(http.StatusInternalServerError, gin.H{
						"success": false,
						"error":   "Database connection test failed",
					})
					return
				}
				c.JSON(http.StatusOK, gin.H{
					"success":     true,
					"message":     "Database connection successful",
					"emailExists": emailExists,
				})
			})

			// Job stats endpoint (debug only)
			api.GET("/jobs/stats", func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{
					"jobs":   jobScheduler.GetJobStats(),
					"errors": jobScheduler.GetRecentErrors(10),
				})
			})

			// Rate limit status endpoint (debug only)
			api.GET("/ratelimit/status", auth.GetRateLimitStatus(hybridRateLimiter))

			// Queue stats endpoint (debug only)
			api.GET("/queue/stats", func(c *gin.Context) {
				stats := map[string]interface{}{
					"provider_type": func() string {
						if _, ok := queueProvider.(*queue.RedisQueueProvider); ok {
							return "redis"
						}
						return "memory"
					}(),
				}
				if emailWorker != nil {
					stats["email_worker"] = emailWorker.GetStats()
				}
				c.JSON(http.StatusOK, stats)
			})

			// Detailed health endpoint (debug only)
			api.GET("/health/details", healthChecker.HealthHandler())
		}

		// Authentication routes
		authHandlers.SetupRoutes(api)

		// Protected routes
		protected := api.Group("")
		protected.Use(auth.JWTAuthMiddleware(jwtSvc))

		// Account management
		accountHandlers.SetupRoutes(protected)

		// Experience and education
		protected.POST("/account/experiences", expEduHandlers.CreateExperience)
		protected.GET("/account/experiences", expEduHandlers.GetMyExperiences)
		protected.PATCH("/account/experiences/:id", expEduHandlers.UpdateExperience)
		protected.DELETE("/account/experiences/:id", expEduHandlers.DeleteExperience)

		protected.POST("/account/education", expEduHandlers.CreateEducation)
		protected.GET("/account/education", expEduHandlers.GetMyEducation)
		protected.PATCH("/account/education/:id", expEduHandlers.UpdateEducation)
		protected.DELETE("/account/education/:id", expEduHandlers.DeleteEducation)

		// Relationships
		relationshipHandlers.SetupRoutes(protected)

		// Notifications
		notificationHandlers.SetupRoutes(protected)

		// Messaging
		messagingGroup := protected.Group("/conversations")
		{
			messagingGroup.GET("", messageHandlers.GetConversations)
			messagingGroup.GET("/unread-count", messageHandlers.GetUnreadCount)
			messagingGroup.GET("/:id/messages", messageHandlers.GetMessages)
			// Message sending with rate limiting (60 messages per minute)
			messagingGroup.POST("/:id/messages",
				auth.MessageRateLimitMiddleware(hybridRateLimiter),
				messageHandlers.SendMessage)
			messagingGroup.PATCH("/:id/read", messageHandlers.MarkAsRead)
			messagingGroup.GET("/:id/pinned", messageHandlers.GetPinnedMessages)
			messagingGroup.GET("/:id/search", messageHandlers.SearchConversationMessages)
			messagingGroup.POST("/:id/typing/start", messageHandlers.StartTyping)
			messagingGroup.POST("/:id/typing/stop", messageHandlers.StopTyping)
			messagingGroup.GET("/:id", messageHandlers.GetConversation)
			messagingGroup.POST("/start/:userId", messageHandlers.StartConversation)

			// Delivery tracking endpoints (WhatsApp-style - batch)
			messagingGroup.POST("/:id/mark-delivered", messageHandlers.MarkConversationDelivered)

			// E2EE key exchange endpoints
			messagingGroup.POST("/:id/keys", messageHandlers.ExchangePublicKey)
			messagingGroup.GET("/:id/keys", messageHandlers.GetConversationPublicKey)
		}

		messageGroup := protected.Group("/messages")
		{
			messageGroup.GET("/search", messageHandlers.SearchMessages)
			messageGroup.GET("/starred", messageHandlers.GetStarredMessages)
			messageGroup.DELETE("/:id", messageHandlers.DeleteMessage)
			messageGroup.POST("/:id/reactions", messageHandlers.AddReaction)
			messageGroup.DELETE("/:id/reactions", messageHandlers.RemoveReaction)
			messageGroup.POST("/:id/star", messageHandlers.StarMessage)
			messageGroup.DELETE("/:id/star", messageHandlers.UnstarMessage)
			messageGroup.POST("/:id/pin", messageHandlers.PinMessage)
			messageGroup.DELETE("/:id/pin", messageHandlers.UnpinMessage)
			messageGroup.PATCH("/:id", messageHandlers.EditMessage)
			messageGroup.GET("/:id/edit-history", messageHandlers.GetMessageEditHistory)
			messageGroup.POST("/:id/forward", messageHandlers.ForwardMessage)
			messageGroup.POST("/upload-image", messageHandlers.UploadImage)
			messageGroup.POST("/upload-audio", messageHandlers.UploadAudio)
			messageGroup.POST("/upload-file", messageHandlers.UploadFile)
			messageGroup.POST("/upload-video", messageHandlers.UploadVideo)

			// File download with signed URLs (secure)
			messageGroup.GET("/files/:messageId/download", messageHandlers.GetFileSignedURL)

			// Delivery tracking endpoints (WhatsApp-style)
			messageGroup.GET("/pending", messageHandlers.GetPendingMessages)
			messageGroup.POST("/:id/mark-delivered", messageHandlers.MarkMessageDelivered)
			messageGroup.POST("/:id/read", messageHandlers.MarkMessageReadEndpoint)
		}

		presenceGroup := protected.Group("/users")
		{
			presenceGroup.GET("/:id/presence", messageHandlers.GetUserPresence)
			presenceGroup.GET("/presence/bulk", messageHandlers.GetBulkPresence)
		}

		// Search (public)
		searchHandlers.SetupRoutes(api)

		// Posts & Feed
		api.GET("/articles/:slug", postHandlers.GetArticleBySlug) // Public

		postsGroup := protected.Group("/posts")
		{
			postsGroup.POST("/upload-image", postHandlers.UploadImage)
			postsGroup.POST("/upload-video", postHandlers.UploadVideo)
			postsGroup.POST("/upload-audio", postHandlers.UploadAudio)
			postsGroup.POST("", postHandlers.CreatePost)
			postsGroup.GET("/:id", postHandlers.GetPost)
			postsGroup.PUT("/:id", postHandlers.UpdatePost)
			postsGroup.DELETE("/:id", postHandlers.DeletePost)
			postsGroup.POST("/:id/restrict", postHandlers.RestrictPost)
			postsGroup.DELETE("/:id/restrict", postHandlers.UnrestrictPost)
			postsGroup.GET("/user/:username", postHandlers.GetUserPosts)
			postsGroup.GET("/:id/insights", postHandlers.GetPostInsights)
			postsGroup.POST("/:id/like", postHandlers.LikePost)
			postsGroup.DELETE("/:id/like", postHandlers.UnlikePost)
			postsGroup.POST("/:id/share", postHandlers.SharePost)
			postsGroup.POST("/:id/save", postHandlers.SavePost)
			postsGroup.DELETE("/:id/save", postHandlers.UnsavePost)
			postsGroup.POST("/:id/comments", postHandlers.CreateComment)
			postsGroup.GET("/:id/comments", postHandlers.GetComments)
			postsGroup.POST("/:id/vote", postHandlers.VotePoll)
			postsGroup.GET("/:id/results", postHandlers.GetPollResults)
		}

		commentsGroup := protected.Group("/comments")
		{
			commentsGroup.PUT("/:id", postHandlers.UpdateComment)
			commentsGroup.DELETE("/:id", postHandlers.DeleteComment)
			commentsGroup.POST("/:id/like", postHandlers.LikeComment)
		}

		feedGroup := protected.Group("/feed")
		{
			feedGroup.GET("/home", postHandlers.GetHomeFeed)
			feedGroup.GET("/following", postHandlers.GetFollowingFeed)
			feedGroup.GET("/explore", postHandlers.GetExploreFeed)
			feedGroup.GET("/saved", postHandlers.GetSavedFeed)
			feedGroup.GET("/since-last-visit", postHandlers.GetSinceLastVisitCounts)
		}

		activityGroup := protected.Group("/activity")
		{
			activityGroup.GET("/interactions", postHandlers.GetUserInteractions)
			activityGroup.GET("/archived", postHandlers.GetUserArchived)
			activityGroup.GET("/shared", postHandlers.GetUserShared)
		}

		hashtagGroup := api.Group("/hashtags")
		{
			hashtagGroup.GET("/:tag/posts", postHandlers.GetHashtagFeed)
			hashtagGroup.GET("/trending", postHandlers.GetTrendingHashtags)

			hashtagProtected := hashtagGroup.Group("")
			hashtagProtected.Use(auth.JWTAuthMiddleware(jwtSvc))
			{
				hashtagProtected.POST("/:tag/follow", postHandlers.FollowHashtag)
				hashtagProtected.DELETE("/:tag/follow", postHandlers.UnfollowHashtag)
			}
		}

		// Statuses
		statusesGroup := protected.Group("/statuses")
		{
			statusesGroup.POST("/upload-image", statusHandlers.UploadStatusImage)
			statusesGroup.POST("/upload-video", statusHandlers.UploadStatusVideo)
			statusesGroup.POST("", statusHandlers.CreateStatus)
			statusesGroup.GET("/feed", statusHandlers.GetStatusesForFeed)
			statusesGroup.GET("/user/:userID", statusHandlers.GetUserStatuses)
			statusesGroup.GET("/:id", statusHandlers.GetStatus)
			statusesGroup.DELETE("/:id", statusHandlers.DeleteStatus)
			statusesGroup.POST("/:id/view", statusHandlers.ViewStatus)
			statusesGroup.GET("/:id/views", statusHandlers.GetStatusViews)
			statusesGroup.POST("/:id/react", statusHandlers.ReactToStatus)
			statusesGroup.DELETE("/:id/react", statusHandlers.RemoveStatusReaction)
			statusesGroup.GET("/:id/reactions", statusHandlers.GetStatusReactions)
			statusesGroup.POST("/:id/comments", statusHandlers.CreateStatusComment)
			statusesGroup.GET("/:id/comments", statusHandlers.GetStatusComments)
			statusesGroup.DELETE("/comments/:id", statusHandlers.DeleteStatusComment)
			statusesGroup.POST("/:id/message-reply", statusHandlers.CreateStatusMessageReply)
		}

		// WebSocket
		wsHandlers.SetupRoutes(api)
	}

	log.Println("[Routes] All routes registered")

	// ============================================
	// 20. START SERVER WITH GRACEFUL SHUTDOWN
	// ============================================
	server := &http.Server{
		Addr:         ":" + cfg.Server.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("[Server] Starting on port %s", cfg.Server.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[Server] Shutdown signal received...")

	// Create shutdown context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Shutdown HTTP server first
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("[Server] HTTP server shutdown error: %v", err)
	}

	// Stop job scheduler
	log.Println("[Server] Stopping job scheduler...")
	jobScheduler.Stop()

	// Stop rate limiter cleanup
	log.Println("[Server] Stopping rate limiter...")
	hybridRateLimiter.Stop()

	// Close WebSocket connections
	log.Println("[Server] Closing WebSocket connections...")
	wsManager.Shutdown()

	// Close cache connection
	log.Println("[Server] Closing cache connection...")
	if err := cacheProvider.Close(); err != nil {
		log.Printf("[Server] Cache close error: %v", err)
	}

	// Stop email worker
	log.Println("[Server] Stopping email worker...")
	if emailWorker != nil {
		emailWorker.Stop()
	}

	// Close queue provider
	log.Println("[Server] Closing queue provider...")
	if queueProvider != nil {
		queueProvider.Close()
	}

	log.Println("[Server] Shutdown complete")
}

// emailSenderAdapter adapts utils.EmailService to queue.EmailSender interface
type emailSenderAdapter struct {
	svc *utils.EmailService
}

func (a *emailSenderAdapter) SendWelcomeEmail(to, name string) error {
	return a.svc.SendWelcomeEmail(to, name)
}

func (a *emailSenderAdapter) SendVerificationEmail(to, code string) error {
	return a.svc.SendVerificationEmail(to, code)
}

func (a *emailSenderAdapter) SendPasswordResetEmail(to, token string) error {
	return a.svc.SendPasswordResetEmail(to, token)
}

func (a *emailSenderAdapter) SendNotificationEmail(to, subject, body string) error {
	// Use the general SendEmail method
	return a.svc.SendEmail(to, subject, body, body)
}
