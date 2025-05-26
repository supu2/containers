package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

type RequestLog struct {
	Timestamp   string      `json:"timestamp"`
	RemoteAddr  string      `json:"remote_addr"`
	Method      string      `json:"method"`
	URI         string      `json:"uri"`
	Protocol    string      `json:"protocol"`
	Host        string      `json:"host"`
	UserAgent   string      `json:"user_agent"`
	Referer     string      `json:"referer,omitempty"`
	RequestSize int64       `json:"request_size,omitempty"`
	RequestJSON interface{} `json:"request_json,omitempty"`
	RequestBody string      `json:"request_body,omitempty"`
}

func main() {
	// Create a new logger that writes to stdout
	logger := log.New(os.Stdout, "", 0)

	// Create a new HTTP server with our logging handler
	server := &http.Server{
		Addr: ":8080",
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Handle the request first
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("Request logged"))

			// Get the remote address (handling proxies)
			remoteAddr := r.RemoteAddr
			if forwardedFor := r.Header.Get("X-Forwarded-For"); forwardedFor != "" {
				remoteAddr = forwardedFor
			}

			// Parse the remote address to remove port if present
			host, _, err := net.SplitHostPort(remoteAddr)
			if err == nil {
				remoteAddr = host
			}

			// Initialize log entry
			logEntry := RequestLog{
				Timestamp:   time.Now().UTC().Format(time.RFC3339Nano),
				RemoteAddr:  remoteAddr,
				Method:      r.Method,
				URI:         r.RequestURI,
				Protocol:    r.Proto,
				Host:        r.Host,
				UserAgent:   r.UserAgent(),
				Referer:     r.Referer(),
				RequestSize: r.ContentLength,
			}

			// Read and parse the request body for POST/PUT/PATCH methods
			if r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodPatch {
				// Read the body while preserving it for the actual request
				bodyBytes, err := io.ReadAll(r.Body)
				if err != nil {
					logger.Printf(`{"error":"failed to read request body: %v"}`, err)
					return
				}

				// Restore the body so it can be read again by other handlers
				r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

				// Only process if there's content
				if len(bodyBytes) > 0 {
					// Try to parse as JSON
					var jsonBody interface{}
					if err := json.Unmarshal(bodyBytes, &jsonBody); err == nil {
						logEntry.RequestJSON = jsonBody
					} else {
						// If not JSON, store as string
						logEntry.RequestBody = string(bodyBytes)
					}
				}
			}

			// Marshal to JSON
			logData, err := json.Marshal(logEntry)
			if err != nil {
				logger.Printf(`{"error":"failed to marshal log entry: %v"}`, err)
				return
			}

			// Write the log entry as NDJSON
			logger.Println(string(logData))
		}),
	}

	// Start the server
	log.Printf("Starting server on %s", server.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}