package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	apperr "histeeria-backend/pkg/errors"

	"github.com/google/uuid"
)

// SupabaseAccountGroupRepository implements AccountGroupRepository using Supabase
type SupabaseAccountGroupRepository struct {
	supabaseURL    string
	supabaseAPIKey string
	httpClient     *http.Client
}

// NewSupabaseAccountGroupRepository creates a new Supabase account group repository
func NewSupabaseAccountGroupRepository(supabaseURL, supabaseAPIKey string) AccountGroupRepository {
	return &SupabaseAccountGroupRepository{
		supabaseURL:    supabaseURL,
		supabaseAPIKey: supabaseAPIKey,
		httpClient:     &http.Client{},
	}
}

// GetAccountGroupForUser returns the account group ID for a user
func (r *SupabaseAccountGroupRepository) GetAccountGroupForUser(ctx context.Context, userID uuid.UUID) (*uuid.UUID, error) {
	// Call the database function
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/get_account_group_for_user", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"user_uuid": userID.String(),
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error getting account group: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.NewAppError(resp.StatusCode, "failed to get account group")
	}

	var groupID string
	if err := json.NewDecoder(resp.Body).Decode(&groupID); err != nil {
		// Try parsing as array
		var results []string
		if err2 := json.NewDecoder(resp.Body).Decode(&results); err2 == nil && len(results) > 0 {
			groupID = results[0]
		} else {
			return nil, fmt.Errorf("failed to decode response: %w", err)
		}
	}

	if groupID == "" || groupID == "null" {
		return nil, nil // No account group found
	}

	parsedUUID, err := uuid.Parse(groupID)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID format: %w", err)
	}

	return &parsedUUID, nil
}

// GetLinkedAccounts returns all accounts linked to the user's account group
func (r *SupabaseAccountGroupRepository) GetLinkedAccounts(ctx context.Context, userID uuid.UUID) ([]LinkedAccount, error) {
	// First get the account group ID
	groupID, err := r.GetAccountGroupForUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	if groupID == nil {
		// User has no account group, return empty list
		return []LinkedAccount{}, nil
	}

	// Call the database function to get all accounts in the group
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/get_accounts_in_group", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"group_id": groupID.String(),
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error getting linked accounts: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.NewAppError(resp.StatusCode, "failed to get linked accounts")
	}

	var accounts []LinkedAccount
	if err := json.NewDecoder(resp.Body).Decode(&accounts); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return accounts, nil
}

// CreateAccountGroupWithUser creates a new account group and adds the first user
func (r *SupabaseAccountGroupRepository) CreateAccountGroupWithUser(ctx context.Context, userID uuid.UUID, isPrimary bool) (*uuid.UUID, error) {
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/create_account_group_with_user", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"user_uuid":  userID.String(),
		"is_primary": isPrimary,
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=representation")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error creating account group: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return nil, apperr.NewAppError(resp.StatusCode, "failed to create account group")
	}

	var groupID string
	if err := json.NewDecoder(resp.Body).Decode(&groupID); err != nil {
		// Try parsing as array
		var results []string
		if err2 := json.NewDecoder(resp.Body).Decode(&results); err2 == nil && len(results) > 0 {
			groupID = results[0]
		} else {
			return nil, fmt.Errorf("failed to decode response: %w", err)
		}
	}

	parsedUUID, err := uuid.Parse(groupID)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID format: %w", err)
	}

	return &parsedUUID, nil
}

// AddUserToAccountGroup adds a user to an existing account group
func (r *SupabaseAccountGroupRepository) AddUserToAccountGroup(ctx context.Context, groupID, userID uuid.UUID, isPrimary bool) error {
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/add_user_to_account_group", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"group_uuid": groupID.String(),
		"user_uuid":  userID.String(),
		"is_primary": isPrimary,
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error adding user to account group: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return apperr.NewAppError(resp.StatusCode, "failed to add user to account group")
	}

	return nil
}

// RemoveUserFromAccountGroup removes a user from an account group
func (r *SupabaseAccountGroupRepository) RemoveUserFromAccountGroup(ctx context.Context, groupID, userID uuid.UUID) error {
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/remove_user_from_account_group", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"group_uuid": groupID.String(),
		"user_uuid":  userID.String(),
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error removing user from account group: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return apperr.NewAppError(resp.StatusCode, "failed to remove user from account group")
	}

	return nil
}

// SetPrimaryAccount sets which account is primary in a group
func (r *SupabaseAccountGroupRepository) SetPrimaryAccount(ctx context.Context, groupID, userID uuid.UUID) error {
	funcURL := fmt.Sprintf("%s/rest/v1/rpc/set_primary_account", r.supabaseURL)
	
	reqBody := map[string]interface{}{
		"group_uuid": groupID.String(),
		"user_uuid":  userID.String(),
	}
	
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, funcURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", r.supabaseAPIKey)
	req.Header.Set("Authorization", "Bearer "+r.supabaseAPIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("[AccountGroupRepo] Error setting primary account: status=%d, body=%s", resp.StatusCode, string(bodyBytes))
		return apperr.NewAppError(resp.StatusCode, "failed to set primary account")
	}

	return nil
}

// VerifyUserInGroup checks if two users belong to the same account group
func (r *SupabaseAccountGroupRepository) VerifyUserInGroup(ctx context.Context, userID1, userID2 uuid.UUID) (bool, error) {
	groupID1, err := r.GetAccountGroupForUser(ctx, userID1)
	if err != nil {
		return false, err
	}

	groupID2, err := r.GetAccountGroupForUser(ctx, userID2)
	if err != nil {
		return false, err
	}

	// Both must have groups and they must be the same
	if groupID1 == nil || groupID2 == nil {
		return false, nil
	}

	return *groupID1 == *groupID2, nil
}
