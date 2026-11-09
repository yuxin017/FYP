import base64
import json
import ssl
from unittest import TestCase
from unittest.mock import patch
import worker
import mail_delivery


class MailChecks(TestCase):
    def test_tls_and_attachment_delivery_use_local_settings_without_logging_credentials(self):
        events=[]
        class SMTP:
            def __init__(self,host,port,**options):events.append(('connect',host,port))
            def __enter__(self):return self
            def __exit__(self,*args):return False
            def ehlo(self):events.append('ehlo')
            def starttls(self,**options):events.append(('tls',options['context'].verify_mode))
            def login(self,username,password):events.append('login')
            def send_message(self,message):events.append(('send',len(list(message.iter_attachments()))))
        config={'smtp':{'enabled':True,'host':'smtp.fixture.invalid','port':587,'security':'starttls','username':'fixture','password':'fixture-secret','from':'photos@example.test'}}
        data={'to':'visitor@example.test','orderId':'a'*64,'totalMinor':2500,'attachments':[{'name':'ThemePark-aaaaaaaaaaaa.jpg','imageBase64':base64.b64encode(b'isolated-image-bytes').decode()}]}
        with patch('pathlib.Path.read_text',return_value=json.dumps(config)):
            result=mail_delivery.send_photo_email(data,SMTP)
        self.assertTrue(result['sent'])
        self.assertLess(events.index(('tls',ssl.CERT_REQUIRED)),events.index('login'))
        self.assertLess(events.index('login'),events.index(('send',1)))
        self.assertNotIn('fixture-secret',str(result)+str(events))

    def test_bad_destination_and_disabled_delivery_never_connect(self):
        def no_network(*args,**kwargs):raise AssertionError('No SMTP connection is allowed')
        with patch('pathlib.Path.read_text',return_value='{"smtp":{"enabled":false}}'):
            with self.assertRaises(ValueError):mail_delivery.send_photo_email({'to':'bad\r\nheader'},no_network)
