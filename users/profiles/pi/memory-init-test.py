"""Offline tests: python3 users/profiles/pi/memory-init-test.py."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest

SCRIPT = Path(__file__).with_name("memory-init.nu")


class MemoryInitTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        subprocess.run(["jj", "git", "init", "--colocate", str(self.root)],
                       check=True, capture_output=True)
        self.requests = []
        self.exists = False
        self.status = None
        self.recall_error = False
        test = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def respond(self, status, body):
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(body).encode())

            def do_GET(self):
                test.requests.append(("GET", self.path))
                self.respond(test.status or (200 if test.exists else 404), {})

            def do_PUT(self):
                test.requests.append(("PUT", self.path))
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                assert body == {}
                test.exists = True
                self.respond(200, {})

            def do_POST(self):
                test.requests.append(("POST", self.path))
                self.respond(200, {"error": "failed"} if test.recall_error else {"results": []})

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{server.server_port}"

    def run_init(self, bank="test-bank", cwd=None, success=True):
        result = subprocess.run(
            ["nu", "--no-config-file", str(SCRIPT), bank, "--server", self.url],
            cwd=cwd or self.root, text=True, capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def seed_config(self, config):
        (self.root / ".pi").mkdir(exist_ok=True)
        (self.root / ".pi/mcp.json").write_text(json.dumps(config))

    def test_create_from_subdirectory_and_repeat(self):
        child = self.root / "src"
        child.mkdir()
        self.run_init(cwd=child)
        config = json.loads((self.root / ".pi/mcp.json").read_text())
        server = config["mcpServers"]["hindsight"]
        self.assertEqual(server["url"], self.url + "/mcp/test-bank/")
        self.assertEqual(server["exposure"], "hidden")
        self.assertEqual(server["toolExposure"], dict.fromkeys(["retain", "recall", "reflect"], "codemode"))
        self.assertIn("bank `test-bank`", (self.root / ".pi/APPEND_SYSTEM.md").read_text())
        files = [self.root / p for p in [".pi/mcp.json", ".pi/APPEND_SYSTEM.md", ".git/info/exclude"]]
        before = [p.read_bytes() for p in files]
        self.run_init()
        self.assertEqual(before, [p.read_bytes() for p in files])
        self.assertEqual(sum(method == "PUT" for method, _ in self.requests), 1)
        ignored = subprocess.run(["git", "check-ignore", ".pi/mcp.json", ".pi/APPEND_SYSTEM.md"],
                                 cwd=self.root, check=True, text=True, capture_output=True)
        self.assertEqual(len(ignored.stdout.splitlines()), 2)
        tracked = subprocess.run(["jj", "file", "list", "root:.pi"], cwd=self.root,
                                 check=True, text=True, capture_output=True)
        self.assertEqual(tracked.stdout, "")

    def test_preserves_existing_files_and_bank(self):
        self.exists = True
        self.seed_config({"autoEnableCodemode": False, "mcpServers": {"other": {"url": "https://example.com/mcp"}}})
        policy = self.root / ".pi/APPEND_SYSTEM.md"
        policy.write_text("Personal instructions\n")
        self.run_init()
        config = json.loads((self.root / ".pi/mcp.json").read_text())
        self.assertFalse(config["autoEnableCodemode"])
        self.assertIn("other", config["mcpServers"])
        self.assertEqual(policy.read_text(), "Personal instructions\n")
        self.assertFalse(any(method == "PUT" for method, _ in self.requests))

    def test_existing_matching_connection_keeps_custom_description(self):
        self.seed_config({"mcpServers": {"hindsight": {
            "url": self.url + "/mcp/test-bank/",
            "description": "My custom description",
            "exposure": "hidden",
            "toolExposure": dict.fromkeys(["retain", "recall", "reflect"], "codemode"),
        }}})
        before = (self.root / ".pi/mcp.json").read_bytes()
        self.run_init()
        self.assertEqual(before, (self.root / ".pi/mcp.json").read_bytes())

    def test_invalid_config_is_refused_before_network(self):
        self.seed_config({"mcpServers": []})
        self.run_init(success=False)
        self.assertEqual(self.requests, [])

    def test_conflicting_config_is_untouched(self):
        self.seed_config({"mcpServers": {"hindsight": {"url": "https://other/mcp/"}}})
        before = (self.root / ".pi/mcp.json").read_bytes()
        self.run_init(success=False)
        self.assertEqual(before, (self.root / ".pi/mcp.json").read_bytes())
        self.assertEqual(self.requests, [])

    def test_tracked_config_is_refused(self):
        self.seed_config({})
        subprocess.run(["jj", "file", "track", "--include-ignored", ".pi/mcp.json"],
                       cwd=self.root, check=True, capture_output=True)
        subprocess.run(["jj", "status"], cwd=self.root, check=True, capture_output=True)
        self.assertIn(".pi/mcp.json", subprocess.run(
            ["git", "ls-files", "--", ".pi/mcp.json"], cwd=self.root,
            check=True, text=True, capture_output=True).stdout)
        self.run_init(success=False)
        self.assertEqual(self.requests, [])

    def test_symlink_is_refused(self):
        target = self.root / "elsewhere"
        target.mkdir()
        (self.root / ".pi").symlink_to(target, target_is_directory=True)
        self.run_init(success=False)
        self.assertEqual(self.requests, [])
        self.assertEqual(list(target.iterdir()), [])

    def test_http_error_does_not_create_bank_or_files(self):
        self.status = 403
        self.run_init(success=False)
        self.assertEqual([m for m, _ in self.requests], ["GET"])
        self.assertFalse((self.root / ".pi").exists())

    def test_recall_error_leaves_local_files_untouched(self):
        self.recall_error = True
        self.run_init(success=False)
        self.assertFalse((self.root / ".pi").exists())

    def test_invalid_bank_is_refused_before_network(self):
        self.run_init("../other", success=False)
        self.assertEqual(self.requests, [])


if __name__ == "__main__":
    unittest.main()
