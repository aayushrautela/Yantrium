package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/anacrolix/torrent"
)

type TorrentServer struct {
	client        *torrent.Client
	port          int
	streamPort    int
	activeTorrents map[string]*torrent.Torrent
}

type AddMagnetRequest struct {
	Magnet string `json:"magnet"`
	FileIndex *int `json:"fileIndex,omitempty"` // Optional: specify which file to stream
}

type AddMagnetResponse struct {
	StreamURL string `json:"streamUrl"`
	TorrentID string `json:"torrentId"`
	Files     []FileInfo `json:"files"`
}

type FileInfo struct {
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	Index  int    `json:"index"`
}

type StatusResponse struct {
	Torrents []TorrentStatus `json:"torrents"`
}

type TorrentStatus struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Progress float64 `json:"progress"`
	Status   string  `json:"status"`
	DownloadSpeed int64 `json:"downloadSpeed"`
	UploadSpeed   int64 `json:"uploadSpeed"`
}

func NewTorrentServer(port, streamPort int) *TorrentServer {
	// Create data directory
	dataDir := filepath.Join(os.TempDir(), "yatrium-torrents")
	os.MkdirAll(dataDir, 0755)

	config := torrent.NewDefaultClientConfig()
	config.DataDir = dataDir
	config.NoUpload = false // Allow seeding
	config.Seed = true
	// Optimize for streaming
	config.DropMutuallyCompletePeers = true
	// Limit connections to prevent network choking
	config.EstablishedConnsPerTorrent = 50
	config.HalfOpenConnsPerTorrent = 10
	
	// Use port 0 to let OS assign an available port (avoids conflicts)
	// Or use a high port that's less likely to conflict
	config.ListenPort = 0 // 0 = OS picks available port

	client, err := torrent.NewClient(config)
	if err != nil {
		log.Fatal("Failed to create torrent client:", err)
	}
	
	// Log the actual port that was assigned
	if actualPort := client.LocalPort(); actualPort != 0 {
		log.Printf("Torrent client listening on port %d", actualPort)
	}

	return &TorrentServer{
		client:        client,
		port:          port,
		streamPort:    streamPort,
		activeTorrents: make(map[string]*torrent.Torrent),
	}
}

func (ts *TorrentServer) handleAddMagnet(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req AddMagnetRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	log.Printf("Adding magnet: %s", req.Magnet)

	t, err := ts.client.AddMagnet(req.Magnet)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to add magnet: %v", err), http.StatusInternalServerError)
		return
	}

	// Wait for torrent info with longer timeout for real-world scenarios
	// Some torrents take time to fetch metadata from DHT/bootstrap nodes
	log.Printf("Waiting for torrent metadata...")
	select {
	case <-t.GotInfo():
		log.Printf("Got info for torrent: %s", t.Info().Name)
	case <-time.After(120 * time.Second): // Increased to 2 minutes
		log.Printf("Timeout waiting for torrent info after 120 seconds")
		http.Error(w, "Timeout waiting for torrent info (120s). The torrent may have few seeders or network issues.", http.StatusRequestTimeout)
		return
	}

	torrentID := t.InfoHash().String()
	ts.activeTorrents[torrentID] = t

	// Get file list
	files := t.Files()
	fileInfos := make([]FileInfo, len(files))
	for i, file := range files {
		fileInfos[i] = FileInfo{
			Name:  file.Path(),
			Size:  file.Length(),
			Index: i,
		}
	}

	// Determine which file to stream (default to first .mp4/.mkv file or first file)
	streamFileIndex := 0
	if req.FileIndex != nil {
		streamFileIndex = *req.FileIndex
	} else {
		// Auto-select video file
		for i, file := range files {
			name := strings.ToLower(file.Path())
			if strings.HasSuffix(name, ".mp4") || strings.HasSuffix(name, ".mkv") ||
			   strings.HasSuffix(name, ".avi") || strings.HasSuffix(name, ".mov") {
				streamFileIndex = i
				break
			}
		}
	}

	// Let anacrolix handle piece prioritization automatically based on active readers
	// When we create a file reader later, anacrolix will prioritize pieces intelligently

	streamURL := fmt.Sprintf("http://localhost:%d/stream/%s/%d", ts.streamPort, torrentID, streamFileIndex)

	response := AddMagnetResponse{
		StreamURL: streamURL,
		TorrentID: torrentID,
		Files:     fileInfos,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ts *TorrentServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	torrents := make([]TorrentStatus, 0, len(ts.activeTorrents))

	for id, t := range ts.activeTorrents {
		bytesCompleted := t.BytesCompleted()
		totalBytes := t.Length()

		var progress float64
		if totalBytes > 0 {
			progress = float64(bytesCompleted) / float64(totalBytes) * 100
		}

		status := TorrentStatus{
			ID:       id,
			Name:     t.Info().Name,
			Progress: progress,
			Status:   "downloading",
			DownloadSpeed: 0, // Individual torrent speeds not directly available
			UploadSpeed:   0, // Use client-level stats instead
		}

		if bytesCompleted >= totalBytes && totalBytes > 0 {
			status.Status = "completed"
		}

		torrents = append(torrents, status)
	}

	response := StatusResponse{Torrents: torrents}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}


func (ts *TorrentServer) handleRemoveTorrent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	torrentID := strings.TrimPrefix(r.URL.Path, "/remove/")
	if torrentID == "" {
		http.Error(w, "Torrent ID required", http.StatusBadRequest)
		return
	}

	if t, exists := ts.activeTorrents[torrentID]; exists {
		t.Drop()
		delete(ts.activeTorrents, torrentID)
		w.WriteHeader(http.StatusOK)
	} else {
		http.Error(w, "Torrent not found", http.StatusNotFound)
	}
}

func (ts *TorrentServer) startStreamingServer() {
	mux := http.NewServeMux()

	// Stream endpoint
	mux.HandleFunc("/stream/", func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/stream/")
		parts := strings.Split(path, "/")

		if len(parts) != 2 {
			http.Error(w, "Invalid stream URL", http.StatusBadRequest)
			return
		}

		torrentID := parts[0]
		fileIndexStr := parts[1]
		fileIndex, err := strconv.Atoi(fileIndexStr)
		if err != nil {
			http.Error(w, "Invalid file index", http.StatusBadRequest)
			return
		}

		t, exists := ts.activeTorrents[torrentID]
		if !exists {
			http.Error(w, "Torrent not found", http.StatusNotFound)
			return
		}

		files := t.Files()
		if fileIndex < 0 || fileIndex >= len(files) {
			http.Error(w, "File index out of range", http.StatusBadRequest)
			return
		}

		file := files[fileIndex]

		// Manual streaming for torrent compatibility
		// This avoids http.ServeContent's assumptions about file readers
		reader := file.NewReader()
		defer reader.Close()

		fileSize := file.Length()
		contentType := "video/mp4" // Default to MP4 for video players

		// Detect content type from file extension
		fileName := strings.ToLower(file.Path())
		if strings.HasSuffix(fileName, ".mkv") {
			contentType = "video/x-matroska"
		} else if strings.HasSuffix(fileName, ".avi") {
			contentType = "video/x-msvideo"
		} else if strings.HasSuffix(fileName, ".mov") {
			contentType = "video/quicktime"
		}

		// Set headers
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Content-Length", strconv.FormatInt(fileSize, 10))
		w.Header().Set("Cache-Control", "no-cache")

		// Handle range requests
		statusCode := http.StatusOK
		var start, end int64 = 0, fileSize - 1

		if rangeHeader := r.Header.Get("Range"); rangeHeader != "" {
			// Parse range header (e.g., "bytes=0-1023")
			if strings.HasPrefix(rangeHeader, "bytes=") {
				rangeSpec := strings.TrimPrefix(rangeHeader, "bytes=")
				if strings.Contains(rangeSpec, "-") {
					parts := strings.Split(rangeSpec, "-")
					if len(parts) == 2 {
						if parts[0] != "" {
							if parsed, err := strconv.ParseInt(parts[0], 10, 64); err == nil {
								start = parsed
							}
						}
						if parts[1] != "" {
							if parsed, err := strconv.ParseInt(parts[1], 10, 64); err == nil {
								end = parsed
							}
						}
						statusCode = http.StatusPartialContent
						w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, fileSize))
						w.Header().Set("Content-Length", strconv.FormatInt(end-start+1, 10))
					}
				}
			}
		}

		w.WriteHeader(statusCode)

		// Seek to start position if needed
		if start > 0 {
			if seeker, ok := reader.(io.Seeker); ok {
				if _, err := seeker.Seek(start, io.SeekStart); err != nil {
					log.Printf("Failed to seek to position %d: %v", start, err)
					return
				}
			}
		}

		// Stream the data
		if statusCode == http.StatusPartialContent {
			// For range requests, only send the requested bytes
			bytesToSend := end - start + 1
			if bytesToSend > 0 {
				if _, err := io.CopyN(w, reader, bytesToSend); err != nil && err != io.EOF {
					log.Printf("Error streaming range request: %v", err)
				}
			}
		} else {
			// Send the entire file
			if _, err := io.Copy(w, reader); err != nil && err != io.EOF {
				log.Printf("Error streaming file: %v", err)
			}
		}
	})

	log.Printf("Starting streaming server on port %d", ts.streamPort)
	go func() {
		if err := http.ListenAndServe(fmt.Sprintf(":%d", ts.streamPort), mux); err != nil {
			log.Fatal("Streaming server failed:", err)
		}
	}()
}

func (ts *TorrentServer) Start() {
	// Start streaming server
	ts.startStreamingServer()

	// Main API server
	mux := http.NewServeMux()
	mux.HandleFunc("/add", ts.handleAddMagnet)
	mux.HandleFunc("/status", ts.handleStatus)
	mux.HandleFunc("/remove/", ts.handleRemoveTorrent)

	log.Printf("Starting torrent API server on port %d", ts.port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", ts.port), mux))
}

func (ts *TorrentServer) Close() {
	ts.client.Close()
}

func main() {
	// Set log output to stdout instead of stderr (default)
	log.SetOutput(os.Stdout)

	port := 8080
	streamPort := 8081

	// Allow custom ports via environment variables
	if p := os.Getenv("TORRENT_API_PORT"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil {
			port = parsed
		}
	}
	if p := os.Getenv("TORRENT_STREAM_PORT"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil {
			streamPort = parsed
		}
	}

	server := NewTorrentServer(port, streamPort)
	defer server.Close()

	log.Printf("Torrent sidecar starting - API: %d, Stream: %d", port, streamPort)
	server.Start()
}



