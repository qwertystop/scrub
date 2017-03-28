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
      defdelegate add_object(zone, tags, args, options \\ []), to: APS
      defdelegate show_tags(zone), to: APS
      defdelegate find_tagged(zone, tag), to: APS
      defdelegate cast_tagged(zone, tag, fun), to: APS
      defdelegate cast_tagged(zone, tag, mod, fun, args \\ []), to: APS
      defdelegate call_tagged(zone, tag, fun), to: APS
      defdelegate call_tagged(zone, tag, mod, fun, args \\ []), to: APS
      defdelegate pop_object(pid, zone), to: APS
      defdelegate add_neighbor(other, name, one), to: APS
      defdelegate get_neighbor(zone, name), to: APS
      defdelegate check_rules(zone), to: APS
      defdelegate get_graphic(zone), to: APS

      ## GenServer callbacks
      defdelegate init(args), to: APS

      # Specific-pattern heads don't work with defdelegate
      def handle_call(:showtags, from, state),
        do: APS.handle_call(:showtags, from, state)
      def handle_call({:findtagged, tag}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_call(:allobj, from, state),
        do: APS.handle_call(:allobj, from, state)
      def handle_call({:popobj, pid}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_call({:addneighbor, other, name}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_call({:getneighbor, name}=req, from, state),
        do: APS.handle_call(req, from, state)
      def handle_cast({:addobj, params}=req, state),
        do: APS.handle_cast(req, state)
      def handle_cast(:checkrules, state),
        do: APS.handle_cast(req, state)
    end
  end

  # Public API for basic manipulation common to all Zones

  @doc """
  Add a new object to the specified Zone.
  (specify a Zone by pid or by name)
  """
  def add_object(zone, tags, args, options \\ []) do
    GenServer.cast(zone, {:addobj, {tags, args, options}})
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
 
  def all_objects(zone) do
    GenServer.call(zone, :allobj)
  end

  @doc """
  Casts the given (state -> new_state) to all objects with specified tag.
  """
  def cast_tagged(zone, tag, fun) do
    find_tagged(zone, tag)
    |> cast_list fun
    :ok
  end

  @doc """
  Casts Module.function to all objects with specified tag,
  prepending an object's state to args.
  """
  def cast_tagged(zone, tag, mod, fun, args \\ []) do
    find_tagged(zone, tag)
    |> cast_list(mod, fun, args)
    :ok
  end

  @doc """
  Casts the given (state -> new_state) to all objects in the list.
  """
  def cast_list(list, fun) do
    Enum.map(list, &(Agent.cast(&1, fun)))
    :ok
  end

  @doc """
  Casts Module.function to all objects in the list,
  prepending an object's state to args.
  """
  def cast_list(list, mod, fun, args \\ []) do
    Enum.map(list, &(Agent.cast(&1, mod, fun, args)))
    :ok
  end

  @doc """
  Calls the given (state -> {result, new_state}) on all object with specified tag;
  returns list of {pid, result}.
  """
  def call_tagged(zone, tag, fun) do
    find_tagged(zone, tag)
    |> call_list(fun)
  end

  @doc """
  Calls the given (state -> {result, new_state}) on all object with specified tag;
  returns list of {pid, result}.
  """
  def call_tagged(zone, tag, mod, fun, args \\ []) do
    find_tagged(zone, tag)
    |> call_list(mod, fun, args)
  end

  @doc """
  Calls the given (state -> {result, new_state}) on all objects in the list,
  returns list of {pid, result}.
  """
  def call_list(list, fun) do
    list
    |> Task.async_stream &({&1, Agent.get_and_update(&1, fun)})
    |> Enum.to_list
  end

  @doc """
  Calls the given (state -> {result, new_state}) on all objects in the list,
  returns list of {pid, result}.
  """
  def call_list(list, mod, fun, args \\ []) do
    list
    |> Task.async_stream &({&1, Agent.get_and_update(&1, mod, fun, args)})
    |> Enum.to_list
  end

  @doc """
  Returns the argument to pass to its module's init/1 to recreate the object.
  Then, removes the specified object from the zone,
  makes sure it's no longer listed for any tags,
  and stops it.
  """
  def pop_object(pid, zone) do
    GenServer.call(zone, {:popobj, pid})
  end

  @doc """
  Register `other` as a neighbor of `one` under a given name.
  Names should be symbols that indicate the relationship
  between the zones from the perspective of `one`, e.g. `:above`
  meaning that `other` is above `one`.

  Any given zone can only have one
  neighbor under a given name,
  but multiple zones may have neighbors
  under the same name.
  e.g. only one zone can be directly :above zone A,
  but zone B can also have something :above it.

  Returns :ok or {:error, :already_registered}
  """
  def add_neighbor(other, name, one) do
    GenServer.call(one, {:addneighbor, other, name})
  end

  @doc """
  Returns the pid of the indicated neighbor of this process.
  Returns {:error, :none} if there is no such neighbor.
  """
  def get_neighbor(zone, name) do
    case GenServer.call(zone, {:getneighbor, name}) do
      pid when is_pid(pid) -> pid
      [] -> {:error, :none}
      # below should never come up
      other -> {:error, {:unexpected, other}}
    end
  end

  @doc """
  Checks for applicable rules in a zone, runs them.
  """
  def check_rules(zone) do
    GenServer.cast(zone, :checkrules)
  end

  @doc """
  Returns the graphic to draw for this zone.
  In default implementation, assumes
  each object returns {int, int, int},
  interprets that as an RGB color,
  averages the colors, and returns the result.
  Is overridable. I know it's simplistic,
  but I'm pressed for time and this will do as proof-of-concept.
  """
  def get_graphic(zone) do
    with objs <- all_objects(zone),
      colors <- call_list(zone, APS.Object, :color) |> Enum.map(fn {pid, val} -> val end),
        num <- List.length(colors),
        {rt, gt, bt} <- Enum.map_reduce(colors, {0, 0, 0},
                                        fn {r, g, b}, {rt, gt, bt} ->
                                          {r+rt, g+gt, b+bt} end),
        do: {rt / num, gt / num, bt / num}
  end

  ## GenServer callbacks

  @doc """
  Initialize the Zone.
  Argument must be a tuple containing:
  - object_setup
  - rule_setup

  object_setup is a list of object parameter tuples.
  An object parameter tuple is {tag_list, module, args, opts}
  tag_list is a list of symbols used to tag the specific object.
  The others are the arguments to Agent.start_link/4 to create the object,
  where the function called is :init

  rule_list is a list of Rules.
  A Rule is a tuple {atom, (zone, object -> :ok)}
  The atom is a tag to find objects on in a zone, each frame.
  The function is then called, with the zone and each found object in turn.
  Typically it will use the zone's public API to modify the zone and/or
  run Agent functions on the object.
  """
  def init({object_setup, rule_list}) do
    {objects, tagmap} = start_objects(object_setup)
    {:ok, %{objects: objects, tags: tagmap, rules: rule_list}, :hibernate}
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
  Get all the objects in the zone.
  """
  def handle_call(:allobj, _from, %{:objects => objects}) do
    objects
  end

  @doc """
  Returns the argument to pass to its module's init/1 to recreate the object.
  Then, removes the specified object from the zone,
  makes sure it's no longer listed for any tags,
  and stops it.
  """
  def handle_call({:popobj, pid}, from,
      %{:objects => objects, :tags => tags}=state) do
    reply = Agent.get(pid, &(&1), []) |> APS.Object.deconstruct
    GenServer.reply(from, reply)
    Agent.stop(pid)
    {:noreply, %{state |
        :objects => List.delete(objects, pid),
        :tags => excise(tags, pid, Map.keys(tags))}}
  end

  @doc """
  Registers a neighbor for this.
  """
  def handle_call({:addneighbor, other, name}, _from, _state) do
    unless Registry.keys(:neighbor_registry, self())
           |> Enum.member?(name) do
      # Name not registered for this process
      Registry.register(:neighbor_registry, name, other)
      {:reply, :ok, _state}
    else
      {:reply, {:error, :already_registered}, _state}
    end
  end

  @doc """
  Finds indicated neighbor of this.
  """
  def handle_call({:getneighbor, name}, _from, _state) do
    result = with zones = Registry.lookup(:neighbor_registry, name),
      [head|tail] = zones,
      [ngbr|[]] = Enum.filter_map(zones,
                            fn {s, _} -> s === self() end,
                            fn {_, p} -> p end),
      do: ngbr
      {:reply, result, _state}
  end
  # Casts
  @doc """
  Add an object to this.
  """
  def handle_cast({:addobj, {_tags, _args, _opts}=params},
      %{:objects => objects, :tags => tags}=state) do
    {objlist, tagmap} = add_obj(objects, tags, params)
    {:noreply, %{state |
        :objects => objlist,
        :tags => tagmap}}
  end

  @doc """
  Runs all rules.
  """
  def handle_cast(:checkrules, %{:rules => rules}=state) do
    zone = self()
    # For each rule
    Task.async_stream(rules, fn {tag, cbak} ->
      # Find all the objects with the appropriate tag
      GenServer.call(zone, {:findtagged, tag})
      # Call the rule's callback function on each one
      |> Task.async_stream &cbak.(zone, &1)
      # Push it all through the pipe
      |> Enum.to_list
    end)
    {:noreply, state}
  end

  ## Private
  # Starts a new object,
  # returns updated taglist and objlist
  defp add_obj(objlist, tagmap, {tags, args, opts}) do
    {:ok, pid} = Agent.start_link(APS.Object, :reconstruct, args, opts)
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
