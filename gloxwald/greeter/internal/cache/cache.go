package cache

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

const cacheDir = ".cache/gloxwaldgreet"
const preferencesFile = "preferences"

// UserPreferences holds cached user preferences
type UserPreferences struct {
	Username string `json:"username"` // Last successful username
}

// SavePreferences saves user preferences to cache
func SavePreferences(prefs UserPreferences) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %v", err)
	}

	cachePath := filepath.Join(home, cacheDir)
	if err := os.MkdirAll(cachePath, 0755); err != nil {
		return fmt.Errorf("failed to create cache directory: %v", err)
	}

	filePath := filepath.Join(cachePath, preferencesFile)
	data, err := json.Marshal(prefs)
	if err != nil {
		return fmt.Errorf("failed to marshal preferences: %v", err)
	}

	if err := os.WriteFile(filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write preferences file: %v", err)
	}

	return nil
}

// LoadPreferences loads user preferences from cache
func LoadPreferences() (*UserPreferences, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %v", err)
	}

	filePath := filepath.Join(home, cacheDir, preferencesFile)
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return nil, nil // No cached preferences
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read preferences file: %v", err)
	}

	var prefs UserPreferences
	if err := json.Unmarshal(data, &prefs); err != nil {
		return nil, fmt.Errorf("failed to unmarshal preferences: %v", err)
	}

	return &prefs, nil
}
