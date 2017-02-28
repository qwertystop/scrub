defmodule APSTest do
  use ExUnit.Case

  # dummy object for testing
  defmodule DummyObject do
    def init(a \\ 0, b \\ 1, c \\ 2) do
      {a, b, c}
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

  test "tag-finding", %{zone: zone} do
    assert APS.show_tags(zone) == []
    APS.add_object(zone, [:foo, :bar], DummyObject, [5, 3])
    APS.add_object(zone, [:bar], DummyObject, [])
    assert APS.show_tags(zone) == [:bar, :foo]
    # can't know what the pids are ahead of time,
    #  but there should be exactly one foo and two bars,
    #  and one of the bars is also the foo.
    #  and there are no other tags
    foos = APS.find_tagged(zone, :foo)
    bars = APS.find_tagged(zone, :bar)
    assert APS.find_tagged(zone, :other) == []
    assert Enum.count(foos) == 1
    assert Enum.count(bars) == 2
    assert Enum.count(Enum.uniq(foos ++ bars)) == 2
    assert Agent.get(hd(foos), fn tup -> tup end) == {5, 3, 2}
    assert Agent.get(hd(bars), fn tup -> tup end) == {0, 1, 2}
    assert Agent.get(hd(tl bars), fn tup -> tup end) == {5, 3, 2}
  end
end
