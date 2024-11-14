defmodule CollaborativeDoc do
  require Logger

  def demo do
    # Start undo manager with configuration
    {:ok, undo_pid} = UndoManager.start_link(%{
      tracked_origins: ["client1", "client2", "client3"],
      capture_timeout: 500
    })

    # Register three clients
    {:ok, _list1} = UndoManager.register_client(undo_pid, "client1")
    {:ok, _list2} = UndoManager.register_client(undo_pid, "client2")
    {:ok, _list3} = UndoManager.register_client(undo_pid, "client3")

    # Client 1 adds 1
    {:ok, array_contents} = UndoManager.push(undo_pid, "client1", 1)
    Logger.info("After client1 adds 1: #{inspect(array_contents)}")

    # Client 2 adds 20
    {:ok, array_contents} = UndoManager.push(undo_pid, "client2", 20)
    Logger.info("After client2 adds 20: #{inspect(array_contents)}")

    # Client 3 adds 30
    {:ok, array_contents} = UndoManager.push(undo_pid, "client3", 30)
    Logger.info("After client3 adds 30: #{inspect(array_contents)}")

    # Client 1 adds 2
    {:ok, array_contents} = UndoManager.push(undo_pid, "client1", 2)
    Logger.info("After client1 adds 2: #{inspect(array_contents)}")

    # Client 2 adds 21
    {:ok, array_contents} = UndoManager.push(undo_pid, "client2", 21)
    Logger.info("After client2 adds 21: #{inspect(array_contents)}")

    # Client 3 adds 31
    {:ok, array_contents} = UndoManager.push(undo_pid, "client3", 31)
    Logger.info("After client3 adds 31: #{inspect(array_contents)}")

    # Client 1 adds 3
    {:ok, array_contents} = UndoManager.push(undo_pid, "client1", 3)
    Logger.info("After client1 adds 3: #{inspect(array_contents)}")

    # Client 2 adds 22
    {:ok, array_contents} = UndoManager.push(undo_pid, "client2", 22)
    Logger.info("After client2 adds 22: #{inspect(array_contents)}")

    # Client 3 adds 32
    {:ok, array_contents} = UndoManager.push(undo_pid, "client3", 32)
    Logger.info("After client3 adds 32: #{inspect(array_contents)}")

    # Client 1 adds 4
    {:ok, array_contents} = UndoManager.push(undo_pid, "client1", 4)
    Logger.info("After client1 adds 4: #{inspect(array_contents)}")

    Logger.info("\n=== Starting Undo Operations for client1 ===\n")

    # Undo client1's operations one by one
    Enum.each(1..4, fn i ->
      case UndoManager.undo(undo_pid, "client1") do
        {:ok, array_contents} ->
          Logger.info("After undo #{i} (removing #{5-i}): #{inspect(array_contents)}")
        {:error, :no_operations} ->
          Logger.info("No operations to undo")
      end
    end)
  end
end
