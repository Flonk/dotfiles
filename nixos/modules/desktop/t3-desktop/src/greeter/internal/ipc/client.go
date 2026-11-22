package ipc

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
)

type RequestType string
type ResponseType string

const (
	CreateSessionRequest           RequestType = "create_session"
	PostAuthMessageResponseRequest RequestType = "post_auth_message_response"
	StartSessionRequest            RequestType = "start_session"
	CancelSessionRequest           RequestType = "cancel_session"

	SuccessResponse     ResponseType = "success"
	ErrorResponse       ResponseType = "error"
	AuthMessageResponse ResponseType = "auth_message"
)

type CreateSession struct {
	Type     RequestType `json:"type"`
	Username string      `json:"username"`
}

type PostAuthMessageResponse struct {
	Type     RequestType `json:"type"`
	Response *string     `json:"response"`
}

type StartSession struct {
	Type RequestType `json:"type"`
	Cmd  []string    `json:"cmd"`
	Env  []string    `json:"env"`
}

type CancelSession struct {
	Type RequestType `json:"type"`
}

type Success struct {
	Type ResponseType `json:"type"`
}

type Error struct {
	Type        ResponseType `json:"type"`
	ErrorType   string       `json:"error_type"`
	Description string       `json:"description"`
}

type AuthMessage struct {
	Type            ResponseType `json:"type"`
	AuthMessageType string       `json:"auth_message_type"`
	AuthMessage     string       `json:"auth_message"`
}

type Client struct {
	conn net.Conn
}

func NewClient() (*Client, error) {
	socketPath := os.Getenv("GREETD_SOCK")
	if socketPath == "" {
		return nil, fmt.Errorf("GREETD_SOCK environment variable not set")
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to greetd socket at %s: %v", socketPath, err)
	}

	return &Client{conn: conn}, nil
}

func (c *Client) Close() error {
	return c.conn.Close()
}

func (c *Client) SendRequest(req interface{}) error {
	data, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %v", err)
	}

	length := uint32(len(data))
	lengthBytes := make([]byte, 4)
	binary.LittleEndian.PutUint32(lengthBytes, length)

	_, err = c.conn.Write(lengthBytes)
	if err != nil {
		return fmt.Errorf("failed to write length: %v", err)
	}

	_, err = c.conn.Write(data)
	if err != nil {
		return fmt.Errorf("failed to write data: %v", err)
	}

	return nil
}

func (c *Client) ReceiveResponse() (interface{}, error) {
	lengthBytes := make([]byte, 4)
	_, err := io.ReadFull(c.conn, lengthBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to read length: %v", err)
	}

	length := binary.LittleEndian.Uint32(lengthBytes)
	data := make([]byte, length)
	_, err = io.ReadFull(c.conn, data)
	if err != nil {
		return nil, fmt.Errorf("failed to read data: %v", err)
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %v", err)
	}

	respType, ok := raw["type"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid response: missing type")
	}

	switch ResponseType(respType) {
	case SuccessResponse:
		var resp Success
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, err
		}
		return resp, nil
	case ErrorResponse:
		var resp Error
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, err
		}
		return resp, nil
	case AuthMessageResponse:
		var resp AuthMessage
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, err
		}
		return resp, nil
	default:
		return nil, fmt.Errorf("unknown response type: %s", respType)
	}
}

func (c *Client) CreateSession(username string) error {
	req := CreateSession{
		Type:     CreateSessionRequest,
		Username: username,
	}
	return c.SendRequest(req)
}

func (c *Client) PostAuthMessageResponse(response *string) error {
	req := PostAuthMessageResponse{
		Type:     PostAuthMessageResponseRequest,
		Response: response,
	}
	return c.SendRequest(req)
}

func (c *Client) StartSession(cmd []string, env []string) error {
	req := StartSession{
		Type: StartSessionRequest,
		Cmd:  cmd,
		Env:  env,
	}

	if err := c.SendRequest(req); err != nil {
		return err
	}

	resp, err := c.ReceiveResponse()
	if err != nil {
		return fmt.Errorf("failed to receive start session response: %v", err)
	}

	if _, ok := resp.(Success); ok {
		return nil
	}

	if errResp, ok := resp.(Error); ok {
		return fmt.Errorf("failed to start session: %s - %s", errResp.ErrorType, errResp.Description)
	}

	return fmt.Errorf("unexpected response to start_session: %T", resp)
}

func (c *Client) CancelSession() error {
	req := CancelSession{
		Type: CancelSessionRequest,
	}

	if err := c.SendRequest(req); err != nil {
		return err
	}

	resp, err := c.ReceiveResponse()
	if err != nil {
		return fmt.Errorf("failed to receive CancelSession response: %v", err)
	}

	if _, ok := resp.(Success); !ok {
		if _, ok := resp.(Error); ok {
			return nil
		}
		return fmt.Errorf("unexpected response to CancelSession: %T", resp)
	}

	return nil
}
