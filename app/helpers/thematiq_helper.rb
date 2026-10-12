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
end
