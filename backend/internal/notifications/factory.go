package notifications

import (
	"fmt"
	"time"

	"histeeria-backend/internal/models"

	"github.com/google/uuid"
)

// NotificationFactory creates different types of notifications with proper formatting
type NotificationFactory struct{}

// NewNotificationFactory creates a new notification factory
func NewNotificationFactory() *NotificationFactory {
	return &NotificationFactory{}
}

// =====================================================
// SOCIAL NOTIFICATIONS
// =====================================================

// NewFollowNotification creates a notification when someone follows a user
func (f *NotificationFactory) NewFollowNotification(followerID, followedID uuid.UUID, followerUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", followerUsername)
	actionType := "follow_back"

	return &models.Notification{
		UserID:       followedID,
		Type:         models.NotificationFollow,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s started following you", followerUsername),
		Message:      nil,
		ActorID:      &followerID,
		ActionURL:    &actionURL,
		IsActionable: true,
		ActionType:   &actionType,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30), // 30 days
	}
}

// NewFollowBackNotification creates a notification when the followed user follows back
func (f *NotificationFactory) NewFollowBackNotification(followerID, followedID uuid.UUID, followerUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", followerUsername)

	return &models.Notification{
		UserID:       followedID,
		Type:         models.NotificationFollowBack,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s followed you back", followerUsername),
		Message:      nil,
		ActorID:      &followerID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}

// NewConnectionRequestNotification creates a notification for connection requests
func (f *NotificationFactory) NewConnectionRequestNotification(fromID, toID uuid.UUID, fromUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", fromUsername)
	actionType := "accept_connection"
	message := "wants to connect with you"

	return &models.Notification{
		UserID:       toID,
		Type:         models.NotificationConnectionRequest,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s wants to connect", fromUsername),
		Message:      &message,
		ActorID:      &fromID,
		ActionURL:    &actionURL,
		IsActionable: true,
		ActionType:   &actionType,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"request_id": fromID.String(),
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// NewConnectionAcceptedNotification creates a notification when connection is accepted
func (f *NotificationFactory) NewConnectionAcceptedNotification(acceptorID, requesterID uuid.UUID, acceptorUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", acceptorUsername)
	message := "accepted your connection request"

	return &models.Notification{
		UserID:       requesterID,
		Type:         models.NotificationConnectionAccepted,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s is now your connection", acceptorUsername),
		Message:      &message,
		ActorID:      &acceptorID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}

// NewConnectionRejectedNotification creates a notification when connection is rejected
func (f *NotificationFactory) NewConnectionRejectedNotification(rejecterID, requesterID uuid.UUID, rejecterUsername string) *models.Notification {
	message := "declined your connection request"

	return &models.Notification{
		UserID:       requesterID,
		Type:         models.NotificationConnectionRejected,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s declined your request", rejecterUsername),
		Message:      &message,
		ActorID:      &rejecterID,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}

// NewCollaborationRequestNotification creates a notification for collaboration requests
func (f *NotificationFactory) NewCollaborationRequestNotification(fromID, toID uuid.UUID, fromUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", fromUsername)
	actionType := "accept_collaboration"
	message := "wants to collaborate with you"

	return &models.Notification{
		UserID:       toID,
		Type:         models.NotificationCollaborationRequest,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s wants to collaborate", fromUsername),
		Message:      &message,
		ActorID:      &fromID,
		ActionURL:    &actionURL,
		IsActionable: true,
		ActionType:   &actionType,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"request_id": fromID.String(),
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// NewCollaborationAcceptedNotification creates a notification when collaboration is accepted
func (f *NotificationFactory) NewCollaborationAcceptedNotification(acceptorID, requesterID uuid.UUID, acceptorUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/profile/%s", acceptorUsername)
	message := "accepted your collaboration request"

	return &models.Notification{
		UserID:       requesterID,
		Type:         models.NotificationCollaborationAccepted,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s is now your collaborator", acceptorUsername),
		Message:      &message,
		ActorID:      &acceptorID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}

// NewCollaborationRejectedNotification creates a notification when collaboration is rejected
func (f *NotificationFactory) NewCollaborationRejectedNotification(rejecterID, requesterID uuid.UUID, rejecterUsername string) *models.Notification {
	message := "declined your collaboration request"

	return &models.Notification{
		UserID:       requesterID,
		Type:         models.NotificationCollaborationRejected,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s declined your collaboration", rejecterUsername),
		Message:      &message,
		ActorID:      &rejecterID,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// FUTURE: MESSAGE NOTIFICATIONS
// =====================================================

// NewMessageNotification creates a notification for new messages
func (f *NotificationFactory) NewMessageNotification(senderID, receiverID uuid.UUID, senderUsername, messagePreview string) *models.Notification {
	actionURL := fmt.Sprintf("/messages/%s", senderID.String())
	message := messagePreview

	return &models.Notification{
		UserID:       receiverID,
		Type:         models.NotificationMessage,
		Category:     models.CategoryMessages,
		Title:        fmt.Sprintf("New message from %s", senderUsername),
		Message:      &message,
		ActorID:      &senderID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"conversation_id": senderID.String(),
			"preview":         messagePreview,
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// FUTURE: POST/FEED NOTIFICATIONS
// =====================================================

// NewPostLikeNotification creates a notification when someone likes a post
func (f *NotificationFactory) NewPostLikeNotification(likerID, postOwnerID, postID uuid.UUID, likerUsername string) *models.Notification {
	actionURL := fmt.Sprintf("/posts/%s", postID.String())
	message := "liked your post"

	return &models.Notification{
		UserID:       postOwnerID,
		Type:         models.NotificationPostLike,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s liked your post", likerUsername),
		Message:      &message,
		ActorID:      &likerID,
		TargetID:     &postID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"post_id": postID.String(),
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// NewPostCommentNotification creates a notification when someone comments on a post
func (f *NotificationFactory) NewPostCommentNotification(commenterID, postOwnerID, postID uuid.UUID, commenterUsername, commentPreview string) *models.Notification {
	actionURL := fmt.Sprintf("/posts/%s", postID.String())
	message := fmt.Sprintf("commented: %s", commentPreview)

	return &models.Notification{
		UserID:       postOwnerID,
		Type:         models.NotificationPostComment,
		Category:     models.CategorySocial,
		Title:        fmt.Sprintf("%s commented on your post", commenterUsername),
		Message:      &message,
		ActorID:      &commenterID,
		TargetID:     &postID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"post_id":         postID.String(),
			"comment_preview": commentPreview,
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// FUTURE: PROJECT NOTIFICATIONS
// =====================================================

// NewProjectInviteNotification creates a notification for project invites
func (f *NotificationFactory) NewProjectInviteNotification(inviterID, inviteeID, projectID uuid.UUID, inviterUsername, projectName string) *models.Notification {
	actionURL := fmt.Sprintf("/projects/%s", projectID.String())
	actionType := "accept_project_invite"
	message := fmt.Sprintf("invited you to join %s", projectName)

	return &models.Notification{
		UserID:       inviteeID,
		Type:         models.NotificationProjectInvite,
		Category:     models.CategoryProjects,
		Title:        fmt.Sprintf("Project invitation from %s", inviterUsername),
		Message:      &message,
		ActorID:      &inviterID,
		TargetID:     &projectID,
		ActionURL:    &actionURL,
		IsActionable: true,
		ActionType:   &actionType,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"project_id":   projectID.String(),
			"project_name": projectName,
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// FUTURE: COMMUNITY NOTIFICATIONS
// =====================================================

// NewCommunityInviteNotification creates a notification for community invites
func (f *NotificationFactory) NewCommunityInviteNotification(inviterID, inviteeID, communityID uuid.UUID, inviterUsername, communityName string) *models.Notification {
	actionURL := fmt.Sprintf("/communities/%s", communityID.String())
	actionType := "accept_community_invite"
	message := fmt.Sprintf("invited you to join %s", communityName)

	return &models.Notification{
		UserID:       inviteeID,
		Type:         models.NotificationCommunityInvite,
		Category:     models.CategoryCommunities,
		Title:        fmt.Sprintf("Community invitation from %s", inviterUsername),
		Message:      &message,
		ActorID:      &inviterID,
		TargetID:     &communityID,
		ActionURL:    &actionURL,
		IsActionable: true,
		ActionType:   &actionType,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"community_id":   communityID.String(),
			"community_name": communityName,
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// FUTURE: PAYMENT NOTIFICATIONS
// =====================================================

// NewPaymentReceivedNotification creates a notification for received payments
func (f *NotificationFactory) NewPaymentReceivedNotification(senderID, receiverID uuid.UUID, amount float64, currency, senderUsername string) *models.Notification {
	actionURL := "/payments"
	message := fmt.Sprintf("sent you %s %.2f", currency, amount)

	return &models.Notification{
		UserID:       receiverID,
		Type:         models.NotificationPaymentReceived,
		Category:     models.CategoryPayments,
		Title:        fmt.Sprintf("Payment from %s", senderUsername),
		Message:      &message,
		ActorID:      &senderID,
		ActionURL:    &actionURL,
		IsActionable: false,
		ActionTaken:  false,
		Metadata: map[string]interface{}{
			"amount":   amount,
			"currency": currency,
		},
		CreatedAt: time.Now(),
		ExpiresAt: time.Now().AddDate(0, 0, 30),
	}
}

// =====================================================
// SYSTEM NOTIFICATIONS
// =====================================================

// NewSystemAnnouncementNotification creates a system announcement notification
func (f *NotificationFactory) NewSystemAnnouncementNotification(userID uuid.UUID, title, message string) *models.Notification {
	return &models.Notification{
		UserID:       userID,
		Type:         models.NotificationSystemAnnouncement,
		Category:     models.CategorySystem,
		Title:        title,
		Message:      &message,
		ActorID:      nil,
		IsActionable: false,
		ActionTaken:  false,
		Metadata:     map[string]interface{}{},
		CreatedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 0, 30),
	}
}
