"""Private-stdin diagnostic. Normal users run tool/check-email.cmd."""
import json
import sys
from mail_delivery import check_smtp

def main():
    if sys.stdin.isatty():
        print('Run tool/check-email.cmd to check the shared Firebase email configuration.')
        return 1
    try:
        check_smtp(json.loads(sys.stdin.read(16000)))
        print('SMTP connection and sign-in passed. No email was sent.')
        return 0
    except Exception:
        print('Email sign-in could not be verified. Review the shared email settings and internet connection.')
        return 1

if __name__ == '__main__':
    sys.exit(main())
