import http from 'http'
import type { AddressInfo } from 'net'

export type RpcProxy = {
  url: string
  close: () => void
}

// forge script cannot send custom RPC headers: it talks to this loopback-only
// relay, which forwards each JSON-RPC request upstream with the headers.
export const startRpcProxy = async (
  upstreamUrl: string,
  headers: Record<string, string>
): Promise<RpcProxy> => {
  const server = http.createServer((request, response) => {
    const chunks: Buffer[] = []
    request.on('data', (chunk: Buffer) => chunks.push(chunk))
    request.on('end', () => {
      fetch(upstreamUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...headers },
        body: Buffer.concat(chunks)
      })
        .then(async upstreamResponse => {
          response.writeHead(upstreamResponse.status, {
            'content-type':
              upstreamResponse.headers.get('content-type') ?? 'application/json'
          })
          response.end(Buffer.from(await upstreamResponse.arrayBuffer()))
        })
        .catch(() => {
          response.writeHead(502)
          response.end()
        })
    })
  })

  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address() as AddressInfo
  return {
    url: `http://127.0.0.1:${port}`,
    close: () => server.close()
  }
}
