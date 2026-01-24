package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
	"github.com/gosimple/slug"
)

// SupabaseArticleRepository implements ArticleRepository using Supabase
type SupabaseArticleRepository struct {
	*SupabasePostRepository
}

// NewSupabaseArticleRepository creates a new article repository
func NewSupabaseArticleRepository(supabaseURL, serviceKey string) *SupabaseArticleRepository {
	return &SupabaseArticleRepository{
		SupabasePostRepository: NewSupabasePostRepository(supabaseURL, serviceKey),
	}
}

// CreateArticle creates a new article
func (r *SupabaseArticleRepository) CreateArticle(ctx context.Context, article *models.Article) error {
	if article.ID == uuid.Nil {
		article.ID = uuid.New()
	}

	// Generate slug if not provided
	if article.Slug == "" {
		article.Slug = r.generateUniqueSlug(ctx, article.Title)
	}

	// Calculate read time
	article.ReadTimeMinutes = article.CalculateReadTime()

	payload := map[string]interface{}{
		"id":                article.ID,
		"post_id":           article.PostID,
		"title":             article.Title,
		"subtitle":          article.Subtitle,
		"content_html":      article.ContentHTML,
		"cover_image_url":   article.CoverImageURL,
		"meta_title":        article.MetaTitle,
		"meta_description":  article.MetaDescription,
		"slug":              article.Slug,
		"read_time_minutes": article.ReadTimeMinutes,
		"category":          article.Category,
	}

	data, err := r.makeRequest("POST", "articles", "", payload)
	if err != nil {
		return fmt.Errorf("failed to create article: %w", err)
	}

	// Parse as map first to handle timestamps
	var createdData []map[string]interface{}
	if err := json.Unmarshal(data, &createdData); err != nil {
		return fmt.Errorf("failed to unmarshal article: %w", err)
	}

	if len(createdData) > 0 {
		// Parse article with custom timestamp handling
		articleData := createdData[0]
		
		// Parse timestamps
		parseTime := func(val interface{}) *time.Time {
			if val == nil {
				return nil
			}
			str, ok := val.(string)
			if !ok {
				return nil
			}
			
			if t, err := time.Parse(time.RFC3339, str); err == nil {
				return &t
			}
			if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
				return &t
			}
			
			utc, _ := time.LoadLocation("UTC")
			if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
				parts := strings.Split(str, ".")
				if len(parts) == 2 {
					fractional := parts[1]
					if len(fractional) > 6 {
						fractional = fractional[:6]
					} else if len(fractional) < 6 {
						fractional = fractional + strings.Repeat("0", 6-len(fractional))
					}
					normalized := parts[0] + "." + fractional
					if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", normalized, utc); err == nil {
						return &t
					}
				} else {
					if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
						return &t
					}
				}
			}
			
			return nil
		}

		parseRequiredTime := func(val interface{}) time.Time {
			if t := parseTime(val); t != nil {
				return *t
			}
			return time.Now()
		}

		// Parse IDs
		if id, ok := articleData["id"].(string); ok {
			if uuid, err := uuid.Parse(id); err == nil {
				article.ID = uuid
			}
		}
		if postIDVal, ok := articleData["post_id"].(string); ok {
			if uuid, err := uuid.Parse(postIDVal); err == nil {
				article.PostID = uuid
			}
		}
		
		// Parse strings
		if title, ok := articleData["title"].(string); ok {
			article.Title = title
		}
		if subtitle, ok := articleData["subtitle"].(string); ok && subtitle != "" {
			article.Subtitle = subtitle
		}
		if contentHTML, ok := articleData["content_html"].(string); ok {
			article.ContentHTML = contentHTML
		}
		if coverImageURL, ok := articleData["cover_image_url"].(string); ok && coverImageURL != "" {
			article.CoverImageURL = coverImageURL
		}
		if metaTitle, ok := articleData["meta_title"].(string); ok && metaTitle != "" {
			article.MetaTitle = metaTitle
		}
		if metaDescription, ok := articleData["meta_description"].(string); ok && metaDescription != "" {
			article.MetaDescription = metaDescription
		}
		if slug, ok := articleData["slug"].(string); ok {
			article.Slug = slug
		}
		if category, ok := articleData["category"].(string); ok && category != "" {
			article.Category = category
		}
		
		// Parse integers
		if readTime, ok := articleData["read_time_minutes"].(float64); ok {
			article.ReadTimeMinutes = int(readTime)
		}
		if viewsCount, ok := articleData["views_count"].(float64); ok {
			article.ViewsCount = int(viewsCount)
		}
		if readsCount, ok := articleData["reads_count"].(float64); ok {
			article.ReadsCount = int(readsCount)
		}
		
		// Parse timestamps
		article.CreatedAt = parseRequiredTime(articleData["created_at"])
		article.UpdatedAt = parseRequiredTime(articleData["updated_at"])
	}

	// Add tags
	if len(article.Tags) > 0 {
		r.AddTags(ctx, article.ID, article.Tags)
	}

	return nil
}

// parseArticleFromMap parses an Article from a map[string]interface{} with custom timestamp handling
func (r *SupabaseArticleRepository) parseArticleFromMap(articleData map[string]interface{}) (*models.Article, error) {
	article := &models.Article{}
	
	// Parse timestamps
	parseTime := func(val interface{}) *time.Time {
		if val == nil {
			return nil
		}
		str, ok := val.(string)
		if !ok {
			return nil
		}
		
		if t, err := time.Parse(time.RFC3339, str); err == nil {
			return &t
		}
		if t, err := time.Parse(time.RFC3339Nano, str); err == nil {
			return &t
		}
		
		utc, _ := time.LoadLocation("UTC")
		if !strings.Contains(str, "Z") && !strings.Contains(str, "+") && len(str) > 10 {
			parts := strings.Split(str, ".")
			if len(parts) == 2 {
				fractional := parts[1]
				if len(fractional) > 6 {
					fractional = fractional[:6]
				} else if len(fractional) < 6 {
					fractional = fractional + strings.Repeat("0", 6-len(fractional))
				}
				normalized := parts[0] + "." + fractional
				if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", normalized, utc); err == nil {
					return &t
				}
			} else {
				if t, err := time.ParseInLocation("2006-01-02T15:04:05", str, utc); err == nil {
					return &t
				}
			}
		}
		
		return nil
	}

	parseRequiredTime := func(val interface{}) time.Time {
		if t := parseTime(val); t != nil {
			return *t
		}
		return time.Now()
	}

	// Parse IDs
	if id, ok := articleData["id"].(string); ok {
		if uuid, err := uuid.Parse(id); err == nil {
			article.ID = uuid
		}
	}
	if postIDVal, ok := articleData["post_id"].(string); ok {
		if uuid, err := uuid.Parse(postIDVal); err == nil {
			article.PostID = uuid
		}
	}
	
	// Parse strings
	if title, ok := articleData["title"].(string); ok {
		article.Title = title
	}
	if subtitle, ok := articleData["subtitle"].(string); ok && subtitle != "" {
		article.Subtitle = subtitle
	}
	if contentHTML, ok := articleData["content_html"].(string); ok {
		article.ContentHTML = contentHTML
	}
	if coverImageURL, ok := articleData["cover_image_url"].(string); ok && coverImageURL != "" {
		article.CoverImageURL = coverImageURL
	}
	if metaTitle, ok := articleData["meta_title"].(string); ok && metaTitle != "" {
		article.MetaTitle = metaTitle
	}
	if metaDescription, ok := articleData["meta_description"].(string); ok && metaDescription != "" {
		article.MetaDescription = metaDescription
	}
	if slug, ok := articleData["slug"].(string); ok {
		article.Slug = slug
	}
	if category, ok := articleData["category"].(string); ok && category != "" {
		article.Category = category
	}
	
	// Parse integers
	if readTime, ok := articleData["read_time_minutes"].(float64); ok {
		article.ReadTimeMinutes = int(readTime)
	}
	if viewsCount, ok := articleData["views_count"].(float64); ok {
		article.ViewsCount = int(viewsCount)
	}
	if readsCount, ok := articleData["reads_count"].(float64); ok {
		article.ReadsCount = int(readsCount)
	}
	
	// Parse timestamps
	article.CreatedAt = parseRequiredTime(articleData["created_at"])
	article.UpdatedAt = parseRequiredTime(articleData["updated_at"])

	return article, nil
}

// GetArticle retrieves an article by ID
func (r *SupabaseArticleRepository) GetArticle(ctx context.Context, articleID uuid.UUID) (*models.Article, error) {
	query := fmt.Sprintf("?id=eq.%s&select=*", articleID.String())

	data, err := r.makeRequest("GET", "articles", query, nil)
	if err != nil {
		return nil, err
	}

	// Parse as map first to handle timestamps
	var articlesData []map[string]interface{}
	if err := json.Unmarshal(data, &articlesData); err != nil {
		return nil, err
	}

	if len(articlesData) == 0 {
		return nil, fmt.Errorf("article not found")
	}

	article, err := r.parseArticleFromMap(articlesData[0])
	if err != nil {
		return nil, err
	}

	// Load tags
	tags, _ := r.GetArticleTags(ctx, articleID)
	article.Tags = tags

	return article, nil
}

// GetArticleBySlug retrieves an article by its URL slug
// Supports both old format (title-only) and new format (title-uniqueid)
func (r *SupabaseArticleRepository) GetArticleBySlug(ctx context.Context, slugStr string) (*models.Article, error) {
	// Log original slug
	fmt.Printf("[GetArticleBySlug] Original slug: %q\n", slugStr)
	
	// URL decode the slug in case it's encoded
	if decoded, err := url.QueryUnescape(slugStr); err == nil {
		slugStr = strings.TrimSpace(decoded)
		fmt.Printf("[GetArticleBySlug] After URL decode: %q\n", slugStr)
	} else {
		slugStr = strings.TrimSpace(slugStr)
	}
	
	// For slugs with unique IDs (new format: title-uniqueid), preserve the case of the unique ID
	// The unique ID is always 12 characters and comes after the last hyphen
	// Format: {title-slug}-{12-char-unique-id}
	lastHyphenIndex := strings.LastIndex(slugStr, "-")
	if lastHyphenIndex > 0 {
		// Check if what comes after the last hyphen looks like a unique ID (12 chars, alphanumeric)
		potentialID := slugStr[lastHyphenIndex+1:]
		if len(potentialID) == 12 {
			// This is likely a unique ID, preserve its case
			titlePart := strings.ToLower(slugStr[:lastHyphenIndex])
			slugStr = titlePart + "-" + potentialID
			fmt.Printf("[GetArticleBySlug] Preserved unique ID case: %q\n", slugStr)
		} else {
			// Old format or different structure, lowercase everything
			slugStr = strings.ToLower(slugStr)
		}
	} else {
		// Old format (no unique ID), lowercase everything
		slugStr = strings.ToLower(slugStr)
	}
	
	// Try exact match first (for new format with unique ID)
	// URL encode the slug value for Supabase PostgREST (handles special characters)
	encodedSlug := url.QueryEscape(slugStr)
	query := fmt.Sprintf("?slug=eq.%s&select=*", encodedSlug)
	
	fmt.Printf("[GetArticleBySlug] Query string: %q\n", query)
	fmt.Printf("[GetArticleBySlug] Full URL will be: /rest/v1/articles%s\n", query)

	data, err := r.makeRequest("GET", "articles", query, nil)
	if err != nil {
		fmt.Printf("[GetArticleBySlug] makeRequest error: %v\n", err)
		return nil, fmt.Errorf("failed to query article: %w", err)
	}

	fmt.Printf("[GetArticleBySlug] Response data length: %d bytes\n", len(data))

	// Parse as map first to handle timestamps properly
	var articlesData []map[string]interface{}
	if err := json.Unmarshal(data, &articlesData); err != nil {
		fmt.Printf("[GetArticleBySlug] JSON unmarshal error: %v\n", err)
		return nil, fmt.Errorf("failed to parse article: %w", err)
	}

	fmt.Printf("[GetArticleBySlug] Found %d articles\n", len(articlesData))

	if len(articlesData) == 0 {
		return nil, fmt.Errorf("article not found for slug: %s", slugStr)
	}

	// Use custom parser to handle timestamps correctly
	article, err := r.parseArticleFromMap(articlesData[0])
	if err != nil {
		fmt.Printf("[GetArticleBySlug] parseArticleFromMap error: %v\n", err)
		return nil, fmt.Errorf("failed to parse article: %w", err)
	}

	tags, _ := r.GetArticleTags(ctx, article.ID)
	article.Tags = tags

	return article, nil
}

// GetArticleByPostID retrieves an article by post ID
func (r *SupabaseArticleRepository) GetArticleByPostID(ctx context.Context, postID uuid.UUID) (*models.Article, error) {
	query := fmt.Sprintf("?post_id=eq.%s&select=*", postID.String())

	data, err := r.makeRequest("GET", "articles", query, nil)
	if err != nil {
		return nil, err
	}

	// Parse as map first to handle timestamps
	var articlesData []map[string]interface{}
	if err := json.Unmarshal(data, &articlesData); err != nil {
		return nil, err
	}

	if len(articlesData) == 0 {
		return nil, fmt.Errorf("article not found")
	}

	return r.parseArticleFromMap(articlesData[0])
}

// UpdateArticle updates an article
func (r *SupabaseArticleRepository) UpdateArticle(ctx context.Context, articleID uuid.UUID, updates map[string]interface{}) error {
	query := fmt.Sprintf("?id=eq.%s", articleID.String())

	_, err := r.makeRequest("PATCH", "articles", query, updates)
	return err
}

// IncrementViews increments the view count
func (r *SupabaseArticleRepository) IncrementViews(ctx context.Context, articleID uuid.UUID) error {
	// Naive increment: read then write (may have race conditions under heavy load)
	article, err := r.GetArticle(ctx, articleID)
	if err != nil {
		return err
	}
	newCount := article.ViewsCount + 1
	updates := map[string]interface{}{
		"views_count": newCount,
	}
	return r.UpdateArticle(ctx, articleID, updates)
}

// RecordRead records that a user fully read an article
func (r *SupabaseArticleRepository) RecordRead(ctx context.Context, articleID, userID uuid.UUID) error {
	// Naive increment for reads_count
	article, err := r.GetArticle(ctx, articleID)
	if err != nil {
		return err
	}
	newCount := article.ReadsCount + 1
	updates := map[string]interface{}{
		"reads_count": newCount,
	}
	return r.UpdateArticle(ctx, articleID, updates)
}

// AddTags adds tags to an article
func (r *SupabaseArticleRepository) AddTags(ctx context.Context, articleID uuid.UUID, tags []string) error {
	for _, tag := range tags {
		payload := map[string]interface{}{
			"article_id": articleID,
			"tag":        strings.ToLower(tag),
		}

		r.makeRequest("POST", "article_tags", "", payload)
	}

	return nil
}

// GetArticleTags retrieves tags for an article
func (r *SupabaseArticleRepository) GetArticleTags(ctx context.Context, articleID uuid.UUID) ([]string, error) {
	query := fmt.Sprintf("?article_id=eq.%s&select=tag", articleID.String())

	data, err := r.makeRequest("GET", "article_tags", query, nil)
	if err != nil {
		return []string{}, nil
	}

	var tagRecords []struct {
		Tag string `json:"tag"`
	}
	if err := json.Unmarshal(data, &tagRecords); err != nil {
		return []string{}, nil
	}

	tags := make([]string, len(tagRecords))
	for i, record := range tagRecords {
		tags[i] = record.Tag
	}

	return tags, nil
}

// generateUniqueSlug generates a unique URL slug for an article with a unique ID suffix
func (r *SupabaseArticleRepository) generateUniqueSlug(ctx context.Context, title string) string {
	baseSlug := slug.Make(title)
	
	// Ensure base slug is lowercase (slug.Make should already do this, but be safe)
	baseSlug = strings.ToLower(baseSlug)
	
	// Generate a short unique ID (12 characters: lowercase alphanumeric only)
	// Must be lowercase to comply with database constraint
	uniqueID := generateShortID()
	uniqueSlug := fmt.Sprintf("%s-%s", baseSlug, uniqueID)
	
	// Check if slug exists (very unlikely with UUID, but check anyway)
	counter := 0
	for {
		query := fmt.Sprintf("?slug=eq.%s&select=id", uniqueSlug)
		data, err := r.makeRequest("GET", "articles", query, nil)
		if err != nil {
			break
		}

		var existing []map[string]interface{}
		if err := json.Unmarshal(data, &existing); err != nil || len(existing) == 0 {
			break
		}

		// If slug exists (extremely rare), generate a new ID
		uniqueID = generateShortID()
		uniqueSlug = fmt.Sprintf("%s-%s", baseSlug, uniqueID)
		counter++

		// Safety limit
		if counter > 5 {
			// Use full UUID as last resort (lowercase)
			uuidStr := strings.ToLower(strings.ReplaceAll(uuid.New().String(), "-", ""))
			uniqueSlug = fmt.Sprintf("%s-%s", baseSlug, uuidStr)
			break
		}
	}

	return uniqueSlug
}

// generateShortID generates a short, readable unique ID (12 characters)
// Format: lowercase letters and numbers only (e.g., "094ab79oapux")
// Must be lowercase to comply with database slug constraint
func generateShortID() string {
	// Use UUID and convert to a readable alphanumeric format
	u := uuid.New()
	id := strings.ReplaceAll(u.String(), "-", "")
	
	// Convert hex characters to lowercase alphanumeric
	// Pattern: numbers stay as-is, hex letters become lowercase letters
	result := make([]byte, 12)
	for i := 0; i < 12 && i < len(id); i++ {
		char := id[i]
		switch {
		case char >= '0' && char <= '9':
			// Keep numbers as-is
			result[i] = char
		case char >= 'a' && char <= 'f':
			// Keep hex letters as lowercase
			result[i] = char
		case char >= 'A' && char <= 'F':
			// Convert uppercase hex to lowercase
			result[i] = char + 32 // A->a, B->b, etc.
		default:
			// Fallback: use modulo to get a valid lowercase character
			result[i] = 'a' + (char % 26)
		}
	}
	return string(result)
}
