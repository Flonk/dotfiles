#!/usr/bin/env python3
"""
Mock greetd IPC server for testing the greeter without logging out.

Accepts all create_session / post_auth_message_response / start_session
requests and responds with success. Simulates one PAM password prompt.
"""

import json
import os
import socket
import struct
import sys
import signal

SOCK_PATH = sys.argv[1] if len(sys.argv) > 1 else "/tmp/greetd-mock.sock"


def send_msg(conn: socket.socket, payload: dict):
    data = json.dumps(payload).encode("utf-8")
    conn.sendall(struct.pack("=I", len(data)) + data)


def recv_msg(conn: socket.socket) -> dict | None:
    raw = b""
    while len(raw) < 4:
        chunk = conn.recv(4 - len(raw))
        if not chunk:
            return None
        raw += chunk
    length = struct.unpack("=I", raw)[0]
    data = b""
    while len(data) < length:
        chunk = conn.recv(length - len(data))
        if not chunk:
            return None
        data += chunk
    return json.loads(data.decode("utf-8"))


def handle_client(conn: socket.socket):
    """Handle one greeter connection."""
    while True:
        msg = recv_msg(conn)
        if msg is None:
            break

        msg_type = msg.get("type", "")
        print(f"[mock-greetd] <- {msg_type}: {json.dumps(msg)}")

        if msg_type == "create_session":
            user = msg.get("username", "?")
            print(f"[mock-greetd] Creating session for user: {user}")
            # Simulate PAM asking for a password
            send_msg(conn, {
                "type": "auth_message",
                "auth_message_type": "secret",
                "auth_message": "Password:",
            })

        elif msg_type == "post_auth_message_response":
            pw = msg.get("response", "")
            print(f"[mock-greetd] Got password: {'*' * len(pw) if pw else '(empty)'}")
            # Always succeed in mock mode
            send_msg(conn, {"type": "success"})

        elif msg_type == "start_session":
            cmd = msg.get("cmd", [])
            print(f"[mock-greetd] Would start session: {' '.join(cmd)}")
            send_msg(conn, {"type": "success"})
            print("[mock-greetd] Session 'started' — greeter should exit now.")
            break

        elif msg_type == "cancel_session":
            print("[mock-greetd] Session cancelled.")
            send_msg(conn, {"type": "success"})

        else:
            print(f"[mock-greetd] Unknown message type: {msg_type}")
            send_msg(conn, {
                "type": "error",
                "error_type": "error",
                "description": f"Unknown message type: {msg_type}",
            })

    conn.close()


def main():
    # Clean up stale socket
    if os.path.exists(SOCK_PATH):
        os.unlink(SOCK_PATH)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCK_PATH)
    server.listen(1)

    def cleanup(*_):
        server.close()
        if os.path.exists(SOCK_PATH):
            os.unlink(SOCK_PATH)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    print(f"[mock-greetd] Listening on {SOCK_PATH}")
    print("[mock-greetd] Any password will be accepted.")

    try:
        while True:
            conn, _ = server.accept()
            print("[mock-greetd] Client connected")
            handle_client(conn)
    except KeyboardInterrupt:
        pass
    finally:
        cleanup()


if __name__ == "__main__":
    main()
