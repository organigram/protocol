import { formatFoundryDeployments } from './format'

import { spawnSync } from 'child_process'
import path from 'path'

const PROTOCOL_DIR = path.resolve(__dirname, '..')

const resolveSignerArgs = (): string[] => {
  if (process.env.PRIVATE_KEY) {
    return ['--private-key', process.env.PRIVATE_KEY]
  }

  if (process.env.MNEMONIC) {
    return ['--mnemonics', process.env.MNEMONIC]
  }

  return []
}

export const deployProtocol = async () => {
  const signerArgs = resolveSignerArgs()
  const hasRpc = Boolean(process.env.RPC_URL)

  const args = [
    'script',
    'script/DeployProtocol.s.sol:DeployProtocolScript',
    '--slow'
  ]

  if (hasRpc) {
    args.push('--rpc-url', process.env.RPC_URL as string)
  }

  if (signerArgs.length > 0 && hasRpc) {
    args.push('--broadcast', ...signerArgs)
  } else {
    console.warn(
      'RPC_URL or deployer credentials were not provided. Running a local simulation only.'
    )
  }

  const result = spawnSync('forge', args, {
    cwd: PROTOCOL_DIR,
    stdio: 'inherit',
    env: process.env
  })

  if (result.error) {
    throw result.error
  }

  if (result.status !== 0) {
    throw new Error(`forge script failed with exit code ${result.status}`)
  }
  return true
}

;(async () => {
  const didBroadcast = await deployProtocol()

  if (!didBroadcast) {
    console.info(
      'Skipping deployments.json formatting because no broadcast was performed.'
    )
    return
  }

  await formatFoundryDeployments()
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
