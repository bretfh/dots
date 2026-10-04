from http.server import SimpleHTTPRequestHandler
import socketserver
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument('-d', '--dir', default='.', help='Directory to serve')
parser.add_argument('-p', '--port', type=int, default=8000, help='Port number')
args = parser.parse_args()

handler = SimpleHTTPRequestHandler
handler.directory = args.dir

with socketserver.TCPServer(("", args.port), handler) as httpd:
    print(f"Serving {args.dir} on port {args.port}")
    httpd.serve_forever()
