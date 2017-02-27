defmodule APS do
  @moduledoc """
  APS: The Abstract Positioning System

  A module which uses APS is called a Zone.
  The contents of the world in-game are divided into several
  Zones. The APS manages the objects in each Zone,
  and any interactions between objects, cross-Zone or otherwise.

  Objects in a Zone are tagged with keyword lists,
  to check the tags the rules (see below).
  One required tag is :position, which the object itself should know
  and which may change as the game progresses. The associated value
  can be of any format but should be consistent within a specific
  Zone type. It might be actual coordinates, or it might be something
  more abstract such as an index (cards in a hand) or a keyword list
  (for in-game states associated with e.g. rotation or reflection)
  A Zone has a function to convert this internal representation
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
  TODO Documentation
  A Zone is set up by `use APS, opts`,
  where `opts` is the tuple used by default for initialization
  arguments, when calling Zone.start_link/0

  `opts` is as follows:
  {object_setup}

  object_setup is as follows:
  A list of parameters to use for initializing all Objects in the Zone,
    organized as for start_link with the addition
    of a keyword list [tag: value, tag2: value2]:
  [{tags, module, args, options}, {tags, module, args, options}, ...]

  (Zones can be started with arguments other than the default
  by instead starting them with with
  GenServer.start_link/2 or GenServer.start_link/3
  """
  defmacro __using__(opts) do
    quote do
      use GenServer
      # TODO define public API of a Zone here
      @doc """
      Starts up the Zone with default arguments
      """
      def start_link do
        GenServer.start_link(__MODULE__, unquote(opts))
      end

      # Define GenServer callbacks here
      def init({object_setup}) do
        tagmap = %{}
        objects = for block <- object_setup do
              [tags | params] = block

              case params do
                {module, args, opts} ->
                  {:ok, pid} = Agent.start_link(module, :init, args, opts)
                {module, args} ->
                  {:ok, pid} = Agent.start_link(module, :init, args)
              end
              # Add new tags, and register new object with them
              for tag <- tags do
                case tagmap do
                  # If tag is registered, add new object
                  %{^tag => vals} ->
                    tagmap = %{tagmap | tag => [pid | tagmap[tag]]}
                  # If tag is not registered, register it
                  _ -> tagmap = %{tagmap | tag => [pid]}
                end
              end
            end
        # Done. Take the opportunity to clean up the stack,
        # as it's unlikely anything else will call this immediately,
        # since the rest of the game still needs to initialize.
        # Also it's more acceptable to be a little slower at startup.
        {ok, %{objects: object_setup, tags: tagmap}, :hibernate}
      end

      @doc """
      Add an object to this.
      """
      # TODO add tags
      def handle_cast({:addobj, tags, module, args, opts}, state) do
        {:noreply, %{state |
            :objects => %{state.objects |
                Agent.start_link(module, :init, args, opts)}}}
      end

    end
  end
end
