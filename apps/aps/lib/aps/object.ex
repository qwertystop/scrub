defprotocol APS.Object do
  @doc """
  Returns the color of this object.
  The default implementation of Zones produces their color
  by averaging the color of their contained objects.
  """
  def color(obj)

  @doc """
  The inverse of APS.Object.reconstruct/1.
  Deconstructing, message-passing, and reconstructing
  is the intended means of copying or moving objects between zones.
  
  The simplest implementation is to simply have
  both functions return their argument.
  However, some games may have object state which should
  not be maintained on copy for reasons of gameplay or message-bloating,
  such as age counters or cached calculations.
  """
  def deconstruct(obj)

  @doc """
  The inverse of APS.Object.deconstruct/1.
  Deconstructing, message-passing, and reconstructing
  is the intended means of copying or moving objects between zones.
  
  The simplest implementation is to simply have
  both functions return their argument.
  However, some games may have object state which should
  not be maintained on copy for reasons of gameplay or message-bloating,
  such as age counters or cached calculations.
  """
  def reconstruct(obj)

  @doc """
  Object recieves keypress code, returns its new state.
  """
  def handle_key(obj, key_code)
end

defimpl Object, for: Map do
  def color(map) do
    with {r, g, b} <- map.color,
    do: {{r, g, b}, map}
  end

  def deconstruct(map) do
    map
  end

  def reconstruct(map) do
    map
  end

  # maps do not respond to key input
  def handle_key(map, key_code) do
    map
  end
end
