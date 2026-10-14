# The admin page

An OpenProject administrator picks the design system on one page.

## Open it

Open **Administration**, then **Thematiq design**. Only administrators see the menu item and only they can open the page.

OpenProject has its own menu item called "Design". That page belongs to OpenProject's Enterprise edition and is not part of this plugin.

## Pick a design system

The page lists every design system in the plugin. Each one has a small picture: a top bar, a button and a few rows, drawn from its own tokens.

1. Find the design system. Type part of its name in **Search design systems** and select **Search**. **Show all** brings the full list back.
2. Select it. The list is one group of radio buttons, so the arrow keys move through it.
3. Select **Apply**. The apply dialog opens: the shell now and after, and a table of every value that differs, light and dark, with its value now and after. Nothing is applied yet.
4. Untick a value to keep its value of now. The picture of after follows the boxes. A value that is OpenProject's own now cannot be kept, and says so.
5. Select **Apply**. The page puts the new style sheets in its own style tags and repaints without a reload; without JavaScript the form posts and the page loads again. When values were kept, the result is a new custom design system named "<name>, with values kept".

Or select **Try it yourself first**. The design system is then yours alone, on every page, in this session: a banner at the foot of each page names it and offers **Publish to everyone** and **Discard**. Nobody else sees it. A trial ends after a day, and only counts while you are an administrator.

The line "Active now" names the design system in use. The list marks it "Active", and marks Cunningham "Default".

The search runs on the server and looks at the name and id of every design system, your custom ones included. The count under the field counts them too. The page works without JavaScript.

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

## Tiles in the top bar

**Tiles in the top bar**, at the bottom of the page, picks which apps and modules show as tiles after the logo, and in which order.

1. Choose **The bar of the design, without tiles**, **My own row** or **No tiles**. The design is Nextcloud's dossiq bar, which has no tiles: the app switcher holds every app and module. The places start with the row of the earlier OpenProject design, for an own row.
2. For your own row, pick a tile for each place, from left to right. Empty places are skipped. At most twelve.
3. Select **Save tiles**. Everyone sees the new row on their next page.

A tile a user cannot open is left out, and the row is filled up from OpenProject's own order. Nextcloud tiles need the Nextcloud address. The page a user is on always gets a tile. [shell-structure.md](shell-structure.md#the-row-of-apps) has the rules.

## Projects and modules

**Projects and modules**, at the bottom of the page, lets parts of OpenProject have their own design system.

- **A project.** Open the project, **Project settings**, **Design**, and pick one. Every page of the project follows it, the top bar and the logo included. Its subprojects inherit it. The page says where the current design system comes from.
- **A module.** Pick one per module here. The content of that module's pages follows it, in every project that has not chosen otherwise. The top bar and the menu stay the page's.
- **Let projects choose.** Off by default. On, members with the permission **Choose design system** may pick for their project, from the design systems you tick. Give the permission to a role under **Administration**, **Users and permissions**, **Roles and permissions**. No role has it until you do.

The most specific choice wins: a module in a project, the project, the module, a parent project, then the design system picked at the top of this page. [design/scopes.md](design/scopes.md) has the rules.

## Export and import a design system

**Export** next to a design system saves it as a JSON file: its id, its name, its eighteen values and the name of its logo file. The file has the same shape as one entry of the plugin's catalogue. A design system with values from thematiq's full vocabulary has them in a `vocabulary` entry beside the eighteen; [the full vocabulary](design/full-vocabulary.md) lists the names. A file exported before the vocabulary existed imports as it always did.

**Import a design system**, at the bottom of the page, reads such a file.

1. Choose the file and select **Import**.
2. The file is added as a new custom design system. It never replaces one that is there.
3. Pick it in the list and select **Apply**.

The plugin treats the file as untrusted. It refuses a file over 64 KB, a file that is not JSON, a file with an entry it does not know and a file with one value that does not pass the check of its kind: a colour, a length, a font stack, or one of the kinds of the vocabulary. When it refuses a file, nothing changes.

A logo file does not travel with the file. The file holds the logo's name. When that names a logo that ships with the plugin, the imported design system shows it. Otherwise it uses OpenProject's own logo.

Uploaded files do not travel either. A font file is often not free to pass on, and the export would grow from a few KB to many MB. The export file lists the kinds of file it left behind, under `uploads`. The import reads that list and tells you which files to upload again. A version of the plugin from before uploads refuses a file with that entry: remove the entry by hand, or upgrade first. The same goes for `vocabulary` on a version from before the vocabulary.

## Check the page after a change to the code

The script `test/integration/admin_page_check.rb` signs in, opens the page and uses every action. Run it inside a development container, never against an instance people use:

On the instance from [Try it locally with Docker](../README.md#try-it-locally-with-docker), from the repository root. Give the port you opened OpenProject on:

```bash
docker compose -f docker/compose.yml exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```

On a container started as in [development.md](development.md), which gets `SECRET_KEY_BASE` from `docker run`:

```bash
docker exec -e THEMATIQ_CHECK_PASSWORD='<admin password>' -e THEMATIQ_CHECK_HOST=localhost:8080 openproject-thematiq \
  bash -lc 'cd /app && bin/rails runner /app/custom-plugins/openproject-thematiq/test/integration/admin_page_check.rb'
```

`bash -lc` matters on the compose instance: the login shell reads the secret from its volume. Without it `rails runner` stops with "INSECURE SECRET_KEY_BASE DETECTED".

## History

**History**, linked under "Active now", lists every change to the design: when, who, what. Each row is kept in the plugin's table `thematiq_changes` together with the whole setup after the change: the design system in use, the custom design systems, the rules for projects, the Nextcloud address, the tiles of the top bar and every choice per project and module.

1. Select **Restore** next to a change.
2. The page lists what restoring it changes, in words. Nothing is written yet. A version that no longer reads, for example because it names a project that was deleted, is refused whole and says why.
3. Select **Restore this version**.

The restore is a row of its own, so the setup from before it can be restored too. The rows cannot be changed or deleted from OpenProject. The setup is kept for the newest 50 changes; older rows keep who, what and when. Uploaded logos, icons and fonts are not part of a version and stay as they are.

## A brand manager who is not an administrator

Give someone the global permission **Manage the design**: under **Administration**, **Users and permissions**, **Roles and permissions**, make or edit a global role with it, then give that role to the person under their **Global roles**. They then see **Thematiq design** in the administration and can do everything on it: pick, edit, upload, import, restore. They see nothing else of the administration. Their changes carry their name in the history.
