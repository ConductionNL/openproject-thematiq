# The admin page

An OpenProject administrator connects OpenProject to thematiq on one page.

## Open it

Open **Administration**, then **Thematiq design**. Only administrators see the menu item and only they can open the page.

OpenProject has its own menu item called "Design". That page belongs to OpenProject's Enterprise edition and is not part of this plugin.

## Connect to thematiq

1. Enter the address of the Nextcloud that runs thematiq in **Nextcloud address**, for example `https://cloud.example.org`. If your Nextcloud needs `index.php` in its addresses, add it: `https://cloud.example.org/index.php`.
2. Select **Check connection**. The page tells you which design system thematiq offers. Nothing is saved yet.
3. Select **Save**. OpenProject fetches the design system and uses it at once.

## Read the status

| Field | What it tells you |
|---|---|
| Name | The design system that styles OpenProject now |
| Revision | The version of that design system, as thematiq names it |
| Source | "Thematiq", or "Bundled default" when OpenProject uses its built in set |
| Last fetched | When OpenProject last received a design system |
| Last checked | When OpenProject last asked thematiq, with or without a change |

A yellow banner says when the bundled default is in use, and why. A red banner says when the last fetch failed. After a failed fetch the last design system stays in use.

## Refresh

OpenProject asks thematiq every five minutes. Select **Refresh now** to fetch at once.

## Choose another design system

You choose the design system in thematiq, in Nextcloud. OpenProject follows within five minutes.

## Stop using thematiq

Clear **Nextcloud address** and select **Save**. OpenProject goes back to the bundled default.

## Check the page after a change to the code

The script `test/integration/admin_page_check.rb` signs in, opens the page and uses every action. Run it inside a development container, never against an instance people use:

```bash
docker exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject-thematiq \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```
