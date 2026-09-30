# Access

Beacon has three roles. Every account holds exactly one of them.

## Roles

| Role | Read data | Edit dashboards | Edit rules and silences | Change settings |
| --- | --- | --- | --- | --- |
| Viewer | yes | no | no | no |
| Editor | yes | yes | yes | no |
| Operator | yes | yes | yes | yes |

Viewer is the default for a new account. A team lead can raise an account to Editor. Only the
observability team grants Operator.

## Service accounts

Automation uses service accounts, which authenticate with a token instead of a password. A service
account holds the Viewer role unless its owning team asks for Editor. Tokens expire after 90 days.

## Pages from Beacon

Operators are on the Beacon on-call rotation.

If the on-call engineer has not acknowledged a page within 15 minutes, the page moves to the
secondary on-call engineer. If neither has acknowledged it within 30 minutes, it goes to the
observability team lead, who decides whether to open an incident.

## Removing access

When someone leaves a team, their team lead lowers their account to Viewer the same day. The
observability team removes the account entirely when the person leaves the company.
