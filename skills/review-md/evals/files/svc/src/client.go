// Package client is the Go client for the ledgerd HTTP API described in specs/api.md.
package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Version is the client release. It ships with the ledgerd release of the same number.
const Version = "2.4.1"

const (
	// DefaultBaseURL points at a ledgerd on the same host.
	DefaultBaseURL = "http://127.0.0.1:8420"
	// MaxRetries is how many times a failed request is retried after the first attempt.
	MaxRetries = 5
	// RetryBackoff is the wait before the first retry. It doubles before each later retry.
	RetryBackoff = 200 * time.Millisecond
	// RequestTimeout bounds a single attempt.
	RequestTimeout = 10 * time.Second
)

// Entry is one ledger record.
type Entry struct {
	Account string `json:"account"`
	Amount  int64  `json:"amount"`
	Memo    string `json:"memo,omitempty"`
}

// Client talks to one ledgerd node.
type Client struct {
	BaseURL string
	HTTP    *http.Client
}

// New returns a Client for baseURL, or for DefaultBaseURL when baseURL is empty.
func New(baseURL string) *Client {
	if baseURL == "" {
		baseURL = DefaultBaseURL
	}
	return &Client{BaseURL: baseURL, HTTP: &http.Client{Timeout: RequestTimeout}}
}

// Map applies f to every element of xs and returns the results in order.
func Map[T any](xs []T, f func(T) T) []T {
	out := make([]T, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}

// PostEntry appends e. key is sent as the Idempotency-Key header, so a retried request is
// applied once.
func (c *Client) PostEntry(ctx context.Context, e Entry, key string) error {
	body, err := json.Marshal(e)
	if err != nil {
		return err
	}
	return c.doWithRetry(ctx, func() (*http.Request, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+"/v2/entries", bytes.NewReader(body))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Idempotency-Key", key)
		return req, nil
	}, http.StatusCreated)
}

// Drain asks the node to stop accepting writes and flush its write queue.
func (c *Client) Drain(ctx context.Context) error {
	return c.doWithRetry(ctx, func() (*http.Request, error) {
		return http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+"/v2/drain", nil)
	}, http.StatusAccepted)
}

func (c *Client) doWithRetry(ctx context.Context, build func() (*http.Request, error), want int) error {
	wait := RetryBackoff
	var lastErr error
	for attempt := 0; attempt <= MaxRetries; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(wait):
			}
			wait *= 2
		}
		req, err := build()
		if err != nil {
			return err
		}
		resp, err := c.HTTP.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		resp.Body.Close()
		if resp.StatusCode == want {
			return nil
		}
		lastErr = fmt.Errorf("ledgerd: %s returned %d, want %d", req.URL.Path, resp.StatusCode, want)
		if resp.StatusCode < 500 {
			return lastErr
		}
	}
	return lastErr
}
