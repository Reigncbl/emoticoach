import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from typing import Optional


class EmailService:
    """
    Anonymous email service for Help Center requests.
    Sends emails from a system account without logging user info or IP addresses.
    """
    
    def __init__(self):
        # Load SMTP configuration from environment variables
        self.smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER")  # e.g., noreply@emoticoach.com
        self.smtp_password = os.getenv("SMTP_PASSWORD")
        self.recipient_email = os.getenv("HELP_CENTER_EMAIL", "emoticoach@gmail.com")
        
    def send_help_request(self, message: str, subject: Optional[str] = None, user_email: Optional[str] = None) -> bool:
        """
        Send anonymous help request email.
        
        Args:
            message: The help request message
            subject: Optional custom subject line
            user_email: Optional user email for response
            
        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            # Validate SMTP credentials
            if not self.smtp_user or not self.smtp_password:
                print("ERROR: SMTP credentials not configured")
                return False
            
            # Create message
            msg = MIMEMultipart('alternative')
            msg['From'] = f"EmotiCoach Help Center <{self.smtp_user}>"
            msg['To'] = self.recipient_email
            msg['Subject'] = subject or "New Help Center Request"
            
            # Create HTML and plain text versions
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
            
            # Plain text version
            text_body = f"""
New Help Center Request

Submitted: {timestamp}
{f'User Email: {user_email}' if user_email else 'Anonymous (no email provided)'}

Message:
{message}

---
This is a help request from EmotiCoach app.
{f'Reply to: {user_email}' if user_email else 'No user email provided - unable to respond directly.'}
"""
            
            # HTML version
            html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }}
        .container {{
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }}
        .header {{
            background-color: #FF5722;
            color: white;
            padding: 20px;
            border-radius: 8px 8px 0 0;
        }}
        .content {{
            background-color: #f9f9f9;
            padding: 20px;
            border: 1px solid #ddd;
            border-top: none;
        }}
        .message-box {{
            background-color: white;
            padding: 15px;
            border-left: 4px solid #FF5722;
            margin: 15px 0;
            white-space: pre-wrap;
        }}
        .footer {{
            background-color: #f1f1f1;
            padding: 15px;
            border-radius: 0 0 8px 8px;
            font-size: 12px;
            color: #666;
        }}
        .timestamp {{
            color: #666;
            font-size: 14px;
        }}
        .email-info {{
            background-color: #E3F2FD;
            padding: 10px 15px;
            border-radius: 4px;
            margin: 15px 0;
            border-left: 4px solid #2196F3;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2 style="margin: 0;">New Help Center Request</h2>
        </div>
        <div class="content">
            <p class="timestamp"><strong>Submitted:</strong> {timestamp}</p>
            
            {f'''<div class="email-info">
                <strong>User Email:</strong> <a href="mailto:{user_email}">{user_email}</a>
            </div>''' if user_email else '<p style="color: #999; font-style: italic;">Anonymous (no email provided)</p>'}
            
            <div class="message-box">
                <strong>Message:</strong><br><br>
                {message}
            </div>
        </div>
        <div class="footer">
            <p style="margin: 0;">This is a help request from EmotiCoach app.</p>
            <p style="margin: 5px 0 0 0;">{f'Reply to: {user_email}' if user_email else 'No user email provided - unable to respond directly.'}</p>
        </div>
    </div>
</body>
</html>
"""
            
            # Attach both versions
            part1 = MIMEText(text_body, 'plain')
            part2 = MIMEText(html_body, 'html')
            msg.attach(part1)
            msg.attach(part2)
            
            # Send email
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)
            
            print(f"Help request email sent successfully to {self.recipient_email}")
            return True
            
        except smtplib.SMTPAuthenticationError as e:
            print(f"SMTP Authentication failed: {e}")
            return False
        except smtplib.SMTPException as e:
            print(f"SMTP error occurred: {e}")
            return False
        except Exception as e:
            print(f"Error sending help request email: {e}")
            return False
    
    def send_feedback(self, message: str, rating: Optional[int] = None) -> bool:
        """
        Send anonymous feedback email.
        
        Args:
            message: The feedback message
            rating: Optional rating (1-5)
            
        Returns:
            bool: True if email sent successfully, False otherwise
        """
        try:
            # Validate SMTP credentials
            if not self.smtp_user or not self.smtp_password:
                print("ERROR: SMTP credentials not configured")
                return False
            
            # Create message
            msg = MIMEMultipart('alternative')
            msg['From'] = f"EmotiCoach Feedback <{self.smtp_user}>"
            msg['To'] = self.recipient_email
            msg['Subject'] = "New App Feedback"
            
            # Create HTML and plain text versions
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
            rating_text = f" ({rating}/5 stars)" if rating else ""
            
            # Plain text version
            text_body = f"""
New App Feedback{rating_text}

Submitted: {timestamp}

Message:
{message}

---
This is anonymous feedback from EmotiCoach app.
No user information or IP addresses are logged for privacy.
"""
            
            # HTML version
            rating_stars = "⭐" * rating if rating else ""
            html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }}
        .container {{
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }}
        .header {{
            background-color: #2196F3;
            color: white;
            padding: 20px;
            border-radius: 8px 8px 0 0;
        }}
        .content {{
            background-color: #f9f9f9;
            padding: 20px;
            border: 1px solid #ddd;
            border-top: none;
        }}
        .message-box {{
            background-color: white;
            padding: 15px;
            border-left: 4px solid #2196F3;
            margin: 15px 0;
            white-space: pre-wrap;
        }}
        .footer {{
            background-color: #f1f1f1;
            padding: 15px;
            border-radius: 0 0 8px 8px;
            font-size: 12px;
            color: #666;
        }}
        .timestamp {{
            color: #666;
            font-size: 14px;
        }}
        .rating {{
            font-size: 24px;
            margin: 10px 0;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2 style="margin: 0;">New App Feedback</h2>
        </div>
        <div class="content">
            <p class="timestamp"><strong>Submitted:</strong> {timestamp}</p>
            {f'<div class="rating">{rating_stars} {rating}/5</div>' if rating else ''}
            
            <div class="message-box">
                <strong>Feedback:</strong><br><br>
                {message}
            </div>
        </div>
        <div class="footer">
            <p style="margin: 0;">This is anonymous feedback from EmotiCoach app.</p>
            <p style="margin: 5px 0 0 0;">No user information or IP addresses are logged for privacy.</p>
        </div>
    </div>
</body>
</html>
"""
            
            # Attach both versions
            part1 = MIMEText(text_body, 'plain')
            part2 = MIMEText(html_body, 'html')
            msg.attach(part1)
            msg.attach(part2)
            
            # Send email
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)
            
            print(f"Feedback email sent successfully to {self.recipient_email}")
            return True
            
        except Exception as e:
            print(f"Error sending feedback email: {e}")
            return False


# Create singleton instance
email_service = EmailService()
