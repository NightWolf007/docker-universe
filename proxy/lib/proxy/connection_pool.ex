defmodule Proxy.ConnectionPool do
  @moduledoc """
  Supervisor that contains all composite connections.
  Don't restart child on their exit.
  Strategy: simple_one_for_one
  """

  use Supervisor

  @timeout 5_000

  @host "127.0.0.1"
  @port 6379

  alias Proxy.TCPSocket
  alias Proxy.CompositeConnection

  @doc """
  Starts connection pool
  """
  @spec start_link() :: {:ok | pid} | {:error, any}
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    child = Supervisor.child_spec(CompositeConnection,
      start: {CompositeConnection, :start_link, []},
      restart: :temporary
    )
    Supervisor.init([child], strategy: :simple_one_for_one)
  end

  @doc """
  Stops connection pool
  """
  @spec stop(Supervisor.supervisor) :: :ok
  def stop(sup) do
    sup
    |> Supervisor.which_children
    |> Enum.each(fn {_, pid, _, _} -> GenServer.stop(pid, :normal, @timeout) end)
    Supervisor.stop(sup)
  end

  @doc """
  Creates new connection and appends it to children
  """
  @spec create_connection(Supervisor.supervisor, :gen_tcp.socket) ::
        {:ok, pid} | {:error, any}
  def create_connection(sup, cli_socket) do
    case TCPSocket.connect(@host, @port) do
      {:ok, app_socket} ->
        args = [cli_socket, app_socket]
        case Supervisor.start_child(sup, args) do
          {:ok, pid} -> {:ok, pid}
          err ->
            TCPSocket.close(app_socket)
            err
        end
      err -> err
    end
  end
end
