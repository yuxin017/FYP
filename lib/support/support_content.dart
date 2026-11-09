class SupportGuide {
  final String id, category, title, subtitle, icon;
  final List<String> steps;
  const SupportGuide(
    this.id,
    this.category,
    this.title,
    this.subtitle,
    this.icon,
    this.steps,
  );
}

const supportGuides = [
  SupportGuide(
    'login',
    'Getting Started',
    'How to Log In',
    'Sign in with your registered email',
    'login',
    [
      'Open the app and select Email Address on the login screen.',
      'Enter the email address used when you created your account.',
      'Enter your password. Use the eye icon if you need to check it.',
      'Tap Log In. Complete email verification if prompted, then continue to the park app.',
    ],
  ),
  SupportGuide(
    'register',
    'Getting Started',
    'Create an Account',
    'Register and set up your profile',
    'person',
    [
      'Tap Sign Up on the login screen.',
      'Enter your name, email address and phone number, then choose and confirm a password.',
      'Create the account and open the verification email in your inbox.',
      'Return to the app, confirm your email is verified and complete your profile.',
    ],
  ),
  SupportGuide(
    'reset',
    'Getting Started',
    'Reset a Forgotten Password',
    'Recover access securely',
    'password',
    [
      'Tap Forgot Password on the login screen.',
      'Enter the registered email address and request a reset link.',
      'Check your inbox and spam folder, then open the Firebase password reset link.',
      'Choose a new password on the secure reset page, then return to Log In.',
    ],
  ),
  SupportGuide(
    'buy',
    'Tickets',
    'Purchase Park Tickets',
    'Choose a pass and plan your visit',
    'ticket',
    [
      'Open Tickets and choose a day pass or annual pass.',
      'Select your visit date and adult/child quantities, then add the pass to your cart.',
      'Complete each guest’s name and email. Assign to Me fills your own details.',
      'Review the total, select a payment method and confirm. Your order and QR tickets are saved in My Tickets.',
    ],
  ),
  SupportGuide(
    'scan',
    'Tickets',
    'Scan & Add Tickets',
    'Find tickets linked to your account',
    'scan',
    [
      'Open Profile and tap Scan & Add Ticket.',
      'Allow camera access when you want to scan a ticket QR.',
      'Scan the QR code or enter the full ticket ID or readable reference.',
      'Open the ticket details. The ticket must belong to your account or use your registered guest email.',
    ],
  ),
  SupportGuide(
    'entry',
    'At the Park',
    'Enter the Park',
    'Present your digital admission ticket',
    'ticket',
    [
      'Open Tickets, then My Tickets.',
      'Choose your pass and open its digital QR ticket.',
      'Present each guest’s own QR to staff at the park entrance.',
      'Staff validate admission for the selected visit day. Multi-day passes retain their remaining valid dates.',
    ],
  ),
  SupportGuide(
    'rewards',
    'At the Park',
    'Use Points & Vouchers',
    'Make the most of your park rewards',
    'reward',
    [
      'Open Profile, then Points to check your balance and activity.',
      'Collect any available points from completed purchases. New ticket purchases collect automatically.',
      'Open the Redemption Catalogue and exchange enough points for a reward.',
      'Find it in My Vouchers. Show staff the QR and confirm Use Voucher when they accept it.',
    ],
  ),
  SupportGuide(
    'profile',
    'Getting Started',
    'Personalise Your Profile',
    'Keep your details and interests up to date',
    'person',
    [
      'Open Profile and choose Edit Profile or Profile Settings.',
      'Update your name, contact number and optional profile photo in Personal Information.',
      'Save your height, food preferences and park interests in Preferences & Interests.',
      'Reopen your profile to check the saved information.',
    ],
  ),
];

class SupportFaq {
  final String question, answer, category;
  final String? guideId;
  const SupportFaq(this.question, this.answer, this.category, [this.guideId]);
}

const supportFaqs = [
  SupportFaq(
    'How do I add a purchased ticket?',
    'Open Profile, tap Scan & Add Ticket, then scan its QR code or enter the ticket reference. Access is limited to your own tickets and tickets assigned to your registered guest email.',
    'Tickets',
    'scan',
  ),
  SupportFaq(
    'Which details should I use to log in?',
    'Use the email address registered to your account and its password. Check for spelling mistakes and complete email verification if prompted.',
    'Account',
    'login',
  ),
  SupportFaq(
    'What should I do if I forgot my password?',
    'Select Forgot Password and request a reset link for your registered email. Check your inbox and spam folder, then follow the secure reset page.',
    'Account',
    'reset',
  ),
  SupportFaq(
    'Where can I find my loyalty points?',
    'Open Profile and tap Points. You can see your balance, earned/redeemed activity and any purchase points ready to collect.',
    'Account',
    'rewards',
  ),
  SupportFaq(
    'Where are my confirmed tickets?',
    'Open Tickets, then My Tickets. Upcoming, Used and Expired filters organise your passes by their current admission status and dates.',
    'Tickets',
    'entry',
  ),
  SupportFaq(
    'Can I buy tickets for more than one guest?',
    'Yes. Add the adult and child quantities to your cart and complete a name and email for every guest. A checkout supports up to ten guests across five pass selections.',
    'Tickets',
    'buy',
  ),
  SupportFaq(
    'How do I use points when buying tickets?',
    'At Review Order, choose the points discount. Each 100 points reduces the total by RM1. The discount cannot exceed your saved balance or the ticket subtotal.',
    'Payments',
    'buy',
  ),
  SupportFaq(
    'Where can I download a receipt?',
    'Open Profile → Purchase History, choose the confirmed order and download its PDF receipt. The saved payment method and booking total are shown with the order.',
    'Payments',
  ),
  SupportFaq(
    'When should I press Use Voucher?',
    'Show the voucher to staff first. Press Use Voucher and confirm only when staff are ready to accept it. A used or expired voucher cannot be used again.',
    'Park Visit',
    'rewards',
  ),
  SupportFaq(
    'Can a multi-day pass be used again tomorrow?',
    'A valid multi-day or annual pass allows admission once per valid day. Its remaining dates stay available after today’s admission. Check the expiry shown on the pass.',
    'Park Visit',
    'entry',
  ),
  SupportFaq(
    'How do I report a problem or make a complaint?',
    'Open Help & Support, choose Report a Problem or Submit a Complaint, and describe what happened. My Requests keeps the status, support replies and your follow-up messages together.',
    'Park Visit',
  ),
  SupportFaq(
    'Can I reply after a case has been resolved?',
    'Yes. Open My Requests, select the resolved case and choose Reopen Request. You can then send a follow-up message in the same conversation.',
    'Account',
  ),
];
