#!/usr/bin/env node

import { spawn } from 'node:child_process'
import http from 'node:http'

const clientId = process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID
const chainId = '31337'
const rpcOrigin = process.env.THIRDWEB_RPC_ORIGIN ?? 'https://localhost:3000'
const forkProxyPort = Number(process.env.ANVIL_FORK_PROXY_PORT ?? '8546')

if (!clientId) {
  throw new Error('NEXT_PUBLIC_THIRDWEB_CLIENT_ID is not defined')
}

const upstreamUrl = `https://11155111.rpc.thirdweb.com/${clientId}`

const proxy = http.createServer(async (request, response) => {
  try {
    const body = await new Promise(resolve => {
      const chunks = []
      request.on('data', chunk => chunks.push(chunk))
      request.on('end', () => resolve(Buffer.concat(chunks)))
    })
    const upstreamResponse = await fetch(upstreamUrl, {
      method: request.method,
      headers: {
        'content-type': request.headers['content-type'] ?? 'application/json',
        Origin: rpcOrigin
      },
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : body
    })
    response.writeHead(upstreamResponse.status, {
      'content-type': upstreamResponse.headers.get('content-type') ?? 'application/json'
    })
    response.end(Buffer.from(await upstreamResponse.arrayBuffer()))
  } catch (error) {
    response.writeHead(502, { 'content-type': 'application/json' })
    response.end(JSON.stringify({ error: error instanceof Error ? error.message : 'Fork proxy failed.' }))
  }
})

await new Promise((resolve, reject) => {
  proxy.once('error', reject)
  proxy.listen(forkProxyPort, '127.0.0.1', resolve)
})

try {
  const anvil = spawn(
    'anvil',
    [
      '--fork-url',
      `http://127.0.0.1:${forkProxyPort}`,
      '--chain-id',
      chainId,
      '--host',
      '127.0.0.1',
      '--port',
      '8545'
    ],
    { stdio: 'inherit' }
  )
  const exitCode = await new Promise(resolve => {
    anvil.once('exit', code => resolve(code ?? 1))
    anvil.once('error', () => resolve(1))
  })
  process.exitCode = exitCode
} finally {
  await new Promise(resolve => proxy.close(resolve))
}
