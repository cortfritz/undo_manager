defmodule UndoManager do
  defmodule StackItem do
    defstruct before_state: nil,  # Binary state vector before change
              after_state: nil,   # Binary state vector after change
              update: nil,        # Update that created this state
              meta: %{}          # Additional metadata
  end

  use GenServer
  require Logger

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def register_client(pid, client_id) do
    GenServer.call(pid, {:register_client, client_id})
  end

  def push(pid, client_id, value) do
    GenServer.call(pid, {:push, client_id, value})
  end

  def undo(pid, client_id) do
    GenServer.call(pid, {:undo, client_id})
  end

  # Server Callbacks
  def init(opts) do
    %{
      tracked_origins: origins,
      capture_timeout: timeout
    } = opts

    main_doc = Yex.Doc.new()
    _array = Yex.Doc.get_array(main_doc, "array")

    {:ok, %{
      main_doc: main_doc,
      clients: %{},  # Will store client-specific docs
      undo_stack: [],
      redo_stack: [],
      undoing: false,
      redoing: false,
      tracked_origins: MapSet.new(origins ++ [__MODULE__]),
      capture_timeout: timeout,
      last_change: nil
    }}
  end

  def handle_call({:register_client, client_id}, _from, state) do
    # Create a new doc for this client's changes only
    client_doc = Yex.Doc.new()
    _array = Yex.Doc.get_array(client_doc, "array")

    new_state = put_in(state.clients[client_id], %{
      doc: client_doc,
      operations: []
    })

    {:reply, {:ok, []}, new_state}
  end

  def handle_call({:push, client_id, value}, _from, state) do
    # Get client's doc
    client_state = state.clients[client_id]
    client_doc = client_state.doc

    # Apply to client's doc and capture update
    {:ok, sv_before} = Yex.encode_state_vector(client_doc)
    client_array = Yex.Doc.get_array(client_doc, "array")
    :ok = Yex.Array.push(client_array, value)
    {:ok, client_update} = Yex.encode_state_as_update(client_doc, sv_before)

    # Apply to main doc
    main_array = Yex.Doc.get_array(state.main_doc, "array")
    :ok = Yex.Array.push(main_array, value)

    # Create stack item with client's update
    stack_item = %StackItem{
      before_state: sv_before,
      after_state: nil,  # Not needed since we store updates
      update: client_update,
      meta: %{client_id: client_id, value: value}
    }

    new_state = %{state |
      undo_stack: [stack_item | state.undo_stack]
    }

    array_contents = Yex.Array.to_list(main_array)
    {:reply, {:ok, array_contents}, new_state}
  end

  def handle_call({:undo, client_id}, _from, state) do
    Logger.info("Starting undo for client #{client_id}")

    case Enum.find(state.undo_stack, fn item ->
      Map.get(item.meta, :client_id) == client_id
    end) do
      nil ->
        {:reply, {:error, :no_operations}, state}

      item ->
        # Create new doc
        new_doc = Yex.Doc.new()
        _array = Yex.Doc.get_array(new_doc, "array")

        # First apply other clients' updates to main doc
        Enum.each(state.clients, fn {other_id, client_state} ->
          if other_id != client_id do
            Logger.debug("Applying #{other_id}'s full state")
            {:ok, other_update} = Yex.encode_state_as_update(client_state.doc)
            Yex.apply_update(new_doc, other_update)
            array = Yex.Doc.get_array(new_doc, "array")
            Logger.debug("Doc after #{other_id}'s changes: #{inspect(Yex.Array.to_list(array))}")
          end
        end)

        # Then apply only the remaining updates from the undoing client
        remaining_ops = state.undo_stack
          |> Enum.reverse()
          |> Enum.filter(fn op ->
            Map.get(op.meta, :client_id) == client_id && op != item
          end)

        Logger.debug("Applying remaining ops for #{client_id}: #{inspect(remaining_ops)}")

        Enum.each(remaining_ops, fn op ->
          Yex.apply_update(new_doc, op.update)
        end)

        # Update state
        new_state = %{state |
          main_doc: new_doc,
          undo_stack: List.delete(state.undo_stack, item),
          redo_stack: [item | state.redo_stack]
        }

        array = Yex.Doc.get_array(new_doc, "array")
        array_contents = Yex.Array.to_list(array)
        Logger.debug("Final doc state: #{inspect(array_contents)}")

        {:reply, {:ok, array_contents}, new_state}
    end
  end
end
