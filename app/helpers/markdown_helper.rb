require "redcarpet"

module MarkdownHelper
  def markdown(text)
    return "" if text.blank?

    @markdown ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        hard_wrap: true,
        link_attributes: { target: "_blank", rel: "noopener noreferrer" }
      ),
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      space_after_headers: true,
      underline: true
    )

    @markdown.render(text).html_safe
  end
end
