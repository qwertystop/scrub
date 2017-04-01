defprotocol APS.Object do
  @doc """
  Returns the color of this object.
  The default implementation of Zones produces their color
  by averaging the color of their contained objects.
  """
  def color(obj)

  @doc """
  Returns a clone of the object. Not guaranteed to be identical to that object;
  if you want something identical use Agent.get/3 with the identity function.
  The intended means of moving objects between zones.
  
  The simplest implementation is to simply return the argument.
  However, some games may have object state which should
  not be maintained on clone for reasons of gameplay or message-bloating,
  such as age counters or caches.

  The options are for distinguishing between multiple such cases.
  """
  def clone(obj, opts \\ [])

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

  def clone(map, _opts \\ []) do
    map
  end

  # maps do not respond to key input
  def handle_key(map, key_code) do
    map
  end
end
