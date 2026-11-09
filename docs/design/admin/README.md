# Module 2 admin design references

Original artwork and reference images come from the user's downloaded FYP.fig.

- Admin sign-in: 128:529, MacBook Pro 14" - 10.
- Visitor Accounts: 135:551, MacBook Pro 14" - 12.
- Visitor Profile Details: 135:552, MacBook Pro 14" - 13.
- Activity Monitoring style: 135:553, MacBook Pro 14" - 14.

The original frames are flattened image designs. The login brand panel is extracted
into assets/images/admin/login-brand.png. All forms, tables, filters, actions and
navigation are Flutter controls. Package management, ticket records and gate
validation use the same sidebar, header, rose palette and card/table styling;
these supporting flows do not have complete standalone frames in the file.

Accounts, names, membership, balances, status and counts use Firebase data.
The implemented sidebar covers this module's working screens. Administrator-role
management, automated risk detection, complaint handling and report-generation
workflows are separate modules, and are not represented by nonworking navigation.

The desktop layout is checked at 1512 x 982, with a drawer and scrollable tables
on smaller windows. Widget-layout captures under .local/admin-qa use isolated test
fixtures; they are not a second running application or shared Firebase data.
