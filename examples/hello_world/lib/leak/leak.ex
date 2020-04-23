defmodule HelloWorld.Leak do
  use GenServer
  require Logger

  def start(opts) do
    Horde.DynamicSupervisor.start_child(
      HelloWorld.HelloSupervisor,
      {__MODULE__, opts}
    )
  end

  def count() do
    Enum.filter(
      Horde.DynamicSupervisor.which_children(HelloWorld.HelloSupervisor),
      &match?({_, _, _, [__MODULE__]}, &1)
    )
    |> Enum.count()
  end

  def child_spec(opts = %{:name => name}) do
    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 10_000,
      restart: :transient
    }
  end

  def start_link(opts = %{:name => name}) do
    case GenServer.start_link(__MODULE__, opts, name: via_tuple(name)) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # this is the part that causes leak
        {:ok, pid}

        # :ignore
    end
  end

  def init(opts) do
    {:ok, opts}
  end

  def via_tuple(name), do: {:via, Horde.Registry, {HelloWorld.HelloRegistry, name}}
end
