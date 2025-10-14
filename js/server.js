import net from "net";

const connections = [];

const step = 4;
const task = [2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11];
const results = [];

const gen = function* (array, step) {
  let nextIndex = 0;
  while (true) {
    if (nextIndex > array.length) return;
    yield array.slice(nextIndex, (nextIndex += step));
  }
};

const check = (client) => client.done === false;

const iterator = gen(task, step);
let get = 0;

const server = net.createServer((socket) => {
  console.dir({ Connected: socket.remotePort });
  const client = { socket, done: false, get: get++ };

  connections.push(client);
  const message = Buffer.from(iterator.next().value || []);

  socket.write(message);

  socket.on("data", (data) => {
    console.log(`From ${socket.remotePort}`, data);

    results.push({ get: client.get, data: Array.from(data) });

    client.done = true;
    console.log(client.get);

    socket.end();
  });

  socket.on("close", () => {
    const index = connections.findIndex((conn) => {
      return conn.socket.remotePort === socket.remotePort;
    });

    if (index !== -1) connections.splice(index, 1);

    console.log(`Closed ${socket.remotePort}`);

    if (!connections.some(check)) {
      console.log("all done!");
      console.dir(results, { depth: null });

      const finish = results
        .sort((a, b) => a.get - b.get)
        .reduce((acc, obj) => [...acc, ...obj.data], []);

      console.dir(finish, { depth: null });

      server.unref();

      console.dir({ connections });
    }
  });
});

server.listen(2000);
