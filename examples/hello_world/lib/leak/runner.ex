defmodule HelloWorld.LeakRunner do
  require Logger

  def repeat(times, _count, _sleep) when times <= 0 do
    :done
  end

  def repeat(times, count, sleep) do
    :ok = start_n(count)
    Process.sleep(sleep)
    print_memory_info()
    repeat(times - 1, count, sleep)
  end

  def init_dynamic_sup() do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: MyApp.DynamicSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def repeat_dynamic_sup(times, _count, _sleep) when times <= 0 do
    :done
  end

  def repeat_dynamic_sup(times, count, sleep) do
    Enum.each(1..count, fn i ->
      DynamicSupervisor.start_child(
        MyApp.DynamicSupervisor,
        {HelloWorld.Leak, %{:name => "foo#{to_string(i)}", :foo => "bar"}}
      )
    end)

    Process.sleep(sleep)
    Logger.info("MyApp.DynamicSupervisor #{get_heap_size_mb(MyApp.DynamicSupervisor)}MB")
    repeat_dynamic_sup(times - 1, count, sleep)
  end

  def start_n(number) do
    Enum.each(1..number, fn i ->
      HelloWorld.Leak.start(%{:name => "Leak#{to_string(i)}", :foo => "#{to_string(i)}"})
    end)
  end

  def print_memory_info() do
    Logger.info(
      "
    Elixir.HelloWorld.HelloSupervisor.Crdt                #{
        get_heap_size_mb(Elixir.HelloWorld.HelloSupervisor.Crdt)
      }MB
    Elixir.HelloWorld.HelloSupervisor.ProcessesSupervisor #{
        get_heap_size_mb(Elixir.HelloWorld.HelloSupervisor.ProcessesSupervisor)
      }MB
    Elixir.HelloWorld.HelloSupervisor                     #{
        get_heap_size_mb(Elixir.HelloWorld.HelloSupervisor)
      }MB
    "
    )
  end

  def crdt_size() do
    pid = Process.whereis(Elixir.HelloWorld.HelloSupervisor.Crdt)
    state = :sys.get_state(pid)
    map_size(Map.get(state, :merkle_map).map)
  end

  defp get_heap_size_mb(module) do
    {:total_heap_size, size} = Process.info(Process.whereis(module), :total_heap_size)
    size = size * :erlang.system_info(:wordsize) / 1_048_576
    :erlang.float_to_binary(size, decimals: 3)
  end
end
