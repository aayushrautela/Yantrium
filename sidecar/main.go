package main

import (
	"encoding/json"
	"fmt"
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
	client    *torrent.Client
	port      int
	streamPort int
	activeTorrents map[string]*torrent.Torrent
	streamManagers map[string]*StreamManager
}

type StreamManager struct {
	torrent         *torrent.Torrent
	fileIndex       int
	currentPosition int64  // Current playback position in bytes
	bufferAheadSize int64  // How much data to keep buffered ahead (20MB default)
	lastUpdate      time.Time
}

func NewStreamManager(t *torrent.Torrent, fileIndex int) *StreamManager {
	return &StreamManager{
		torrent:         t,
		fileIndex:       fileIndex,
		currentPosition: 0,
		bufferAheadSize: 20 * 1024 * 1024, // 20MB buffer
		lastUpdate:      time.Now(),
	}
}

// UpdatePlaybackPosition updates the current playback position and adjusts piece priorities
func (sm *StreamManager) UpdatePlaybackPosition(positionBytes int64) {
	sm.currentPosition = positionBytes
	sm.lastUpdate = time.Now()
	sm.prioritizePieces()
}

// prioritizePieces sets download priorities to maintain streaming performance
func (sm *StreamManager) prioritizePieces() {
	file := sm.torrent.Files()[sm.fileIndex]
	fileSize := file.Length()

	// Calculate which pieces we need for current position + buffer
	bytesNeeded := sm.currentPosition + sm.bufferAheadSize
	if bytesNeeded > fileSize {
		bytesNeeded = fileSize
	}

	// Convert bytes to piece indices
	pieceLength := int64(sm.torrent.Info().PieceLength)
	startPiece := int(sm.currentPosition / pieceLength)
	endPiece := int((bytesNeeded + pieceLength - 1) / pieceLength) // Round up

	if endPiece >= sm.torrent.NumPieces() {
		endPiece = sm.torrent.NumPieces() - 1
	}

	// Prioritize pieces sequentially from current position
	for i := startPiece; i <= endPiece && i < sm.torrent.NumPieces(); i++ {
		sm.torrent.Piece(i).SetPriority(torrent.PiecePriorityNormal)
	}

	// High priority for immediate next pieces (first 5 pieces ahead)
	immediateEnd := startPiece + 5
	if immediateEnd > endPiece {
		immediateEnd = endPiece
	}
	for i := startPiece; i <= immediateEnd && i < sm.torrent.NumPieces(); i++ {
		sm.torrent.Piece(i).SetPriority(torrent.PiecePriorityHigh)
	}

	// Now prioritize (but don't cancel) the pieces right after our buffer
	bufferEnd := endPiece + 10 // Next 10 pieces at normal priority (lowest)
	for i := endPiece + 1; i <= bufferEnd && i < sm.torrent.NumPieces(); i++ {
		sm.torrent.Piece(i).SetPriority(torrent.PiecePriorityNormal)
	}

	log.Printf("StreamManager: Prioritized pieces %d-%d (high), %d-%d (normal), %d-%d (normal)",
		startPiece, immediateEnd, immediateEnd+1, endPiece, endPiece+1, bufferEnd)
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

type UpdatePositionRequest struct {
	TorrentID     string `json:"torrentId"`
	FileIndex     int    `json:"fileIndex"`
	PositionBytes int64  `json:"positionBytes"`
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

	client, err := torrent.NewClient(config)
	if err != nil {
		log.Fatal("Failed to create torrent client:", err)
	}

	return &TorrentServer{
		client:         client,
		port:           port,
		streamPort:     streamPort,
		activeTorrents: make(map[string]*torrent.Torrent),
		streamManagers: make(map[string]*StreamManager),
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

	// Wait for torrent info
	select {
	case <-t.GotInfo():
		log.Printf("Got info for torrent: %s", t.Info().Name)
	case <-time.After(30 * time.Second):
		http.Error(w, "Timeout waiting for torrent info", http.StatusRequestTimeout)
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

	// Create stream manager for this torrent
	streamManager := NewStreamManager(t, streamFileIndex)
	ts.streamManagers[torrentID] = streamManager

	// Start with sequential download - prioritize first pieces for immediate playback
	streamManager.prioritizePieces()

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

func (ts *TorrentServer) handleUpdatePosition(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req UpdatePositionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	streamManager, exists := ts.streamManagers[req.TorrentID]
	if !exists {
		http.Error(w, "Stream manager not found", http.StatusNotFound)
		return
	}

	streamManager.UpdatePlaybackPosition(req.PositionBytes)
	w.WriteHeader(http.StatusOK)
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

		// Clean up stream manager
		delete(ts.streamManagers, torrentID)

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

		// Set appropriate headers
		w.Header().Set("Content-Type", "video/mp4")
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Content-Length", strconv.FormatInt(file.Length(), 10))

		// Handle range requests for seeking
		if rangeHeader := r.Header.Get("Range"); rangeHeader != "" {
			// Basic range request handling
			w.Header().Set("Content-Range", fmt.Sprintf("bytes 0-%d/%d", file.Length()-1, file.Length()))
			w.WriteHeader(http.StatusPartialContent)
		}

		// Stream the file
		reader := file.NewReader()
		defer reader.Close()

		http.ServeContent(w, r, file.Path(), time.Time{}, reader)
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
	mux.HandleFunc("/position", ts.handleUpdatePosition)
	mux.HandleFunc("/remove/", ts.handleRemoveTorrent)

	log.Printf("Starting torrent API server on port %d", ts.port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", ts.port), mux))
}

func (ts *TorrentServer) Close() {
	ts.client.Close()
}

func main() {
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
