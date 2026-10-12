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
  def thematiq_shell_preview(token_set)
    styles = OpenProject::Thematiq::Preview.new(token_set).shell
    sample = ->(key) { t("thematiq.editor.sample.#{key}") }

    tag.div(class: "thematiq-shell", style: styles[:frame], aria: { hidden: true }, data: { test_selector: "thematiq-shell-preview" }) do
      safe_join([
        tag.div(class: "thematiq-shell__bar", style: styles[:top_bar]) do
          safe_join([tag.span(sample.call(:app), class: "thematiq-shell__app"),
                     tag.span(sample.call(:search), class: "thematiq-shell__search", style: styles[:search])])
        end,
        tag.div(class: "thematiq-shell__body") do
          safe_join([
            tag.div(class: "thematiq-shell__side", style: styles[:sidebar]) do
              safe_join([tag.span(sample.call(:create), class: "thematiq-shell__button", style: styles[:action_button]),
                         tag.span(sample.call(:overview), class: "thematiq-shell__nav", style: styles[:nav_item]),
                         tag.span(sample.call(:work_packages), class: "thematiq-shell__nav", style: styles[:nav_item_active]),
                         tag.span(sample.call(:meetings), class: "thematiq-shell__nav", style: styles[:nav_item])])
            end,
            tag.div(class: "thematiq-shell__main") do
              safe_join([
                tag.div(class: "thematiq-shell__head") do
                  safe_join([tag.span(sample.call(:work_packages), class: "thematiq-shell__title"),
                             tag.span(sample.call(:export), class: "thematiq-shell__button", style: styles[:secondary_button]),
                             tag.span(sample.call(:create), class: "thematiq-shell__button", style: styles[:action_button])])
                end,
                tag.span(sample.call(:filter), class: "thematiq-shell__input", style: styles[:input]),
                tag.div(class: "thematiq-shell__table", style: styles[:table]) do
                  safe_join([
                    tag.div(class: "thematiq-shell__row", style: styles[:table_head]) do
                      safe_join([tag.span(sample.call(:id)), tag.span(sample.call(:subject))])
                    end,
                    *%i[row_one row_two].each_with_index.map do |key, index|
                      tag.div(class: "thematiq-shell__row", style: styles[:table_row]) do
                        safe_join([tag.span("##{index + 1}", style: styles[:link]), tag.span(sample.call(key))])
                      end
                    end
                  ])
                end,
                tag.span(sample.call(:footnote), class: "thematiq-shell__note", style: styles[:muted])
              ])
            end
          ])
        end
      ])
    end
  end

  def thematiq_swatch(token_set, key)
    tag.span(class: "thematiq-editor__swatch", style: OpenProject::Thematiq::Preview.new(token_set).swatch(key), aria: { hidden: true })
  end
end
