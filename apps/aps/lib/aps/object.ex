defprotocol Object do
  def color(obj)
end

defimpl Object, for: Map do
  def color(map) do
    with {r, g, b} <- map.color,
    do: {{r, g, b}, map}
  end
end
