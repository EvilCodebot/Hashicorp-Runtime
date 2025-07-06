package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func logRequest(handler http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        log.Printf("Received request from %s: %s %s", r.RemoteAddr, r.Method, r.URL.Path)
        handler(w, r)
    }
}

func main() {
    port := os.Getenv("LISTEN_PORT")
    if port == "" {
        log.Fatal("LISTEN_PORT environment variable not set")
    }

    address := "0.0.0.0:" + port

    http.HandleFunc("/", logRequest(func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello, World!")
    }))

    log.Printf("Server listening on http://%s\n", address)
    err := http.ListenAndServe(address, nil)
    if err != nil {
        log.Fatalf("Failed to start server: %v", err)
    }
} 