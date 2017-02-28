defmodule APS do
  @moduledoc """
  APS: The Abstract Positioning System

  A module which uses APS is called a Zone.
  The contents of the world in-game are divided into several
  Zones. The APS manages the objects in each Zone,
  and any interactions between objects, cross-Zone or otherwise.

  Objects in a Zone are tagged with keyword lists,
  to check the tags against the rules (see below).


  Objects will be able to return their position within a zone on request.
  The associated value can be of any format but should be consistent
  for all objects in a specific Zone type. It might be actual coordinates,
  or it might be something more abstract such as an index
  (cards in a hand) or a keyword list (for in-game states
  associated with e.g. rotation or reflection).
  A Zone must have a function to convert this internal representation
  into a transform (relative to that Zone's rectangle of screen)
  for rendering.

  A zone also has a set of rules, functions which are called automatically
  each frame if objects matching their conditions are present in the zone,
  or between the zone and a connected zone.

  USERCODE: Define modules for each type of zone, with associated rules
  and initial maps of (tagged) objects, and a position-to-transform
  function.
  """

# TODO: Done things are:
# Initialization of objects, adding more objects.

  @doc """
  A Zone is set up by `use APS, opts`,
  where `opts` is the tuple used by default for initialization
  arguments, when calling Zone.start_link/0

  See the init/1 function for details.

  (Zones can be started with arguments other than the default
  by instead starting them with with
  GenServer.start_link/2 or GenServer.start_link/3
  """
  defmacro __using__(opts) do
    quote do
      use GenServer
      require APS
      # Public API of Zones
      @doc """
      Starts up the Zone with default arguments
      """
      def start_link do
        GenServer.start_link(__MODULE__, unquote(opts))
      end

      # Delegates to APS for GenServer callbacks
      def init(arg) do
        APS.init(arg)
      end

      def handle_call(request, from, state) do
        APS.handle_call(request, from, state)
      end

      def handle_cast(request, state) do
        APS.handle_cast(request, state)
      end

      defoverridable [start_link: 0, handle_call: 3, handle_cast: 2]
    end
  end

  # Public API of Zones
  @doc """
  Add a new object to the specified Zone.
  (specify a Zone by pid or by name)
  """
  def add_object(zone, tags, module, args, options \\ []) do
    GenServer.cast(zone, {:addobj, {tags, module, args, options}})
  end

  @doc """
  Return the list of tags in the given zone
  """
  def show_tags(zone) do
    GenServer.call(zone, :showtags)
  end

  @doc """
  Returns the  list of objects with the given tag in the zone.
  Returns an empty list if there are no such objects.
  """
  def find_tagged(zone, tag) do
    GenServer.call(zone, {:findtagged, tag})
  end

  ## GenServer callbacks

  @doc """
  Initialize the Zone.
  Argument must be a tuple containing:
  - object_setup

  object_setup is a list of object parameter tuples.
  An object parameter tuple is {tag_list, module, args, opts}
  tag_list is a list of symbols used to tag the specific object.
  The others are the arguments to Agent.start_link/4 to create the object,
  where the function called is :init
  """
  def init({object_setup}) do
    {objects, tagmap} = start_objects(object_setup)
    {:ok, %{objects: objects, tags: tagmap}, :hibernate}
  end

  # Calls

  def handle_call(:showtags, _from, %{:tags => tags}=state) do
    {:reply, Map.keys(tags), state}
  end

  def handle_call({:findtagged, tag}, _from, %{:tags => tags}=state) do
    reply = case tags do
      %{^tag => val} -> val
      _ -> []
    end
    {:reply, reply, state}
  end

  # Casts

  @doc """
  Add an object to this.
  """
  def handle_cast({:addobj, {_tags, _module, _args, _opts}=params},
      %{:objects => objects, :tags => tags}=state) do
    {objlist, tagmap} = add_obj(objects, tags, params)
    {:noreply, %{state |
        :objects => objlist,
        :tags => tagmap}}
  end

  ## Private functions

  # Starts a new object,
  # returns updated taglist and objlist
  defp add_obj(objlist, tagmap, {tags, module, args, opts}) do
    {:ok, pid} = Agent.start_link(module, :init, args, opts)
    {[pid | objlist], update_tags(tagmap, tags, pid)}
  end

  # Start all the objects and collect their tags
  defp start_objects(obj_setup_list, pids \\ [], tagmap \\ %{})
  defp start_objects([params | rest], pids, tagmap) do
    {objlist, tagmap} = add_obj(pids, tagmap, params)
    start_objects(rest, objlist, tagmap)
  end

  # base case
  defp start_objects([], pids, tagmap) do
    {pids, tagmap}
  end

  # Add item to all new tags, add them to existing
  defp update_tags(existing, [tag | rest], item) do
    result = case existing do
      # If first is there, prepend new item
      %{^tag => vals} -> %{existing | tag => [item | vals]}
        # else make a new list
        _ -> Map.put(existing, tag, [item])
      end
      update_tags(result, rest, item)
    end

  # base case
  defp update_tags(existing, [], _item) do
    existing
  end
end
