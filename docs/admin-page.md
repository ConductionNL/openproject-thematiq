# The admin page

An OpenProject administrator picks the design system on one page.

## Open it

Open **Administration**, then **Thematiq design**. Only administrators see the menu item and only they can open the page.

OpenProject has its own menu item called "Design". That page belongs to OpenProject's Enterprise edition and is not part of this plugin.

## Pick a design system

The page lists every design system in the plugin. Each one has a small picture: a top bar, a button and a few rows, drawn from its own tokens.

1. Find the design system. Type part of its name in **Search design systems** and select **Search**. **Show all** brings the full list back.
2. Select it. The list is one group of radio buttons, so the arrow keys move through it.
3. Select **Apply**.

The line "Active now" names the design system in use. The list marks it "Active", and marks Cunningham "Default".

The search runs on the server. The page works without JavaScript.

## Check the page after a change to the code

The script `test/integration/admin_page_check.rb` signs in, opens the page and uses every action. Run it inside a development container, never against an instance people use:

```bash
docker exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject-thematiq \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```
