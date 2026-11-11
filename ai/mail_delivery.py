"""SMTP credentials arrive privately from the authenticated Node backend."""
import base64
from email.message import EmailMessage
import re
import smtplib
import ssl

def smtp_settings(data):
    config = data.get('_smtp')
    if not isinstance(config, dict) or not config.get('enabled'):
        raise ValueError('Email delivery settings need an administrator review.')
    if config.get('security') not in ['ssl', 'starttls'] or config.get('port') not in [465, 587, 2525]:
        raise ValueError('Email delivery settings need an administrator review.')
    if not all(isinstance(config.get(key), str) and config[key] for key in ['host', 'username', 'password', 'from']):
        raise ValueError('Email delivery settings need an administrator review.')
    if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', config['from']):
        raise ValueError('Email delivery settings need an administrator review.')
    return config


def check_smtp(data, smtp_factory=None):
    config = smtp_settings(data)
    context = ssl.create_default_context()
    mode = config['security']
    factory = smtp_factory or (smtplib.SMTP_SSL if mode == 'ssl' else smtplib.SMTP)
    options = {'timeout': 20}
    if mode == 'ssl':
        options['context'] = context
    try:
        with factory(config['host'], config['port'], **options) as smtp:
            if mode == 'starttls':
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
            smtp.login(config['username'], config['password'])
    except Exception:
        raise ValueError('Email sign-in could not be verified. Review the shared email settings and internet connection.') from None
    return {'authenticated': True}


def send_reset_email(data, smtp_factory=None):
    try:
        config = smtp_settings(data)
        if not config.get('enabled') or config['security'] not in ['ssl', 'starttls'] or config['port'] not in [465, 587, 2525]:
            raise ValueError()
        for address in [config['from'], data['to']]:
            if not isinstance(address, str) or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', address):
                raise ValueError()
        if not re.fullmatch(r'\d{6}', data['otp']) or not re.fullmatch(r'[a-f0-9]{48}', data['challengeId']):
            raise ValueError()
    except (KeyError, OSError, ValueError, TypeError):
        raise ValueError('Email delivery settings need an administrator review.') from None
    message = EmailMessage()
    message['From'], message['To'] = config['from'], data['to']
    message['Subject'] = 'Your Theme Park password reset code'
    message['Message-ID'] = f"<themepark-reset-{data['challengeId']}@{config['from'].split('@')[1]}>"
    message.set_content(f"Your password reset code is:\n\n{data['otp']}\n\nThis code expires in 5 minutes and can be used once. Enter it in the Theme Park application to choose a new password.\n\nIf you did not request this change, you can ignore this email. Your password has not changed.\n")
    context = ssl.create_default_context()
    mode = config['security']
    factory = smtp_factory or (smtplib.SMTP_SSL if mode == 'ssl' else smtplib.SMTP)
    options = {'timeout': 30}
    if mode == 'ssl':
        options['context'] = context
    try:
        with factory(config['host'], config['port'], **options) as smtp:
            if mode == 'starttls':
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
            smtp.login(config['username'], config['password'])
            smtp.send_message(message)
    except Exception:
        raise ValueError('Email delivery could not be confirmed.') from None
    return {'sent': True}


def send_photo_email(data, smtp_factory=None):
    try:
        config = smtp_settings(data)
        if not config.get('enabled'):
            raise ValueError()
        mode = config['security']
        if mode not in ['ssl', 'starttls'] or config['port'] not in [465, 587, 2525]:
            raise ValueError()
        for address in [config['from'], data['to']]:
            if not isinstance(address, str) or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', address):
                raise ValueError()
        if not re.fullmatch(r'[a-f0-9]{64}', data['orderId']):
            raise ValueError()
    except (KeyError, OSError, ValueError, TypeError):
        raise ValueError('Email delivery settings need an administrator review.') from None
    message = EmailMessage()
    message['From'] = config['from']
    message['To'] = data['to']
    message['Subject'] = 'Your Theme Park photo purchase'
    message['Message-ID'] = f"<themepark-photo-{data['orderId']}@{config['from'].split('@')[1]}>"
    message.set_content(f"Thank you for visiting Theme Park.\n\nPhoto order: PH-{data['orderId'][:12].upper()}\nConfirmed amount: RM {data['totalMinor']/100:.2f}\n\nYour purchased digital photos are attached. Printed copies can be collected using the photo collection pass in your account.\n\nYou can also download digital copies and your receipt from Photo Purchase History.\n")
    attachments = data.get('attachments', [])
    if len(attachments) > 10:
        raise ValueError('The photo email is too large.')
    total = 0
    for item in attachments:
        content = base64.b64decode(item['imageBase64'], validate=True)
        total += len(content)
        if total > 10_000_000 or not re.fullmatch(r'ThemePark-[a-f0-9]{12}\.jpg', item['name']):
            raise ValueError('The photo email is too large.')
        message.add_attachment(content, maintype='image', subtype='jpeg', filename=item['name'])
    context = ssl.create_default_context()
    factory = smtp_factory or (smtplib.SMTP_SSL if mode == 'ssl' else smtplib.SMTP)
    options = {'timeout': 30}
    if mode == 'ssl':
        options['context'] = context
    try:
        with factory(config['host'], config['port'], **options) as smtp:
            if mode == 'starttls':
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
            smtp.login(config['username'], config['password'])
            smtp.send_message(message)
    except Exception:
        raise ValueError('Email delivery could not be confirmed. Check your photo order before resending.') from None
    return {'sent': True, 'messageId': message['Message-ID']}
