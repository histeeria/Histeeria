# Backend Endpoint Requirement

## Required Endpoint

The article page requires a **public** backend endpoint to fetch articles by slug:

```
GET /api/v1/articles/:slug
```

### Expected Response

```json
{
  "success": true,
  "post": {
    "id": "uuid",
    "post_type": "article",
    "author": {
      "id": "uuid",
      "username": "author_username",
      "display_name": "Author Name",
      "profile_picture": "url",
      "is_verified": false
    },
    "article": {
      "id": "uuid",
      "post_id": "uuid",
      "title": "Article Title",
      "subtitle": "Article Subtitle",
      "content_html": "<p>Article content...</p>",
      "cover_image_url": "url",
      "meta_title": "SEO Title",
      "meta_description": "SEO Description",
      "slug": "article-slug",
      "read_time_minutes": 5,
      "category": "Technology",
      "views_count": 100,
      "reads_count": 50,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "tags": ["tag1", "tag2"]
    },
    "likes_count": 10,
    "comments_count": 5,
    "shares_count": 2,
    "is_liked": false,
    "is_saved": false,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### Important Notes

1. **Public Endpoint**: This endpoint should be **publicly accessible** (no authentication required) so articles can be shared and indexed by search engines.

2. **Slug Lookup**: The endpoint should use the `GetArticleBySlug` method from the repository which already exists in `backend/internal/repository/supabase_article_repository.go`.

3. **Post Association**: The response should include the full post object with author information, engagement counts, etc.

4. **Error Handling**: Return 404 if article not found:
   ```json
   {
     "success": false,
     "error": "Article not found"
   }
   ```

### Implementation Suggestion

Add this handler to `backend/internal/posts/handlers.go`:

```go
// GetArticleBySlug handles GET /api/v1/articles/:slug (PUBLIC)
func (h *Handlers) GetArticleBySlug(c *gin.Context) {
    slug := c.Param("slug")
    if slug == "" {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Slug is required"})
        return
    }

    // Get viewer ID (optional - for engagement state)
    var viewerID uuid.UUID
    if userID, exists := c.Get("user_id"); exists {
        viewerID, _ = uuid.Parse(userID.(string))
    }

    // Get article by slug
    article, err := h.service.GetArticleBySlug(c.Request.Context(), slug, viewerID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Article not found"})
        return
    }

    c.JSON(http.StatusOK, models.PostResponse{
        Success: true,
        Post:    article,
    })
}
```

And add the route in `backend/main.go` (in the public API group, not protected):

```go
// Public article routes (no auth required)
api.GET("/articles/:slug", postHandlers.GetArticleBySlug)
```

### Current Status

- ✅ Frontend page created at `/articles/[slug]`
- ✅ API function added to `postsAPI.getArticleBySlug()`
- ⏳ Backend endpoint needs to be implemented

