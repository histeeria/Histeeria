package utils

import (
	"fmt"
	"math/rand"
	"time"

	"histeeria-backend/internal/config"

	"net/smtp"

	"github.com/jordan-wright/email"
)

// EmailService handles email operations
type EmailService struct {
	config *config.EmailConfig
}

// NewEmailService creates a new email service
func NewEmailService(emailConfig *config.EmailConfig) *EmailService {
	return &EmailService{
		config: emailConfig,
	}
}

// GenerateVerificationCode generates a 6-digit verification code
func (e *EmailService) GenerateVerificationCode() string {
	rand.Seed(time.Now().UnixNano())
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

// SendVerificationEmail sends an email verification code
func (e *EmailService) SendVerificationEmail(to, code string) error {
	subject := "Verify Your Email Address - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
	<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<style>
		@media only screen and (max-width: 600px) {
			.mobile-padding { padding: 30px 20px !important; }
			.mobile-header-padding { padding: 30px 20px !important; }
			.mobile-footer-padding { padding: 20px 20px !important; }
			.mobile-content-padding { padding: 30px 20px 30px !important; }
			.mobile-text { font-size: 14px !important; }
			.mobile-title { font-size: 20px !important; }
		}
	</style>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
		<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
					<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px; width: 100%%;">
					<!-- Header -->
					<tr>
							<td class="mobile-header-padding" style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
								<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
							<td class="mobile-content-padding" style="padding: 50px 50px 40px;">
								<h2 class="mobile-title" style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Email Verification Required</h2>
								<p class="mobile-text" style="margin: 0 0 30px; color: #4a5568; font-size: 16px; line-height: 1.7;">Thank you for registering with Histeeria. To complete your account setup, please verify your email address using the verification code below.</p>
							
							<!-- Verification Code Box -->
								<table width="100%%" cellpadding="0" cellspacing="0" style="margin: 35px 0;">
									<tr>
										<td align="center" style="background-color: #f7f9fc; border: 2px solid #e2e8f0; border-radius: 6px; padding: 30px 20px;">
											<div style="font-size: 36px; font-weight: 700; color: #1a1f3a; letter-spacing: 8px; font-family: 'Courier New', monospace;">%s</div>
									</td>
								</tr>
							</table>
							
								<p class="mobile-text" style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">This verification code will expire in <strong style="color: #1a1f3a;">10 minutes</strong>.</p>
								
								<div style="margin-top: 40px; padding-top: 30px; border-top: 1px solid #e2e8f0;">
									<p class="mobile-text" style="margin: 0 0 15px; color: #718096; font-size: 13px; line-height: 1.6;">If you did not create an account with Histeeria, please disregard this email. No further action is required.</p>
							</div>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
							<td class="mobile-footer-padding" style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
								<p class="mobile-text" style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
								<p class="mobile-text" style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
									</td>
								</tr>
							</table>
					<!-- Footer Text -->
					<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; width: 100%%; margin-top: 20px;">
						<tr>
							<td align="center">
								<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, code, time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendPasswordResetEmail sends a password reset email
func (e *EmailService) SendPasswordResetEmail(to, resetToken string) error {
	subject := "Password Reset Request - Histeeria"
	resetURL := fmt.Sprintf("%s/auth/reset-password?token=%s", e.config.FrontendURL, resetToken)
	body := fmt.Sprintf(`
<!DOCTYPE html>
	<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
		<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
					<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
							<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
								<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
							<td style="padding: 50px 50px 40px;">
								<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Password Reset Request</h2>
								<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">We received a request to reset the password for your Histeeria account. Click the button below to proceed with resetting your password.</p>
							
							<!-- Reset Button -->
								<table width="100%%" cellpadding="0" cellspacing="0" style="margin: 35px 0;">
								<tr>
									<td align="center">
											<a href="%s" style="display: inline-block; background-color: #1a1f3a; color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 6px; font-size: 16px; font-weight: 600; letter-spacing: 0.3px; text-align: center;">Reset Password</a>
									</td>
								</tr>
							</table>
							
								<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">Alternatively, copy and paste this link into your browser:</p>
								<p style="margin: 10px 0 0; color: #4a5568; font-size: 13px; word-break: break-all; font-family: 'Courier New', monospace; background-color: #f7f9fc; padding: 12px; border-radius: 4px; border: 1px solid #e2e8f0;">%s</p>
								
								<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">This password reset link will expire in <strong style="color: #1a1f3a;">1 hour</strong>.</p>
								
								<div style="margin-top: 40px; padding-top: 30px; border-top: 1px solid #e2e8f0;">
									<p style="margin: 0 0 15px; color: #718096; font-size: 13px; line-height: 1.6;">If you did not request a password reset, please ignore this email. Your account security remains unchanged.</p>
							</div>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
							<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
								<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
								<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
									</td>
								</tr>
							</table>
					<!-- Footer Text -->
					<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
						<tr>
							<td align="center">
								<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, resetURL, resetURL, time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendWelcomeEmail sends a welcome email after successful verification
func (e *EmailService) SendWelcomeEmail(to, displayName string) error {
	subject := "Welcome to Histeeria"
	body := fmt.Sprintf(`
	<!DOCTYPE html>
		<html>
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<style>
			@media only screen and (max-width: 600px) {
				.mobile-padding { padding: 30px 20px !important; }
				.mobile-header-padding { padding: 30px 20px !important; }
				.mobile-footer-padding { padding: 20px 20px !important; }
				.mobile-content-padding { padding: 30px 20px 30px !important; }
				.mobile-feature-padding { padding: 20px !important; }
				.mobile-text { font-size: 14px !important; }
				.mobile-title { font-size: 20px !important; }
			}
		</style>
	</head>
	<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
		<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
			<tr>
				<td align="center">
					<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px; width: 100%%;">
						<!-- Header -->
						<tr>
							<td class="mobile-header-padding" style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
								<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
							</td>
						</tr>
						<!-- Content -->
						<tr>
							<td class="mobile-content-padding" style="padding: 50px 50px 40px;">
								<h2 class="mobile-title" style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Welcome, %s</h2>
								<p class="mobile-text" style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Your email address has been successfully verified. Your Histeeria account is now active and ready to use.</p>
								
								<!-- Features Section -->
								<div class="mobile-feature-padding" style="margin: 35px 0; padding: 30px; background-color: #f7f9fc; border-radius: 6px; border-left: 4px solid #1a1f3a;">
									<p class="mobile-text" style="margin: 0 0 20px; color: #1a1f3a; font-size: 16px; font-weight: 600;">Get started with Histeeria:</p>
									<table width="100%%" cellpadding="0" cellspacing="0">
										<tr>
											<td style="padding: 12px 0; border-bottom: 1px solid #e2e8f0;">
												<p class="mobile-text" style="margin: 0; color: #4a5568; font-size: 15px; line-height: 1.6;">Connect with industry professionals and expand your network</p>
											</td>
										</tr>
										<tr>
											<td style="padding: 12px 0; border-bottom: 1px solid #e2e8f0;">
												<p class="mobile-text" style="margin: 0; color: #4a5568; font-size: 15px; line-height: 1.6;">Showcase your projects and build your professional portfolio</p>
											</td>
										</tr>
										<tr>
											<td style="padding: 12px 0; border-bottom: 1px solid #e2e8f0;">
												<p class="mobile-text" style="margin: 0; color: #4a5568; font-size: 15px; line-height: 1.6;">Discover exclusive freelance and collaboration opportunities</p>
											</td>
										</tr>
										<tr>
											<td style="padding: 12px 0;">
												<p class="mobile-text" style="margin: 0; color: #4a5568; font-size: 15px; line-height: 1.6;">Access premium resources and industry insights</p>
											</td>
										</tr>
									</table>
								</div>
								
								<div class="mobile-feature-padding" style="margin-top: 35px; padding: 25px; background-color: #f7f9fc; border-radius: 6px;">
									<p class="mobile-text" style="margin: 0 0 10px; color: #1a1f3a; font-size: 15px; font-weight: 600;">Need assistance?</p>
									<p class="mobile-text" style="margin: 0; color: #718096; font-size: 14px; line-height: 1.6;">Team Histeeria is available to help you get the most out of your Histeeria experience.</p>
								</div>
							</td>
						</tr>
						<!-- Footer -->
						<tr>
							<td class="mobile-footer-padding" style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
								<p class="mobile-text" style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
								<p class="mobile-text" style="margin: 0; color: #a0aec0; font-size: 12px;">Thank you for joining our community.</p>
							</td>
						</tr>
					</table>
					<!-- Footer Text -->
					<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
						<tr>
							<td align="center">
								<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
							</td>
						</tr>
					</table>
				</td>
			</tr>
		</table>
		</body>
		</html>
	`, displayName, time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// sendEmail is a helper method to send emails
func (e *EmailService) sendEmail(to, subject, body string) error {
	mail := email.NewEmail()
	mail.From = fmt.Sprintf("%s <%s>", e.config.FromName, e.config.FromEmail)
	mail.To = []string{to}
	mail.Subject = subject
	mail.HTML = []byte(body)

	// Send email using SMTP
	err := mail.Send(fmt.Sprintf("%s:%d", e.config.Host, e.config.Port),
		smtp.PlainAuth("", e.config.Username, e.config.Password, e.config.Host))

	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	return nil
}

// SendEmail is a public method to send emails with HTML and text bodies
func (e *EmailService) SendEmail(to, subject, htmlBody, textBody string) error {
	mail := email.NewEmail()
	mail.From = fmt.Sprintf("%s <%s>", e.config.FromName, e.config.FromEmail)
	mail.To = []string{to}
	mail.Subject = subject
	mail.HTML = []byte(htmlBody)
	mail.Text = []byte(textBody)

	// Send email using SMTP
	err := mail.Send(fmt.Sprintf("%s:%d", e.config.Host, e.config.Port),
		smtp.PlainAuth("", e.config.Username, e.config.Password, e.config.Host))

	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	return nil
}

// ValidateEmailFormat validates email format (basic validation)
func ValidateEmailFormat(email string) bool {
	// Basic email validation - in production, use a more robust validator
	if len(email) < 5 {
		return false
	}

	hasAt := false
	hasDot := false

	for i, char := range email {
		if char == '@' {
			if hasAt || i == 0 || i == len(email)-1 {
				return false
			}
			hasAt = true
		}
		if char == '.' && hasAt {
			hasDot = true
		}
	}

	return hasAt && hasDot
}

// SendPasswordChangedEmail sends notification when password is changed
func (e *EmailService) SendPasswordChangedEmail(to, displayName string) error {
	subject := "Password Changed - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
	<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
				<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
						<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
							<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
						<td style="padding: 50px 50px 40px;">
							<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Password Changed Successfully</h2>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Hello %s,</p>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Your password was successfully changed. If you made this change, no further action is required.</p>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #f7f9fc; border-left: 4px solid #1a1f3a; border-radius: 4px;">
								<p style="margin: 0; color: #1a1f3a; font-size: 14px; font-weight: 600;">Security Notice</p>
								<p style="margin: 10px 0 0; color: #4a5568; font-size: 14px; line-height: 1.6;">If you did not make this change, please secure your account immediately by resetting your password and contacting Team Histeeria.</p>
							</div>
							
							<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">Changed on: <strong style="color: #1a1f3a;">%s</strong></p>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
						<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
							<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated security notification. Please do not reply to this email.</p>
						</td>
					</tr>
				</table>
				<!-- Footer Text -->
				<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
					<tr>
						<td align="center">
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, displayName, time.Now().Format("January 2, 2006 at 3:04 PM MST"), time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendAccountDeletedEmail sends notification when account is deleted
func (e *EmailService) SendAccountDeletedEmail(to, displayName string) error {
	subject := "Account Deleted - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
	<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
				<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
						<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
							<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
						<td style="padding: 50px 50px 40px;">
							<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Account Deletion Confirmation</h2>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Hello %s,</p>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Your Histeeria account has been permanently deleted as requested. All your data has been removed from our systems.</p>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #fef5e7; border-left: 4px solid: #f39c12; border-radius: 4px;">
								<p style="margin: 0; color: #1a1f3a; font-size: 14px; font-weight: 600;">Important</p>
								<p style="margin: 10px 0 0; color: #4a5568; font-size: 14px; line-height: 1.6;">This action is permanent and cannot be undone. If you did not request this deletion, please contact Team Histeeria immediately.</p>
							</div>
							
							<p style="margin: 25px 0 0; color: #4a5568; font-size: 16px; line-height: 1.7;">We're sorry to see you go. If you'd like to return in the future, you're always welcome to create a new account.</p>
							<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">Deleted on: <strong style="color: #1a1f3a;">%s</strong></p>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
						<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
							<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated notification. Please do not reply to this email.</p>
						</td>
					</tr>
				</table>
				<!-- Footer Text -->
				<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
					<tr>
						<td align="center">
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, displayName, time.Now().Format("January 2, 2006 at 3:04 PM MST"), time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendEmailChangeVerificationEmail sends verification code for email change
func (e *EmailService) SendEmailChangeVerificationEmail(to, code string) error {
	subject := "Verify New Email Address - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
	<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
				<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
						<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
							<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
						<td style="padding: 50px 50px 40px;">
							<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Verify Your New Email Address</h2>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">You requested to change your email address. Please verify this new email address by entering the following code:</p>
							
							<!-- Verification Code Box -->
							<table width="100%%" cellpadding="0" cellspacing="0" style="margin: 35px 0;">
								<tr>
									<td align="center">
										<div style="display: inline-block; background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 20px 40px; border-radius: 8px;">
											<p style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700; letter-spacing: 8px; font-family: 'Courier New', monospace;">%s</p>
										</div>
									</td>
								</tr>
							</table>
							
							<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">This code will expire in <strong style="color: #1a1f3a;">1 hour</strong>.</p>
							
							<div style="margin-top: 40px; padding-top: 30px; border-top: 1px solid #e2e8f0;">
								<p style="margin: 0 0 15px; color: #718096; font-size: 13px; line-height: 1.6;">If you did not request this email change, please ignore this message and secure your account by changing your password.</p>
							</div>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
						<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
							<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
						</td>
					</tr>
				</table>
				<!-- Footer Text -->
				<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
					<tr>
						<td align="center">
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, code, time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendUsernameChangedEmail sends notification when username is changed
func (e *EmailService) SendUsernameChangedEmail(to, displayName, oldUsername, newUsername string) error {
	subject := "Username Changed - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
	<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
				<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
						<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
							<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
						<td style="padding: 50px 50px 40px;">
							<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Username Changed Successfully</h2>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Hello %s,</p>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Your username was successfully changed:</p>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #f7f9fc; border-left: 4px solid #1a1f3a; border-radius: 4px;">
								<p style="margin: 0 0 10px; color: #718096; font-size: 13px;">Previous Username:</p>
								<p style="margin: 0 0 15px; color: #1a1f3a; font-size: 16px; font-weight: 600;">%s</p>
								<p style="margin: 0 0 10px; color: #718096; font-size: 13px;">New Username:</p>
								<p style="margin: 0; color: #1a1f3a; font-size: 16px; font-weight: 600;">%s</p>
							</div>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #fef5e7; border-left: 4px solid #f39c12; border-radius: 4px;">
								<p style="margin: 0; color: #1a1f3a; font-size: 14px; font-weight: 600;">Security Notice</p>
								<p style="margin: 10px 0 0; color: #4a5568; font-size: 14px; line-height: 1.6;">If you did not make this change, please contact Team Histeeria immediately.</p>
							</div>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
						<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
							<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated security notification. Please do not reply to this email.</p>
						</td>
					</tr>
				</table>
				<!-- Footer Text -->
				<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
					<tr>
						<td align="center">
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, displayName, oldUsername, newUsername, time.Now().Year())

	return e.sendEmail(to, subject, body)
}

// SendEmailChangeNotificationToOldEmail notifies the old email address about email change request
func (e *EmailService) SendEmailChangeNotificationToOldEmail(oldEmail, displayName, newEmail string) error {
	subject := "Email Change Request - Histeeria"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa; line-height: 1.6;">
	<table width="100%%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
		<tr>
			<td align="center">
				<table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); max-width: 600px;">
					<!-- Header -->
					<tr>
						<td style="background: linear-gradient(135deg, #1a1f3a 0%%, #2d3561 100%%); padding: 40px 50px; border-radius: 8px 8px 0 0;">
							<h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">Histeeria</h1>
						</td>
					</tr>
					<!-- Content -->
					<tr>
						<td style="padding: 50px 50px 40px;">
							<h2 style="margin: 0 0 20px; color: #1a1f3a; font-size: 24px; font-weight: 600; letter-spacing: -0.3px;">Email Change Request</h2>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">Hello %s,</p>
							<p style="margin: 0 0 25px; color: #4a5568; font-size: 16px; line-height: 1.7;">A request was made to change the email address associated with your Histeeria account.</p>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #f7f9fc; border-left: 4px solid #1a1f3a; border-radius: 4px;">
								<p style="margin: 0 0 10px; color: #718096; font-size: 13px;">Current Email (this address):</p>
								<p style="margin: 0 0 15px; color: #1a1f3a; font-size: 16px; font-weight: 600;">%s</p>
								<p style="margin: 0 0 10px; color: #718096; font-size: 13px;">Requested New Email:</p>
								<p style="margin: 0; color: #1a1f3a; font-size: 16px; font-weight: 600;">%s</p>
							</div>
							
							<p style="margin: 25px 0 0; color: #4a5568; font-size: 16px; line-height: 1.7;">A verification code has been sent to the new email address. The change will only be completed after the new address is verified.</p>
							
							<div style="margin: 35px 0; padding: 20px; background-color: #fef5e7; border-left: 4px solid #f39c12; border-radius: 4px;">
								<p style="margin: 0; color: #1a1f3a; font-size: 14px; font-weight: 600;">Security Alert</p>
								<p style="margin: 10px 0 0; color: #4a5568; font-size: 14px; line-height: 1.6;">If you did not request this change, please secure your account immediately by changing your password and contacting Team Histeeria. Someone may have unauthorized access to your account.</p>
							</div>
							
							<p style="margin: 25px 0 0; color: #718096; font-size: 14px; line-height: 1.6;">Request time: <strong style="color: #1a1f3a;">%s</strong></p>
						</td>
					</tr>
					<!-- Footer -->
					<tr>
						<td style="background-color: #f7f9fc; padding: 30px 50px; border-radius: 0 0 8px 8px; border-top: 1px solid #e2e8f0;">
							<p style="margin: 0 0 10px; color: #718096; font-size: 13px; line-height: 1.6;">Histeeria</p>
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">This is an automated security notification. Please do not reply to this email.</p>
						</td>
					</tr>
				</table>
				<!-- Footer Text -->
				<table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; margin-top: 20px;">
					<tr>
						<td align="center">
							<p style="margin: 0; color: #a0aec0; font-size: 12px;">© %d Histeeria. All rights reserved.</p>
						</td>
					</tr>
				</table>
			</td>
		</tr>
	</table>
</body>
</html>
	`, displayName, oldEmail, newEmail, time.Now().Format("January 2, 2006 at 3:04 PM MST"), time.Now().Year())

	return e.sendEmail(oldEmail, subject, body)
}
