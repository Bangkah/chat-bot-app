package main

import (
	"net/http"
	"github.com/gin-gonic/gin"
	"io/ioutil"
	"bytes"
	"sync"
	"time"
	"math/rand"
	"fmt"
)

type ChatMessage struct {
	Sender    string    `json:"sender"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

type ChatSession struct {
	ID       string        `json:"id"`
	Name     string        `json:"name"`
	Messages []ChatMessage `json:"messages"`
}

var (
	sessions   = make(map[string]*ChatSession)
	sessionsMu sync.RWMutex
	)

func init() {
	// Data dummy: dua sesi dengan riwayat chat berbeda
	sessions["session-1"] = &ChatSession{
		ID:   "session-1",
		Name: "Tanya AI",
		Messages: []ChatMessage{
			{Sender: "user", Message: "Hai, siapa namamu?", Timestamp: time.Now().Add(-10 * time.Minute)},
			{Sender: "bot", Message: "Saya adalah bot AI Ollama.", Timestamp: time.Now().Add(-9 * time.Minute)},
			{Sender: "user", Message: "Apa yang bisa kamu lakukan?", Timestamp: time.Now().Add(-8 * time.Minute)},
			{Sender: "bot", Message: "Saya bisa menjawab pertanyaan dan membantu Anda.", Timestamp: time.Now().Add(-7 * time.Minute)},
		},
	}
	sessions["session-2"] = &ChatSession{
		ID:   "session-2",
		Name: "Belajar Flutter",
		Messages: []ChatMessage{
			{Sender: "user", Message: "Bagaimana cara membuat aplikasi Flutter?", Timestamp: time.Now().Add(-6 * time.Minute)},
			{Sender: "bot", Message: "Anda bisa mulai dengan flutter create nama_app.", Timestamp: time.Now().Add(-5 * time.Minute)},
			{Sender: "user", Message: "Bagaimana menampilkan daftar chat?", Timestamp: time.Now().Add(-4 * time.Minute)},
			{Sender: "bot", Message: "Gunakan ListView.builder untuk menampilkan daftar chat di Flutter.", Timestamp: time.Now().Add(-3 * time.Minute)},
		},
	}
}

// Endpoint & Route Documentation:
// POST   /session           -> Create new chat session (body: {"name": "Session Name"})
// GET    /session           -> List all chat sessions
// DELETE /session/:id       -> Delete chat session by ID
// GET    /chat/:session_id  -> Get chat history for session
// POST   /chat/:session_id  -> Send message to session (body: {"message": "..."}), returns bot reply

func main() {
	r := gin.Default()

	// Create new session
	r.POST("/session", func(c *gin.Context) {
		var req struct {
			Name string `json:"name"`
		}
		if err := c.BindJSON(&req); err != nil || req.Name == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}
		id := generateSessionID()
		session := &ChatSession{ID: id, Name: req.Name, Messages: []ChatMessage{}}
		sessionsMu.Lock()
		sessions[id] = session
		sessionsMu.Unlock()
		c.JSON(http.StatusOK, session)
	})

	// List all sessions
	r.GET("/session", func(c *gin.Context) {
		sessionsMu.RLock()
		var list []*ChatSession
		for _, s := range sessions {
			list = append(list, s)
		}
		sessionsMu.RUnlock()
		c.JSON(http.StatusOK, list)
	})

	// Delete session
	r.DELETE("/session/:id", func(c *gin.Context) {
		id := c.Param("id")
		sessionsMu.Lock()
		defer sessionsMu.Unlock()
		if _, ok := sessions[id]; !ok {
			c.JSON(http.StatusNotFound, gin.H{"error": "Session not found"})
			return
		}
		delete(sessions, id)
		c.JSON(http.StatusOK, gin.H{"status": "deleted"})
	})

	// Get chat history for session
	r.GET("/chat/:session_id", func(c *gin.Context) {
		id := c.Param("session_id")
		sessionsMu.RLock()
		session, ok := sessions[id]
		sessionsMu.RUnlock()
		if !ok {
			c.JSON(http.StatusNotFound, gin.H{"error": "Session not found"})
			return
		}
		c.JSON(http.StatusOK, session.Messages)
	})

	// Send message to session (and Ollama)
	r.POST("/chat/:session_id", func(c *gin.Context) {
		id := c.Param("session_id")
		var req struct {
			Message string `json:"message"`
		}
		if err := c.BindJSON(&req); err != nil || req.Message == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}
		sessionsMu.Lock()
		session, ok := sessions[id]
		sessionsMu.Unlock()
		if !ok {
			c.JSON(http.StatusNotFound, gin.H{"error": "Session not found"})
			return
		}
		       userMsg := ChatMessage{Sender: "user", Message: req.Message, Timestamp: time.Now()}
		       sessionsMu.Lock()
		       session.Messages = append(session.Messages, userMsg)
		       sessionsMu.Unlock()

		       // Always use Ollama for bot response
		       ollamaResp, err := sendToOllama(req.Message)
		       if err != nil {
			       c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			       return
		       }
		       botMsg := ChatMessage{Sender: "bot", Message: ollamaResp, Timestamp: time.Now()}
		       sessionsMu.Lock()
		       session.Messages = append(session.Messages, botMsg)
		       sessionsMu.Unlock()
		       c.JSON(http.StatusOK, botMsg)
	})

	r.Run(":8080")
}

func sendToOllama(message string) (string, error) {
	       ollamaURL := "http://localhost:11434/api/chat"
	       jsonStr := []byte(fmt.Sprintf(`{"model": "llama2", "message": "%s"}`, message))
	       resp, err := http.Post(ollamaURL, "application/json", bytes.NewBuffer(jsonStr))
	       if err != nil {
		       return "", err
	       }
	       defer resp.Body.Close()
	       body, err := ioutil.ReadAll(resp.Body)
	       if err != nil {
		       return "", err
	       }
	       // Parse JSON response from Ollama
	       var result map[string]interface{}
	       if err := json.Unmarshal(body, &result); err != nil {
		       return string(body), nil // fallback: return raw response
	       }
	       // Try to get 'message' or 'response' field
	       if msg, ok := result["message"].(string); ok {
		       return msg, nil
	       }
	       if resp, ok := result["response"].(string); ok {
		       return resp, nil
	       }
	       return string(body), nil // fallback: return raw response
}

func generateSessionID() string {
	return fmt.Sprintf("%d%d", time.Now().UnixNano(), rand.Intn(10000))
}
