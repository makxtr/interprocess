package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"sort"
)

const (
	port = 2000
	step = 4
)

type Task struct {
	ID   int
	Data []byte
}

type Result struct {
	ID   int
	Data []byte
}

type Server struct {
	taskChan   chan Task
	resultChan chan Result
	doneChan   chan struct{}
	totalTasks int
}

func NewServer(data []byte, step int) *Server {
	tasks := make([][]byte, 0)
	for i := 0; i < len(data); i += step {
		end := i + step
		if end > len(data) {
			end = len(data)
		}
		chunk := make([]byte, end-i)
		copy(chunk, data[i:end])
		tasks = append(tasks, chunk)
	}

	s := &Server{
		taskChan:   make(chan Task, len(tasks)),
		resultChan: make(chan Result, len(tasks)),
		doneChan:   make(chan struct{}),
		totalTasks: len(tasks),
	}

	for i, task := range tasks {
		s.taskChan <- Task{ID: i, Data: task}
	}
	close(s.taskChan)

	return s
}

func (s *Server) handleClient(conn net.Conn) {
	defer conn.Close()

	var clientPort int
	if tcpAddr, ok := conn.RemoteAddr().(*net.TCPAddr); ok {
		clientPort = tcpAddr.Port
	}

	log.Printf("Connected: %d", clientPort)

	task, ok := <-s.taskChan
	if !ok {
		log.Printf("No tasks available, closing connection: %d", clientPort)
		return
	}

	if err := binary.Write(conn, binary.BigEndian, uint32(len(task.Data))); err != nil {
		log.Printf("Error sending task length: %v", err)
		//s.taskChan <- task // panic channel is closed
		return
	}

	if _, err := conn.Write(task.Data); err != nil {
		log.Printf("Error sending task: %v", err)
		return
	}

	var resultLen uint32
	if err := binary.Read(conn, binary.BigEndian, &resultLen); err != nil {
		log.Printf("Error receiving result length: %v", err)
		return
	}

	resultData := make([]byte, resultLen)
	if _, err := io.ReadFull(conn, resultData); err != nil {
		log.Printf("Error receiving result: %v", err)
		return
	}

	log.Printf("From %d: %v", clientPort, resultData)

	s.resultChan <- Result{ID: task.ID, Data: resultData}

	log.Printf("Closed %d", clientPort)
}

func (s *Server) collectResults() {
	results := make([]Result, 0, s.totalTasks)

	for i := 0; i < s.totalTasks; i++ {
		result := <-s.resultChan
		results = append(results, result)
	}

	log.Println("All done!")
	log.Printf("Results: %+v", results)

	sort.Slice(results, func(i, j int) bool {
		return results[i].ID < results[j].ID
	})

	finish := make([]byte, 0)
	for _, r := range results {
		finish = append(finish, r.Data...)
	}

	log.Printf("Final results: %v", finish)
	close(s.doneChan)
}

func (s *Server) Start() {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}

	log.Printf("Server started on port %d", port)

	go s.collectResults()

	go func() {
		for {
			select {
			case <-s.doneChan:
				return
			default:
				conn, err := listener.Accept()
				if err != nil {
					select {
					case <-s.doneChan:
						return
					default:
						log.Printf("Error accepting connection: %v", err)
						continue
					}
				}
				go s.handleClient(conn)
			}
		}
	}()

	<-s.doneChan

	listener.Close()
	log.Println("Server stopped")
}

func main() {
	data := []byte{2, 17, 3, 2, 5, 7, 15, 22, 1, 14, 15, 9, 0, 11}
	server := NewServer(data, step)
	server.Start()
}
