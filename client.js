'use strict';

const net = require('net');

const calc = (task) => {
    return new Promise((resolve) => {
        setTimeout(() => {
            resolve(task.map(item => item * 2));
        }, Math.floor((Math.random() * 10) + 1) * 1000);
    });
};

for (let i = 0; i < 4; i++) {
    const socket = new net.Socket();
    socket.connect({
        port: 2000,
        host: '127.0.0.1',
    }, () => {

        socket.on('data', async data => {
            const task = Array.from(data);

            console.log('Got a job:', socket.localPort);

            const result = await calc(task);

            socket.write(Buffer.from(result));
        });
    });

    socket.on('end', () => {
        console.log('Task done:', socket.localPort)
    });
}
