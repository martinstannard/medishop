defmodule MedishopWeb.Helpers.ProductThumbnail do
  @moduledoc """
  Generates gradient-based SVG thumbnails for products.
  Creates beautiful, colorful placeholders with product initials or SKU.
  """

  @doc """
  Generates an inline SVG data URI for a product thumbnail.
  Uses product title to generate initials and a deterministic color gradient.

  ## Examples

      iex> generate_thumbnail("Aspirin 100mg", "ASP-100")
      "data:image/svg+xml,..."

  """
  def generate_thumbnail(title, sku) do
    initials = extract_initials(title)
    {color1, color2} = generate_gradient_colors(title)

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
      <defs>
        <linearGradient id="grad-#{hash_string(title)}" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#{color1};stop-opacity:1" />
          <stop offset="100%" style="stop-color:#{color2};stop-opacity:1" />
        </linearGradient>
      </defs>
      <rect width="200" height="200" fill="url(#grad-#{hash_string(title)})" />
      <text x="100" y="95" font-family="Arial, sans-serif" font-size="48" font-weight="bold" fill="white" text-anchor="middle" opacity="0.9">#{initials}</text>
      <text x="100" y="125" font-family="Arial, sans-serif" font-size="14" fill="white" text-anchor="middle" opacity="0.7">#{sku}</text>
    </svg>
    """

    # Encode as data URI
    encoded = URI.encode(String.trim(svg), &URI.char_unreserved?/1)
    "data:image/svg+xml,#{encoded}"
  end

  @doc """
  Extracts initials from a product title.
  Takes first letter of first two words, or first two letters if single word.

  ## Examples

      iex> extract_initials("Aspirin 100mg")
      "A1"

      iex> extract_initials("Ibuprofen")
      "IB"

  """
  def extract_initials(title) when is_binary(title) do
    title
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [single_word | _] when byte_size(single_word) >= 2 ->
        String.upcase(String.slice(single_word, 0..1))

      [first, second | _] ->
        String.upcase(String.at(first, 0) <> String.at(second, 0))

      _ ->
        "??"
    end
  end

  @doc """
  Generates a pair of gradient colors based on the product title.
  Uses a deterministic hash to ensure the same product always gets the same colors.
  """
  def generate_gradient_colors(title) do
    # Hash the title to get a deterministic number
    hash = hash_string(title)

    # Select color pair from predefined palette based on hash
    color_pairs = [
      {"#667eea", "#764ba2"},  # Purple
      {"#f093fb", "#f5576c"},  # Pink-Red
      {"#4facfe", "#00f2fe"},  # Blue-Cyan
      {"#43e97b", "#38f9d7"},  # Green-Cyan
      {"#fa709a", "#fee140"},  # Pink-Yellow
      {"#30cfd0", "#330867"},  # Cyan-Purple
      {"#a8edea", "#fed6e3"},  # Mint-Pink
      {"#ff9a56", "#ff6a88"},  # Orange-Pink
      {"#ffecd2", "#fcb69f"},  # Peach
      {"#ff6e7f", "#bfe9ff"},  # Red-Blue
      {"#e0c3fc", "#8ec5fc"},  # Lavender-Blue
      {"#fbc2eb", "#a6c1ee"},  # Pink-Blue
      {"#fdcbf1", "#e6dee9"},  # Rose
      {"#a1c4fd", "#c2e9fb"},  # Sky Blue
      {"#d299c2", "#fef9d7"},  # Purple-Cream
      {"#89f7fe", "#66a6ff"},  # Cyan-Blue
      {"#fa8bff", "#2bd2ff"},  # Magenta-Cyan
      {"#ffeaa7", "#fdcb6e"},  # Yellow-Orange
      {"#74b9ff", "#a29bfe"},  # Blue-Purple
      {"#fd79a8", "#fdcb6e"}   # Pink-Orange
    ]

    index = rem(hash, length(color_pairs))
    Enum.at(color_pairs, index)
  end

  # Private helper to hash a string into a deterministic integer
  defp hash_string(str) do
    :erlang.phash2(str, 1_000_000)
  end
end
