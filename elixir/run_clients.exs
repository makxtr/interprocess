count =
  case System.argv() do
    [num] -> String.to_integer(num)
    _ -> 4
  end

IO.puts("Starting #{count} clients...")

tasks =
  for i <- 1..count do
    Task.async(fn ->
      IO.puts("Client #{i} starting...")
      Interprocess.Client.start()
      IO.puts("Client #{i} finished")
    end)
  end

try do
  Task.await_many(tasks, 20_000)
  IO.puts("\n✓ All #{count} clients finished successfully!")
rescue
  e ->
    IO.puts("\n✗ Error: #{inspect(e)}")
end
