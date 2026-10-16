# Request to OpenProject: an extension point for PDF export styling

**Status: not sent, and superseded.** The product owner chose to patch the four exporter files instead; [enterprise-parity.md](../enterprise-parity.md#pdf-export-styling) describes the patch. No issue was opened anywhere. The text is kept for the day an extension point is worth asking for again.

This is the text we would put to the OpenProject team. It describes one small change in OpenProject's core that lets a plugin supply the styling of PDF exports.

## The request

Title: Let a plugin supply the logo, cover, footer and fonts of PDF exports

### What we would like

One place in core where the PDF exporters ask for their styling, in place of reading the `CustomStyle` record directly. A plugin can then answer that question from its own storage.

### Why

We maintain [openproject-thematiq](https://github.com/ConductionNL/openproject-thematiq), an open source plugin that gives OpenProject the design system of an organisation: colours, corners, font and logo. Dutch municipalities use the same design system in Nextcloud and want their OpenProject and the documents it produces to carry it too.

For the web interface the plugin needs nothing from core beyond the two head hooks that exist. For PDF exports there is no such place. The exporters read their styling straight from `CustomStyle.current`:

| File | What it reads |
|---|---|
| `app/models/exports/pdf/common/logo.rb` | `export_logo` |
| `app/models/exports/pdf/components/cover.rb` | `export_cover` and `export_cover_text_color` |
| `app/models/exports/pdf/components/page.rb` | `export_footer` |
| `app/models/exports/pdf/common/view.rb` | `export_font_regular`, `export_font_bold`, `export_font_italic` and `export_font_bold_italic` |

Read in OpenProject 17.9.1.

So a plugin has two ways to style an export today, and we want neither:

- Write its files into the `CustomStyle` record. That record belongs to the Design page of the Enterprise edition. A plugin should not fill it behind that page's back.
- Prepend its own readers to those four modules. That works until one of them changes, and it has to be checked again on every release.

### What it could look like

A small object that the four files ask, with `CustomStyle` as its default answer. For example:

```ruby
module Exports::PDF::Styling
  # Returns an object that answers logo_path, cover_path, cover_text_color, footer_path and font_files.
  def self.current
    providers.lazy.filter_map(&:call).first || Exports::PDF::Styling::FromCustomStyle.new
  end

  def self.register(&provider)
    providers << provider
  end
end
```

The four files would call `Exports::PDF::Styling.current` where they call `CustomStyle.current` now. Nothing changes for an installation without a plugin, and nothing changes for the Enterprise Design page: it stays the default provider and keeps its licence check where it is today.

We do not need this exact shape. Any single place where the exporters ask for their styling would do, such as a view hook, a setting that names a provider class or a method on a configuration object.

### What we are not asking for

- We are not asking for the Enterprise Design page, or any part of it, to become available without a token.
- We are not asking to read or write `CustomStyle`.
- We are not asking for a change to how exports look by default.

### What we offer

We can write the pull request, with specs, if the team tells us which shape it prefers. We would keep it to the four files above and one new file.

## Notes for us, not part of the request

- The exporters themselves carry no licence check. The check sits on the page that fills the record (`guard_enterprise_feature(:define_custom_style, ...)` in `custom_styles_controller.rb`). The request leaves that as it is.
- The plugin now takes the prepend route, guarded by checksums of the four files. Were core to add such a place, the patch could go.
