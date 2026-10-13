# frozen_string_literal: true

module ThematiqHelper
  # A small picture of a design system, built from its tokens. Decoration only: the name next to it carries the meaning.
  def thematiq_thumbnail(token_set)
    styles = OpenProject::Thematiq::Preview.new(token_set).thumbnail

    tag.div(class: "thematiq-thumb", style: styles[:frame], aria: { hidden: true }) do
      safe_join([
        tag.div(class: "thematiq-thumb__bar", style: styles[:top_bar]) do
          safe_join([tag.span(class: "thematiq-thumb__mark", style: styles[:top_bar_mark]),
                     tag.span(class: "thematiq-thumb__search", style: styles[:top_bar_search])])
        end,
        tag.div(class: "thematiq-thumb__body") do
          safe_join([
            tag.div(class: "thematiq-thumb__side", style: styles[:sidebar]) do
              safe_join([tag.span(class: "thematiq-thumb__button", style: styles[:button]),
                         tag.span(class: "thematiq-thumb__item", style: styles[:active_item]),
                         tag.span(class: "thematiq-thumb__item", style: styles[:item])])
            end,
            tag.div(class: "thematiq-thumb__main", style: styles[:content]) do
              safe_join([tag.span(class: "thematiq-thumb__title", style: styles[:title]),
                         tag.span(class: "thematiq-thumb__row", style: styles[:row]),
                         tag.span(class: "thematiq-thumb__row", style: styles[:row])])
            end
          ])
        end
      ])
    end
  end

  # A larger picture of the shared shell, built from a token set. Decoration with sample text, hidden from assistive technology.
  # Its colours are custom properties on the frame. The script of the editor writes the same properties while you type.
  def thematiq_shell_preview(token_set)
    sample = ->(key) { t("thematiq.editor.sample.#{key}") }
    part = ->(name, text = nil, &block) { tag.span(text, class: "thematiq-shell__#{name}", &block) }
    box = ->(name, &block) { tag.div(class: "thematiq-shell__#{name}", &block) }

    tag.div(class: "thematiq-shell", style: OpenProject::Thematiq::Preview.new(token_set).shell_variables, aria: { hidden: true },
            data: { test_selector: "thematiq-shell-preview", thematiq_preview: true }) do
      safe_join([
        box.call("bar") { safe_join([part.call("app", sample.call(:app)), part.call("search", sample.call(:search))]) },
        box.call("body") do
          safe_join([
            box.call("side") do
              safe_join([part.call("button thematiq-shell__button--action", sample.call(:create)),
                         part.call("nav", sample.call(:overview)),
                         part.call("nav thematiq-shell__nav--active", sample.call(:work_packages)),
                         part.call("nav", sample.call(:meetings))])
            end,
            box.call("main") do
              safe_join([
                box.call("head") do
                  safe_join([part.call("title", sample.call(:work_packages)),
                             part.call("button", sample.call(:export)),
                             part.call("button thematiq-shell__button--action", sample.call(:create))])
                end,
                part.call("input", sample.call(:filter)),
                box.call("table") do
                  safe_join([
                    box.call("row thematiq-shell__row--head") { safe_join([tag.span(sample.call(:id)), tag.span(sample.call(:subject))]) },
                    *%i[row_one row_two].each_with_index.map do |key, index|
                      box.call("row") { safe_join([part.call("link", "##{index + 1}"), tag.span(sample.call(key))]) }
                    end
                  ])
                end,
                box.call("notice") { safe_join([part.call("accent"), tag.span(sample.call(:notice))]) },
                part.call("note", sample.call(:footnote))
              ])
            end
          ])
        end
      ])
    end
  end

  # One contrast check next to a colour field: what is measured, the ratio and the verdict in words.
  # The script of the editor rewrites the ratio and the verdict while you type.
  def thematiq_contrast_line(check, token_set)
    ratio = OpenProject::Thematiq::Editor.ratio(check, token_set)
    verdict = OpenProject::Thematiq::Editor.verdict(ratio)

    tag.li(class: "thematiq-editor__check thematiq-editor__check--#{verdict}", data: { thematiq_check: check.id }) do
      safe_join([tag.span(t("thematiq.editor.contrast.of", pair: t("thematiq.contrast.pairs.#{check.id}"))), " ",
                 tag.span(thematiq_contrast_verdict(verdict, ratio), data: { thematiq_verdict: true })])
    end
  end

  def thematiq_contrast_verdict(verdict, ratio)
    t("thematiq.editor.contrast.#{verdict}", ratio: ratio ? format("%.2f", ratio) : "")
  end

  def thematiq_swatch(token_set, key)
    tag.span(class: "thematiq-editor__swatch", style: OpenProject::Thematiq::Preview.new(token_set).swatch(key), aria: { hidden: true })
  end
end
