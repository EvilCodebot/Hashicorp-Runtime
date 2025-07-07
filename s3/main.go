package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"net/http"
	"os"
)

func logRequest(handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s - from %s", r.Method, r.URL.Path, r.RemoteAddr)
		handler(w, r)
	}
}

func main() {
	port := os.Getenv("LISTEN_PORT")
	if port == "" {
		log.Fatal("LISTEN_PORT environment variable not set")
	}

	// Load TLS certificate and key
	certFile := os.Getenv("TLS_CERT")
	keyFile := os.Getenv("TLS_KEY")
	caFile := os.Getenv("TLS_CA")

	if certFile == "" || keyFile == "" || caFile == "" {
		log.Fatal("TLS_CERT, TLS_KEY, and TLS_CA environment variables must be set")
	}

	// Load CA cert
	caCert, err := os.ReadFile(caFile)
	if err != nil {
		log.Fatalf("Failed to read CA certificate: %v", err)
	}

	caCertPool := x509.NewCertPool()
	if !caCertPool.AppendCertsFromPEM(caCert) {
		log.Fatal("Failed to append CA certificate")
	}

	// Configure TLS
	tlsConfig := &tls.Config{
		ClientCAs:  caCertPool,
		ClientAuth: tls.RequireAndVerifyClientCert,
		MinVersion: tls.VersionTLS12,
	}

	server := &http.Server{
		Addr:      "0.0.0.0:" + port,
		TLSConfig: tlsConfig,
	}

	http.HandleFunc("/", logRequest(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello, World!")
	}))

	log.Printf("Server listening on https://0.0.0.0:%s\n", port)
	err = server.ListenAndServeTLS(certFile, keyFile)
	if err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
