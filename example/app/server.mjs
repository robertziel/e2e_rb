// The app under test: one page that greets the name you type.
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';

const port = Number(process.env.PORT);
if (!Number.isInteger(port) || port <= 0) throw new Error('PORT is not set (e2e passes it from e2e.config.ts)');
const page = readFileSync(new URL('./index.html', import.meta.url));

createServer((_request, response) => {
  response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  response.end(page);
}).listen(port, '127.0.0.1', () => console.error(`example app on :${port}`));
