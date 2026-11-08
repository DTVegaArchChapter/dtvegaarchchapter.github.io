# frozen_string_literal: true

# Generates ASCII, hyphenated category segments for post URLs without
# changing the category values stored in each post's front matter.
module DTVega
  module AsciiSlug
    TRANSLITERATIONS = {
      "ı" => "i", "İ" => "i",
      "ş" => "s", "Ş" => "s",
      "ğ" => "g", "Ğ" => "g",
      "ü" => "u", "Ü" => "u",
      "ö" => "o", "Ö" => "o",
      "ç" => "c", "Ç" => "c"
    }.freeze

    module_function

    def call(value)
      value.to_s
        .gsub(Regexp.union(TRANSLITERATIONS.keys), TRANSLITERATIONS)
        .unicode_normalize(:nfkd)
        .encode("ASCII", :invalid => :replace, :undef => :replace, :replace => "")
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-+|-+\z/, "")
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.posts.docs.each do |post|
    next if post.data["permalink"]

    categories = Array(post.data["categories"])
      .map { |category| DTVega::AsciiSlug.call(category) }
      .reject(&:empty?)
      .uniq

    next if categories.empty?

    post.data["permalink"] =
      "/#{categories.join("/")}/:year/:month/:day/:title:output_ext"
  end
end
