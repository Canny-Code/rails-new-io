class Onboarding::Explanation::Component < Phlex::HTML
  include MarkdownHelper

  def initialize(content:, emoji: "👋")
    @content = content
    @emoji = emoji
  end

  def view_template
    div(class: "mt-4 bg-yellow-50 py-4 px-8 rounded-md flex gap-1") do
      div(class: "flex text-4xl items-center") { @emoji }
      div(class: "ml-6 flex flex-col gap-1 prose prose-sm max-w-none") do
        unsafe_raw markdown(@content)
      end
    end
  end
end
