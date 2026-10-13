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

A custom design system is a design system of the plugin plus the values you change. You can keep up to 50.

1. Select **Customise** next to a design system in the list. The editor opens a new custom design system with that one as the base. To change one you made earlier, select **Edit** next to it.
2. Give your design system a name.
3. Change values. They are in four groups, the same four as in thematiq's token editor: branding, content area, buttons and links, typography. An empty field keeps the value of the base, which the field shows in grey. A colour field has a swatch: select it to pick a colour.
4. Watch the picture beside the form. It follows what you type. Nothing is saved.
5. Read the contrast lines under a colour. Each one names a text and its background, the ratio, and whether it is enough. 4.5 to 1 is needed.
6. Select **Save and apply**. Your design system is saved and becomes the active one.

A value that differs from the base has the badge **Changed**. Each group counts its changed values, and the line above the groups counts them all. **Search values** finds a value by its name. **Show changed values only** hides the rest.

To go back to one value of the base, select **Reset** next to it. **Reset group** empties one group and **Reset all** every field. All three change the form only; select **Save and apply** to keep the result.

The live preview, the colour picker, the search and the filter need scripts in your browser. Without them the page still works: select **Preview** to draw the picture again.

A value the plugin cannot use is marked, with a line that says what is expected. Nothing is saved while a field is marked.

Your design systems stay at the top of the list, marked "Custom". You can pick another design system and come back to yours later. **Delete this custom design system** removes the one you have open, with its uploaded files. It asks first, on a page of its own: select **Delete for good** to go on, or **Cancel**.

### What the editor does not do

- It has no dark value per colour, no opacity control and no custom CSS. [design/style-editor.md](design/style-editor.md) compares it with thematiq's editor, part by part.
- A font you name is loaded when it is one of the 13 families in the plugin. Any other font must be on the reader's device. [logos-and-fonts.md](logos-and-fonts.md) lists the families.

## Upload a logo, icons and fonts

The editor of a saved custom design system has a section **Logo, icons and fonts**. A new design system gets it after the first **Save and apply**.

Each kind has its own small form: a file field, the limits, and the buttons **Upload** or **Replace**, and **Remove**.

1. Choose a file. The field states the file types, the largest size and the picture size.
2. Select **Upload**. The file is stored and in use at once. You do not need **Save and apply** for it.
3. Look at the preview next to the field. The logo for the coloured top bar is shown on your primary colour.

For a font, also type the family name and pick the weight and the style. Use the same family name in the value **Font**. A file with the same family, weight and style replaces the one that is there.

When the plugin refuses a file, a line at the top of the page says why and nothing changes. When it left parts out of an SVG file, it says so: check the preview.

Where each file shows:

| Kind | Where |
|---|---|
| Logo | The top bar, on every page the plugin reaches |
| Logo for the coloured top bar | The top bar, instead of the logo, when you uploaded both |
| Mobile logo | The top bar on screens narrower than 850 px. Without it, narrow screens keep OpenProject's own mark |
| Favicon | The browser tab |
| Touch icon | The home screen of a phone or tablet |
| Font | All text, when the value **Font** names its family |

An uploaded file wins over the file of the design system yours is based on. Deleting a custom design system deletes its files.

[uploads.md](uploads.md) lists the limits, the checks and where the files are kept.

## Export and import a design system

**Export** next to a design system saves it as a JSON file: its id, its name, its eighteen values and the name of its logo file. The file has the same shape as one entry of the plugin's catalogue.

**Import a design system**, at the bottom of the page, reads such a file.

1. Choose the file and select **Import**.
2. The file is added as a new custom design system. It never replaces one that is there.
3. Pick it in the list and select **Apply**.

The plugin treats the file as untrusted. It refuses a file over 64 KB, a file that is not JSON, a file with an entry it does not know and a file with one value that is not a colour, a length or a font stack. When it refuses a file, nothing changes.

A logo file does not travel with the file. The file holds the logo's name. When that names a logo that ships with the plugin, the imported design system shows it. Otherwise it uses OpenProject's own logo.

Uploaded files do not travel either. A font file is often not free to pass on, and the export would grow from a few KB to many MB. The export file lists the kinds of file it left behind, under `uploads`. The import reads that list and tells you which files to upload again. A version of the plugin from before uploads refuses a file with that entry: remove the entry by hand, or upgrade first.

## Check the page after a change to the code

The script `test/integration/admin_page_check.rb` signs in, opens the page and uses every action. Run it inside a development container, never against an instance people use:

```bash
docker exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject-thematiq \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```
