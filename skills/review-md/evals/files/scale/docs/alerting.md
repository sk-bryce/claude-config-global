# Alerting

Beacon ships a standard set of alerts about its own health. Service teams add their own alerting
rules on top; this page covers only the standard set and how alerts are routed.

## Standard alerts

Each component has two standard alerts:

- `Beacon<Component>ErrorsHigh` fires when more than 5 percent of the component's operations end in
  an error for 10 minutes.
- `Beacon<Component>Stale` fires when the component's last successful operation is more than 15
  minutes old.

For example, the scraper's alerts are `BeaconScraperErrorsHigh` and `BeaconScraperStale`. Each
metric's reference page names the alert that uses it.

## Routing

The notifier sends every standard alert to the observability team's channel. An alert that stays
firing for 30 minutes also pages the on-call engineer.

## Escalation

If the on-call engineer has not acknowledged a page within 15 minutes, the page moves to the
secondary on-call engineer. If neither has acknowledged it within 30 minutes, it goes to the
observability team lead, who decides whether to open an incident.

## Silencing an alert

Silence an alert only while you are working on its cause. Every silence needs a reason and an end
time no more than 24 hours away. The notifier drops a silence when its end time passes, so a
problem that outlasts its silence pages again.
