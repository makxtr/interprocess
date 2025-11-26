<?php

declare(strict_types=1);

use Swoole\Server;

const STEP = 4;
const DATA = [2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11];

$tasks = array_chunk(DATA, STEP);
$taskIndex = 0;
$results = [];

$server = new Server("0.0.0.0", 2000);
$server->set([
    'worker_num' => 1,
]);

$server->on("Receive", function (Server $server, int $fd, int $reactorId, string $data) use (&$tasks, &$taskIndex, &$results) {
    echo "Client $fd sent: " . $data . "\n";
    $result = json_decode($data, true);
    if ($result) {
        $results[] = $result;
        echo "Received result from $fd\n";

        if (count($results) >= count($tasks)) {
            echo "All done!\n";
            $final = array_merge(...$results);
            echo "Final result: " . json_encode($final) . "\n";
            $server->shutdown();
        }
    }
});

$server->on("Connect", function (Server $server, int $fd) use (&$tasks, &$taskIndex) {
    echo "Client connected: $fd\n";
    if ($taskIndex < count($tasks)) {
        $task = $tasks[$taskIndex];
        $taskIndex++;
        $payload = json_encode($task);
        $server->send($fd, $payload);
        echo "Sent task to $fd: $payload\n";
    } else {
        echo "No more tasks for $fd\n";
        $server->close($fd);
    }
});

$server->on("Close", function (Server $server, int $fd) {
    echo "Client: Close $fd\n";
});

echo "Swoole TCP Server started at 127.0.0.1:2000\n";
$server->start();
