# Interprocess Communication Example

An example of **parallel data processing** with task distribution among several workers using Node.js/Elixir TCP sockets.

## Architecture

### Server (`server.js`)
- Listens on port 2000
- Splits an array of tasks into chunks of 4 elements
- Distributes chunks to connected clients
- Collects results from all clients
- Combines results in the correct order

### Client (`client.js`)
- Creates 4 concurrent connections to the server
- Receives a task (array of numbers)
- Processes the task: multiplies each number by 2 with a random delay (1-10 seconds)
- Sends the result back to the server

## Requirements

- Node.js (version 12 or higher)

## How to Run

1. Start the server:
```bash
node server.js
```

2. In a separate terminal, start the clients:
```bash
node client.js
```

## Example Output

The server will distribute the task array `[2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11]` among 4 clients and collect the processed results (each number multiplied by 2):

```
Final result: [4, 34, 6, 4, 10, 14, 30, 44, 2, 28, 30, 18, 0, 22]
```

## Use Case

This pattern is useful for:
- Distributing computational tasks across multiple workers
- Load balancing between multiple processors
- Parallel data processing with centralized result collection
