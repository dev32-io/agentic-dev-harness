// Minimal Bun HTTP server — demonstrates the post-install harness layout.
const server = Bun.serve({
  port: 3000,
  fetch() {
    return new Response("Hello from agentic-dev-harness web-bun-sample");
  },
});

console.log(`Listening on http://localhost:${server.port}`);
