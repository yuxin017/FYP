"""SMTP delivery uses local configuration; credentials never enter API responses."""
import base64
from email.message import EmailMessage
import json
from pathlib import Path
import re
import smtplib
import ssl

ROOT = Path(__file__).resolve().parent.parent


def send_photo_email(data, smtp_factory=None):
    try:
        config = json.loads((ROOT / '.local/services.json').read_text())['smtp']
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
