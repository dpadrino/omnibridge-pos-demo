import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const html = readFileSync(new URL('../docs/index.html', import.meta.url), 'utf8');
const match = html.match(/<code id="pos-integration-example">([\s\S]*?)<\/code>/);
assert.ok(match, 'The public integration example must exist');
const code = match[1].replace(/<[^>]+>/g, '').replaceAll('&lt;', '<');

async function runExample(responses, apiKey = '') {
  const calls = [];
  const context = vm.createContext({
    Headers,
    fetch: async (url, options) => {
      calls.push({ url, options });
      const response = responses.shift();
      assert.ok(response, 'Unexpected extra request');
      return {
        ok: response.status >= 200 && response.status < 300,
        status: response.status,
        json: async () => {
          if (response.nonJson) throw new SyntaxError('Not JSON');
          return response.body;
        },
      };
    },
  });
  const source = code.replace("const apiKey = '';", `const apiKey = ${JSON.stringify(apiKey)};`);
  const execution = vm.runInContext(`(async () => {\n${source}\n})()`, context);
  return { calls, execution };
}

test('public POS example consumes zero weight, drawer and ticket in order', async () => {
  const { calls, execution } = await runExample([
    { status: 200, body: { peso: 0, is_simulated: false } },
    { status: 200, body: { ok: true, status: 'ok', is_simulated: false } },
    { status: 200, body: { status: 'ok' } },
  ], 'test-key');
  await execution;
  assert.deepEqual(calls.map(({ url }) => new URL(url).pathname), [
    '/api/v1/scale/weight', '/api/v1/drawer/open', '/api/v1/ticket',
  ]);
  assert.equal(calls[1].options.method, 'POST');
  assert.equal(calls[2].options.method, 'POST');
  assert.equal(calls[2].options.headers.get('Content-Type'), 'application/json');
  assert.match(JSON.parse(calls[2].options.body).content, /VENTA #101\n/);
  for (const call of calls) {
    assert.equal(call.options.headers.get('Authorization'), 'Bearer test-key');
  }
});

for (const response of [
  { status: 401, body: { status: 'error', message: 'Unauthorized' } },
  { status: 503, body: { status: 'error', message: 'Scale unavailable' } },
  { status: 200, body: { ok: false, message: 'Rejected' } },
  { status: 200, body: { peso: 1, is_simulated: true } },
  { status: 200, body: {} },
  { status: 200, body: null },
  { status: 200, body: { peso: -1, is_simulated: false } },
  { status: 200, body: { peso: '1.25', is_simulated: false } },
  { status: 200, body: { peso: 1 } },
  { status: 200, body: { ok: true, mode: 'simulation' } },
  { status: 422, nonJson: true },
]) {
  test(`public POS example stops on ${JSON.stringify(response.body)}`, async () => {
    const { calls, execution } = await runExample([response]);
    await assert.rejects(execution);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].options.headers.has('Authorization'), false);
  });
}

test('a success-shaped drawer without its required confirmation stops the sale', async () => {
  const { calls, execution } = await runExample([
    { status: 200, body: { peso: 1, is_simulated: false } },
    { status: 200, body: { status: 'ok', is_simulated: false } },
  ]);
  await assert.rejects(execution, /gaveta/);
  assert.equal(calls.length, 2);
});

for (const status of [503, 504]) {
  test(`a ticket HTTP ${status} is reported without automatic retry`, async () => {
    const { calls, execution } = await runExample([
      { status: 200, body: { peso: 1, is_simulated: false } },
      { status: 200, body: { ok: true, is_simulated: false } },
      { status, body: { status: 'error', message: 'Dispatch unavailable' } },
    ]);
    await assert.rejects(execution, /Dispatch unavailable/);
    assert.equal(calls.length, 3);
  });
}

test('a failed drawer dispatch prevents the example from printing', async () => {
  const { calls, execution } = await runExample([
    { status: 200, body: { peso: 1, is_simulated: false } },
    { status: 500, body: { status: 'error', message: 'Spooler rejected' } },
  ]);
  await assert.rejects(execution, /Spooler rejected/);
  assert.equal(calls.length, 2);
});
