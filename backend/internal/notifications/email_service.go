package notifications

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"log"

	"histeeria-backend/internal/models"
	"histeeria-backend/internal/utils"
)

// EmailService handles sending notification emails
type EmailService struct {
	emailSvc *utils.EmailService
	baseURL  string
}

// NewEmailService creates a new email notification service
func NewEmailService(emailSvc *utils.EmailService, baseURL string) *EmailService {
	return &EmailService{
		emailSvc: emailSvc,
		baseURL:  baseURL,
	}
}

// SendNotificationEmail sends an email for a notification
func (s *EmailService) SendNotificationEmail(ctx context.Context, userEmail string, notification *models.Notification) error {
	if s.emailSvc == nil {
		log.Println("[EmailService] Email service not configured, skipping email")
		return nil
	}

	subject, htmlBody, textBody := s.buildEmailContent(notification)

	if err := s.emailSvc.SendEmail(userEmail, subject, htmlBody, textBody); err != nil {
		log.Printf("[EmailService] Failed to send email to %s: %v", userEmail, err)
		return fmt.Errorf("failed to send email: %w", err)
	}

	log.Printf("[EmailService] Email sent successfully to %s for notification type: %s", userEmail, notification.Type)
	return nil
}

// SendDigestEmail sends a digest email with multiple notifications
func (s *EmailService) SendDigestEmail(ctx context.Context, userEmail string, notifications []*models.Notification, frequency models.EmailFrequency) error {
	if s.emailSvc == nil {
		log.Println("[EmailService] Email service not configured, skipping digest email")
		return nil
	}

	subject, htmlBody, textBody := s.buildDigestEmailContent(notifications, frequency)

	if err := s.emailSvc.SendEmail(userEmail, subject, htmlBody, textBody); err != nil {
		log.Printf("[EmailService] Failed to send digest email to %s: %v", userEmail, err)
		return fmt.Errorf("failed to send digest email: %w", err)
	}

	log.Printf("[EmailService] Digest email sent successfully to %s (%d notifications)", userEmail, len(notifications))
	return nil
}

// buildEmailContent creates email content based on notification type
func (s *EmailService) buildEmailContent(notification *models.Notification) (subject string, htmlBody string, textBody string) {
	var actorName string
	if notification.ActorUser != nil {
		actorName = notification.ActorUser.DisplayName
	}

	actionURL := s.baseURL + "/notifications"
	if notification.ActionURL != nil {
		actionURL = s.baseURL + *notification.ActionURL
	}

	switch notification.Type {
	case models.NotificationFollow:
		subject = fmt.Sprintf("%s started following you", actorName)
		htmlBody = s.renderFollowEmail(actorName, actionURL)
		textBody = fmt.Sprintf("%s started following you on Asteria.\n\nView profile: %s", actorName, actionURL)

	case models.NotificationConnectionRequest:
		subject = fmt.Sprintf("%s wants to connect with you", actorName)
		htmlBody = s.renderConnectionRequestEmail(actorName, actionURL)
		textBody = fmt.Sprintf("%s wants to connect with you on Asteria.\n\nRespond: %s", actorName, actionURL)

	case models.NotificationConnectionAccepted:
		subject = fmt.Sprintf("%s accepted your connection request", actorName)
		htmlBody = s.renderConnectionAcceptedEmail(actorName, actionURL)
		textBody = fmt.Sprintf("%s accepted your connection request on Asteria.\n\nView profile: %s", actorName, actionURL)

	case models.NotificationCollaborationRequest:
		subject = fmt.Sprintf("%s wants to collaborate with you", actorName)
		htmlBody = s.renderCollaborationRequestEmail(actorName, actionURL)
		textBody = fmt.Sprintf("%s wants to collaborate with you on Asteria.\n\nRespond: %s", actorName, actionURL)

	case models.NotificationCollaborationAccepted:
		subject = fmt.Sprintf("%s accepted your collaboration request", actorName)
		htmlBody = s.renderCollaborationAcceptedEmail(actorName, actionURL)
		textBody = fmt.Sprintf("%s accepted your collaboration request on Asteria.\n\nView profile: %s", actorName, actionURL)

	default:
		subject = notification.Title
		htmlBody = s.renderGenericEmail(notification.Title, notification.Message, actionURL)
		message := ""
		if notification.Message != nil {
			message = *notification.Message
		}
		textBody = fmt.Sprintf("%s\n\n%s\n\nView: %s", notification.Title, message, actionURL)
	}

	return subject, htmlBody, textBody
}

// buildDigestEmailContent creates digest email content
func (s *EmailService) buildDigestEmailContent(notifications []*models.Notification, frequency models.EmailFrequency) (subject string, htmlBody string, textBody string) {
	var period string
	if frequency == models.EmailFrequencyDaily {
		period = "Daily"
	} else {
		period = "Weekly"
	}

	subject = fmt.Sprintf("Your %s Asteria Digest - %d new notifications", period, len(notifications))
	htmlBody = s.renderDigestEmail(notifications, period)

	// Build text version
	textBuffer := bytes.NewBufferString(fmt.Sprintf("Your %s Asteria Digest\n\nYou have %d new notifications:\n\n", period, len(notifications)))
	for _, notif := range notifications {
		textBuffer.WriteString(fmt.Sprintf("• %s\n", notif.Title))
		if notif.Message != nil {
			textBuffer.WriteString(fmt.Sprintf("  %s\n", *notif.Message))
		}
		textBuffer.WriteString("\n")
	}
	textBuffer.WriteString(fmt.Sprintf("\nView all notifications: %s/notifications", s.baseURL))
	textBody = textBuffer.String()

	return subject, htmlBody, textBody
}

// HTML Email Templates

func (s *EmailService) renderFollowEmail(actorName, actionURL string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #7c3aed; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>New Follower</h1>
		</div>
		<div class="content">
			<p><strong>{{.ActorName}}</strong> started following you on Asteria!</p>
			<p>Connect with them and grow your professional network.</p>
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">View Profile</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("follow").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]string{"ActorName": actorName, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderConnectionRequestEmail(actorName, actionURL string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #3b82f6 0%, #60a5fa 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #3b82f6; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; margin: 0 5px; }
		.button-secondary { background: #e5e7eb; color: #374151; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Connection Request</h1>
		</div>
		<div class="content">
			<p><strong>{{.ActorName}}</strong> wants to connect with you on Asteria!</p>
			<p>Accept this request to build your professional network and unlock messaging.</p>
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">View Request</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("connection").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]string{"ActorName": actorName, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderConnectionAcceptedEmail(actorName, actionURL string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #10b981 0%, #34d399 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #10b981; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Connection Accepted</h1>
		</div>
		<div class="content">
			<p><strong>{{.ActorName}}</strong> accepted your connection request!</p>
			<p>You are now connected. Start messaging and collaborating together.</p>
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">Send Message</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("accepted").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]string{"ActorName": actorName, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderCollaborationRequestEmail(actorName, actionURL string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #f59e0b 0%, #fbbf24 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #f59e0b; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Collaboration Request</h1>
		</div>
		<div class="content">
			<p><strong>{{.ActorName}}</strong> wants to collaborate with you!</p>
			<p>Work together on exciting projects and achieve great things.</p>
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">View Request</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("collaboration").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]string{"ActorName": actorName, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderCollaborationAcceptedEmail(actorName, actionURL string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #f59e0b 0%, #fbbf24 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #f59e0b; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Collaboration Accepted</h1>
		</div>
		<div class="content">
			<p><strong>{{.ActorName}}</strong> accepted your collaboration request!</p>
			<p>Start working together on amazing projects.</p>
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">Start Collaborating</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("collab_accepted").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]string{"ActorName": actorName, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderGenericEmail(title string, message *string, actionURL string) string {
	msg := ""
	if message != nil {
		msg = *message
	}

	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.button { display: inline-block; background: #7c3aed; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Notification</h1>
		</div>
		<div class="content">
			<p><strong>{{.Title}}</strong></p>
			{{if .Message}}<p>{{.Message}}</p>{{end}}
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.ActionURL}}" class="button">View Notification</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("generic").Parse(tmpl))
	var buf bytes.Buffer
	t.Execute(&buf, map[string]interface{}{"Title": title, "Message": msg, "ActionURL": actionURL})
	return buf.String()
}

func (s *EmailService) renderDigestEmail(notifications []*models.Notification, period string) string {
	tmpl := `
<!DOCTYPE html>
<html>
<head>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
		.container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; }
		.header { background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%); padding: 30px; text-align: center; }
		.header h1 { color: white; margin: 0; font-size: 24px; }
		.content { padding: 30px; }
		.content p { color: #333; line-height: 1.6; margin: 0 0 20px 0; }
		.notification { background: #f9fafb; padding: 15px; border-radius: 8px; margin-bottom: 10px; }
		.notification h3 { margin: 0 0 5px 0; font-size: 14px; color: #111; }
		.notification p { margin: 0; font-size: 13px; color: #666; }
		.button { display: inline-block; background: #7c3aed; color: white; padding: 12px 30px; border-radius: 8px; text-decoration: none; font-weight: 600; }
		.footer { background: #f9fafb; padding: 20px; text-align: center; color: #6b7280; font-size: 12px; }
	</style>
</head>
<body>
	<div class="container">
		<div class="header">
			<h1>Your {{.Period}} Digest</h1>
		</div>
		<div class="content">
			<p>You have <strong>{{.Count}} new notifications</strong>:</p>
			{{range .Notifications}}
			<div class="notification">
				<h3>{{.Title}}</h3>
				{{if .Message}}<p>{{.Message}}</p>{{end}}
			</div>
			{{end}}
			<p style="text-align: center; margin-top: 30px;">
				<a href="{{.BaseURL}}/notifications" class="button">View All Notifications</a>
			</p>
		</div>
		<div class="footer">
			<p>Asteria • Building connections that matter</p>
			<p style="margin-top: 10px;"><a href="{{.BaseURL}}/settings" style="color: #7c3aed;">Manage email preferences</a></p>
		</div>
	</div>
</body>
</html>`

	t := template.Must(template.New("digest").Parse(tmpl))
	var buf bytes.Buffer

	data := map[string]interface{}{
		"Period":        period,
		"Count":         len(notifications),
		"Notifications": notifications,
		"BaseURL":       s.baseURL,
	}

	t.Execute(&buf, data)
	return buf.String()
}
