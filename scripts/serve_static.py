"""Простой статический сервер с запретом кэша (dev). Аргументы: <порт> <папка>.
Используется для: витрина-сайт (5500), превью сайта (5577), превью web-сборки
приложения (5578). No-cache — чтобы конструктор/превью сразу видели свежие правки.
"""
import http.server
import os
import socketserver
import sys

port = int(sys.argv[1])
directory = sys.argv[2]
os.chdir(directory)


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        super().end_headers()


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
    print(f"serving :{port} (no-cache) from {os.getcwd()}")
    httpd.serve_forever()
