<?php

declare(strict_types=1);

use Swoole\Coroutine;
use Swoole\Coroutine\Client;

const PORT = 2000;
const HOST = '127.0.0.1';
const NUM_CLIENTS = 4;

function runClient(int $id): void
{
    try {
        $client = new Client(SWOOLE_SOCK_TCP);

        if (!$client->connect(HOST, PORT, 30)) {
            echo "Client $id: Failed to connect: " . $client->errMsg . "\n";
            return;
        }

        echo "Client $id: Connected\n";

        // Read task from server
        $taskData = $client->recv();
        if ($taskData === false || $taskData === '') {
            echo "Client $id: No task received\n";
            $client->close();
            return;
        }

        $task = json_decode($taskData, true);
        if ($task) {
            echo "Client $id: Received task: " . json_encode($task) . "\n";

            // Simulate work
            $delay = rand(1, 10);
            echo "Client $id: Working for $delay seconds...\n";
            Coroutine::sleep($delay);

            // Process task
            $result = array_map(fn($n) => $n * 2, $task);

            // Send result
            $payload = json_encode($result);
            $client->send($payload);
            echo "Client $id: Sent result: $payload\n";
        }

        $client->close();

    } catch (\Throwable $e) {
        echo "Client $id Error: " . $e->getMessage() . "\n";
    }
}


Coroutine\run(function () {
    for ($i = 0; $i < NUM_CLIENTS; $i++) {
        go(function () use ($i) {
            runClient($i);
        });
    }
});

echo "All clients finished\n";
