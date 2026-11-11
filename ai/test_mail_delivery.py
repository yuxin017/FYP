import base64
import ssl
from unittest import TestCase
from unittest.mock import patch
import worker
import mail_delivery


class MailChecks(TestCase):
    def test_reset_code_is_delivered_over_tls_and_never_returned(self):
        sent=[]
        class SMTP:
            def __init__(self,host,port,**options):
                self.asserted = options['context'].verify_mode == ssl.CERT_REQUIRED
            def __enter__(self):return self
            def __exit__(self,*args):return False
            def login(self,username,password):pass
            def send_message(self,message):sent.append(message)
        config={'smtp':{'enabled':True,'host':'smtp.fixture.invalid','port':465,'security':'ssl','username':'fixture','password':'fixture-secret','from':'park@example.test'}}
        data={'to':'visitor@example.test','otp':'012345','challengeId':'a'*48}
        data['_smtp']=config['smtp']
        with patch('pathlib.Path.read_text',side_effect=AssertionError('SMTP must not read local credential files')):
            result=mail_delivery.send_reset_email(data,SMTP)
        self.assertEqual(result,{'sent':True})
        self.assertIn('012345',sent[0].get_content())
        self.assertNotIn('fixture-secret',str(result)+str(sent[0]))
        self.assertEqual(len(list(sent[0].iter_attachments())),0)

    def test_tls_and_attachment_delivery_use_injected_settings_without_logging_credentials(self):
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
        data['_smtp']=config['smtp']
        with patch('pathlib.Path.read_text',side_effect=AssertionError('SMTP must not read local credential files')):
            result=mail_delivery.send_photo_email(data,SMTP)
        self.assertTrue(result['sent'])
        self.assertLess(events.index(('tls',ssl.CERT_REQUIRED)),events.index('login'))
        self.assertLess(events.index('login'),events.index(('send',1)))
        self.assertNotIn('fixture-secret',str(result)+str(events))

    def test_bad_destination_and_disabled_delivery_never_connect(self):
        def no_network(*args,**kwargs):raise AssertionError('No SMTP connection is allowed')
        with patch('pathlib.Path.read_text',side_effect=AssertionError('SMTP must not read local credential files')):
            with self.assertRaises(ValueError):mail_delivery.send_photo_email({'to':'bad\r\nheader','_smtp':{'enabled':False}},no_network)

    def test_connection_check_authenticates_without_sending_and_requires_injected_credentials(self):
        events=[]
        class SMTP:
            def __init__(self,*args,**kwargs):pass
            def __enter__(self):return self
            def __exit__(self,*args):return False
            def login(self,*args):events.append('authenticated')
            def send_message(self,*args):raise AssertionError('The check must not send email')
        config={'enabled':True,'host':'smtp.fixture.invalid','port':465,'security':'ssl','username':'fixture','password':'fixture-secret','from':'park@example.test'}
        with patch('pathlib.Path.read_text',side_effect=AssertionError('No local configuration may be read')):
            self.assertEqual(mail_delivery.check_smtp({'_smtp':config},SMTP),{'authenticated':True})
            with self.assertRaises(ValueError):mail_delivery.check_smtp({},SMTP)
        self.assertEqual(events,['authenticated'])
