package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"math/rand/v2"
	"net"
	"sync"
	"time"
)

const (
	serverPort = 2000
	serverHost = "127.0.0.1"
	numClients = 4
)

func calc(task []byte) []byte {
	delay := time.Duration(rand.IntN(10)+1) * time.Second
	time.Sleep(delay)

	result := make([]byte, len(task))
	for i, val := range task {
		result[i] = val * 2
	}
	return result
}

func runClient(id int, wg *sync.WaitGroup) {
	defer wg.Done()

	conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", serverHost, serverPort))
	if err != nil {
		log.Printf("Client %d: Failed to connect: %v", id, err)
		return
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().String()
	log.Printf("Client %d connected from %s", id, localAddr)

	var taskLen uint32
	if err := binary.Read(conn, binary.BigEndian, &taskLen); err != nil {
		if err == io.EOF {
			log.Printf("Client %d: Server closed connection (no tasks)", id)
			return
		}
		log.Printf("Client %d: Error receiving task length: %v", id, err)
		return
	}

	task := make([]byte, taskLen)
	if _, err := io.ReadFull(conn, task); err != nil {
		log.Printf("Client %d: Error receiving task: %v", id, err)
		return
	}

	log.Printf("Client %d: Got a job: %v", id, task)

	result := calc(task)

	log.Printf("Client %d: Sending solution: %v", id, result)

	if err := binary.Write(conn, binary.BigEndian, uint32(len(result))); err != nil {
		log.Printf("Client %d: Error sending result length: %v", id, err)
		return
	}

	if _, err := conn.Write(result); err != nil {
		log.Printf("Client %d: Error sending result: %v", id, err)
		return
	}

	log.Printf("Client %d: Task done", id)
}

func main() {
	var wg sync.WaitGroup

	for i := 0; i < numClients; i++ {
		wg.Add(1)
		go runClient(i+1, &wg)
		time.Sleep(100 * time.Millisecond)
	}

	wg.Wait()
	log.Println("All clients finished")
}
