defmodule APSTest do
  use ExUnit.Case

  # dummy object for testing
  defmodule DummyObject do
    def init(state) do
      state
    end

    def params(state) do
      state
    end
  end

  # dummy module for testing
  defmodule DummyZone do
    use APS, {[]}
  end

  setup do
    {:ok, zone} = DummyZone.start_link
    {:ok, zone: zone}
  end

  test "adding and tag-finding", %{zone: zone} do
    assert APS.show_tags(zone) == []
    DummyZone.add_object(zone, [:foo, :bar], DummyObject, [{5, 3}])
    APS.add_object(zone, [:bar], DummyObject, [1])
    assert APS.show_tags(zone) == [:bar, :foo]
    # can't know what the pids are ahead of time,
    #  but there should be exactly one foo and two bars,
    #  and one of the bars is also the foo.
    #  and there are no other tags
    # Also: Using both the APS and aliased versions to confirm no difference.
    foos = APS.find_tagged(zone, :foo)
    bars = DummyZone.find_tagged(zone, :bar)
    assert APS.find_tagged(zone, :other) == []
    assert Enum.count(foos) == 1
    assert Enum.count(bars) == 2
    assert Enum.count(Enum.uniq(foos ++ bars)) == 2
    assert Agent.get(hd(foos), fn val -> val end) == {5, 3}
    assert Agent.get(hd(bars), fn val -> val end) == 1
    assert Agent.get(hd(tl bars), fn val -> val end) == {5, 3}
  end

  test "adding and removing", %{zone: zone} do
    # using the aliased version in here just to prove it works
    APS.add_object(zone, [:quux, :baz], DummyObject, ["alphabet"])
    APS.add_object(zone, [:baz, :leff], DummyObject, [134])
    assert APS.show_tags(zone) == [:baz, :leff, :quux]
    assert :baz |> APS.find_tagged(zone) |> Enum.count == 2
    [alp | []] = APS.find_tagged(:quux, zone)
    assert APS.pop_object(alp, zone, DummyObject) == "alphabet"
    assert :baz |> APS.find_tagged(zone) |> Enum.count == 1
    assert :quux |> APS.find_tagged(zone) |> Enum.count == 0
    num = :baz |> APS.find_tagged(zone) |> hd |> Agent.get(fn val -> val end)
    assert num == 134
  end
end
