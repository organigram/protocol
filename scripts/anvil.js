#!/usr/bin/env node

import { spawnSync } from 'node:child_process'

const clientId = process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID

if (!clientId) {
  throw new Error('NEXT_PUBLIC_THIRDWEB_CLIENT_ID is not defined')
}

spawnSync(
  'anvil',
  ['--fork-url', `https://11155111.rpc.thirdweb.com/${clientId}`],
  ['--chain-id', '11155111'],
  { stdio: 'inherit' }
)
