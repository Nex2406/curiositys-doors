# Minimal static server for the Godot 4 web build: adds the cross-origin
# isolation headers (COOP/COEP) that SharedArrayBuffer/threads need, plus the
# correct wasm MIME. Serves ./build on the given port.
import http.server, socketserver, sys, os
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
os.chdir(os.path.join(os.path.dirname(__file__), "..", "build"))
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def guess_type(self, path):
        if path.endswith(".wasm"): return "application/wasm"
        return super().guess_type(path)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
    print("serving build/ at http://localhost:%d  (COOP/COEP on)" % PORT)
    httpd.serve_forever()
