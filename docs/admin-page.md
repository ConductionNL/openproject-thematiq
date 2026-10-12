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

## Make a custom design system

OpenProject keeps one custom design system. It is a design system of the plugin plus the values you change.

1. Select **Customise** next to a design system in the list. The editor opens with that design system as the base.
2. Give your design system a name.
3. Change values. Each of the eighteen values has its own field. An empty field keeps the value of the base, which the field shows in grey.
4. Select **Preview**. The picture on the right is drawn again with your values. Nothing is saved.
5. Select **Save and apply**. Your design system is saved and becomes the active one.

To go back to one value of the base, select **Reset** next to it. **Reset all** empties every field. Both change the form only; select **Save and apply** to keep the result.

A value the plugin cannot use is marked, with a line that says what is expected. Nothing is saved while a field is marked.

Your design system stays in the list as "Custom". You can pick another design system and come back to yours later. **Delete the custom design system** removes it.

### What the editor does not do

- The preview does not follow your typing. It is drawn again when you select **Preview**.
- There is one custom design system, not several.
- A font you name is loaded when it is one of the 13 families in the plugin. Any other font must be on the reader's device. [logos-and-fonts.md](logos-and-fonts.md) lists the families.
- You cannot upload a logo.

## Export and import a design system

**Export** next to a design system saves it as a JSON file: its id, its name, its eighteen values and the name of its logo file. The file has the same shape as one entry of the plugin's catalogue.

**Import a design system**, at the bottom of the page, reads such a file.

1. Choose the file and select **Import**.
2. The file becomes the custom design system. It replaces the one that was there.
3. Pick it in the list and select **Apply**.

The plugin treats the file as untrusted. It refuses a file over 64 KB, a file that is not JSON, a file with an entry it does not know and a file with one value that is not a colour, a length or a font stack. When it refuses a file, nothing changes.

A logo does not travel with the file. The file holds a file name only, and an imported design system uses OpenProject's own logo.

## Check the page after a change to the code

The script `test/integration/admin_page_check.rb` signs in, opens the page and uses every action. Run it inside a development container, never against an instance people use:

```bash
docker exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject-thematiq \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```
