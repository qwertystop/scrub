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
# Initialization of objects, adding objects, removing object, searching by keys.
# TODO things are:
# Having rules, checking rules, running rules, broadcasting casts to tags,
# collecting calls from tags, position conversion stub (overridable),
# having neighbors (labelled)

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
      ## Public API of Zones
      @doc """
      Starts up the Zone with default arguments
      """
      def start_link do
        GenServer.start_link(__MODULE__, unquote(opts))
      end

      # This part of the public API is the same regardless of configuration
      defdelegate add_object(zone, tags, module, args, options \\ []), to: APS
      defdelegate show_tags(zone), to: APS
      defdelegate find_tagged(tag, zone), to: APS
      defdelegate pop_object(pid, zone, module), to: APS

      ## GenServer callbacks
      defdelegate init(args), to: APS

      # Specific-pattern heads don't work with defdelegate
      def handle_call(:showtags, from, state),
        do: APS.handle_call(:showtags, from, state)
      def handle_call({:findtagged, tag}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_call({:popobj, module, pid}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_cast({:addobj, params}=req, state),
        do: APS.handle_cast(req, state)
    end
  end

  # Public API for basic manipulation common to all Zones

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
  def find_tagged(tag, zone) do
    GenServer.call(zone, {:findtagged, tag})
  end

  @doc """
  Returns the argument to pass to its module's init/1 to recreate the object.
  Then, removes the specified object from the zone,
  makes sure it's no longer listed for any tags,
  and stops it.
  """
  def pop_object(pid, zone, module) do
    GenServer.call(zone, {:popobj, module, pid})
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

  @doc """
  Return the list of tags in the given zone
  """
  def handle_call(:showtags, _from, %{:tags => tags}=state) do
    {:reply, Map.keys(tags), state}
  end

  @doc """
  Returns the  list of objects with the given tag in the zone.
  Returns an empty list if there are no such objects.
  """
  def handle_call({:findtagged, tag}, _from, %{:tags => tags}=state) do
    reply = case tags do
      %{^tag => val} -> val
      _ -> []
    end
    {:reply, reply, state}
  end

  @doc """
  Returns the argument to pass to its module's init/1 to recreate the object.
  Then, removes the specified object from the zone,
  makes sure it's no longer listed for any tags,
  and stops it.
  """
  def handle_call({:popobj, module, pid}, from,
      %{:objects => objects, :tags => tags}=state) do
    reply = Agent.get(pid, module, :params, [])
    GenServer.reply(from, reply)
    Agent.stop(pid)
    {:noreply, %{state |
        :objects => List.delete(objects, pid),
        :tags => excise(tags, pid, Map.keys(tags))}}
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

  ## Private
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

  # Remove item from all lists in keys of map that contain it
  defp excise(map, item, [key | rest]) do
    excise(%{map | key => List.delete(map[key], item)}, item, rest)
  end
  # base case
  defp excise(map, _item, []) do
    map
  end
end
