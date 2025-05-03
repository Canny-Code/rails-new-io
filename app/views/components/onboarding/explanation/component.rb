class Onboarding::Explanation::Component < Phlex::HTML
  include MarkdownHelper

  def initialize(content:, emoji: "👋", subtitle: nil)
    @content = content
    @emoji = emoji
    @subtitle = subtitle
  end

  def view_template
    div(class: "mt-4 bg-yellow-50 py-4 px-8 rounded-md flex gap-1") do
      div(class: "flex text-4xl items-center") { @emoji }
      div(class: "ml-6 flex flex-col gap-1 prose prose-sm max-w-none") do
        if @subtitle
          h1(class: "mb-0") { unsafe_raw markdown(@content.lines.first) }
          p(class: "mt-[-1.5rem] text-gray-600 italic") { @subtitle }
          unsafe_raw markdown(@content.lines[1..].join)
        else
          unsafe_raw markdown(@content)
        end
      end
    end
  end
end
