# Rewards design reference

Source: the user's Downloads/FYP.fig from the FYP Figma design. Row 3:
Profile 63:1252, Voucher Page 82:37, Voucher Detail Page 82:38, Loyalty Point
Page 87:84. The voucher frames use different crops of the same original composite
image, rather than separate editable screen components.

82-37.png and 82-38.png retain that original composite. profile-reference.png,
vouchers-reference.png and voucher-details-reference.png isolate its screen regions
for comparison. 87-84.png is the original Points & History artwork. 63-1252.png is
only an individual icon from the native profile frame; use profile-reference.png
for the full profile visual reference. frames.json records the original nodes.

assets/images/rewards contains original dining, shopping, photo, earned and
redeemed graphics extracted from these images. Controls and text remain native
Flutter widgets. Layout retains the rose/off-white palette, membership hero,
monthly cards, activity filters, coupon edges/perforations, status chips, QR panel,
instructions, expandable terms and existing park navigation.

Displayed names, counts, points, codes and dates come from Firebase. Added catalogue,
review, confirmation and error states continue the same design; they do not merge
or remove the original designed screens.
