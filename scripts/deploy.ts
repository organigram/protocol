import { formatFoundryDeployments } from './format'
import {
  getDeploymentTargets,
  getRpcHeaders,
  type DeploymentTarget
} from './deploymentTargets'
import { startRpcProxy } from './rpcProxy'

import { spawn } from 'child_process'
import path from 'path'
import { createPublicClient, http } from 'viem'

const PROTOCOL_DIR = path.resolve(__dirname, '..')

type DeployProtocolResult = {
  deploymentTargets: DeploymentTarget[]
  rpcUrlsByChainId: Record<string, string>
}

type DeployProtocolOptions = {
  networks: string[]
  resume: boolean
}

const parseDeployProtocolOptions = (
  args: string[] = process.argv.slice(2)
): DeployProtocolOptions => ({
  networks: args.filter(arg => arg !== '--resume'),
  resume: args.includes('--resume')
})

const getEnvValue = (key: string): string | undefined => {
  const value = process.env[key]?.trim()
  return value == null || value === '' ? undefined : value
}

const resolveSignerArgs = (): string[] => {
  const mnemonic = getEnvValue('MNEMONIC')
  if (mnemonic != null) {
    return ['--mnemonics', mnemonic]
  }

  throw new Error('MNEMONIC is required to deploy the protocol.')
}

const getForgeArgs = (
  target: DeploymentTarget,
  signerArgs: string[],
  resume: boolean
): string[] => {
  const args = [
    'script',
    'script/DeployProtocol.s.sol:DeployProtocolScript',
    '--slow',
    '--rpc-url',
    target.rpcUrl,
    '--broadcast',
    ...signerArgs
  ]

  if (target.hardfork != null) {
    args.push('--hardfork', target.hardfork)
  }

  if (resume) {
    args.push('--resume')
  }

  return args
}

// forge simulates with foundry.toml's evm_version unless told otherwise, but
// Amsterdam (EIP-8037) reprices state creation several times higher: its
// estimates would run deployments out of gas. Its blocks carry an access list.
const readChainInfo = async (
  target: DeploymentTarget
): Promise<{ chainId: string; hardfork?: string }> => {
  try {
    const client = createPublicClient({
      transport: http(target.rpcUrl, {
        fetchOptions: { headers: getRpcHeaders(target.rpcUrl) }
      })
    })
    const latestBlock = await client.request<{
      Method: 'eth_getBlockByNumber'
      Parameters: ['latest', false]
      ReturnType: { blockAccessListHash?: string }
    }>({ method: 'eth_getBlockByNumber', params: ['latest', false] })
    return {
      chainId: (await client.getChainId()).toString(),
      hardfork:
        latestBlock.blockAccessListHash != null ? 'amsterdam' : undefined
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(
      `Could not read chain id for deployment target "${target.name}": ${message}`
    )
  }
}

const getDeploymentPlan = async (
  networks: string[]
): Promise<DeploymentTarget[]> => {
  const targets = getDeploymentTargets(networks)
  const seenChainIds = new Map<string, string>()

  for (const target of targets) {
    const { chainId: actualChainId, hardfork } = await readChainInfo(target)
    target.hardfork = hardfork
    if (target.chainId !== actualChainId) {
      throw new Error(
        `Deployment target "${target.name}" was configured as chain ${target.chainId}, but its RPC URL points to chain ${actualChainId}.`
      )
    }

    const previousTarget = seenChainIds.get(target.chainId)
    if (previousTarget != null) {
      throw new Error(
        `Deployment targets "${previousTarget}" and "${target.name}" both resolve to chain ${target.chainId}.`
      )
    }
    seenChainIds.set(target.chainId, target.name)
  }

  return targets
}

const deployTarget = async (
  target: DeploymentTarget,
  signerArgs: string[],
  resume: boolean
): Promise<void> => {
  const rpcHeaders = getRpcHeaders(target.rpcUrl)
  const rpcProxy =
    Object.keys(rpcHeaders).length > 0
      ? await startRpcProxy(target.rpcUrl, rpcHeaders)
      : undefined
  const args = getForgeArgs(
    { ...target, rpcUrl: rpcProxy?.url ?? target.rpcUrl },
    signerArgs,
    resume
  )
  const label = `${target.name} (chain ${target.chainId})`
  const action = resume
    ? 'Resuming Organigram Protocol deployment'
    : 'Deploying Organigram Protocol'

  console.info(`${action} to ${label}.`)

  try {
    // Asynchronous, so that the RPC proxy keeps serving forge meanwhile.
    const status = await new Promise<number | null>((resolve, reject) => {
      const child = spawn('forge', args, {
        cwd: PROTOCOL_DIR,
        stdio: 'inherit',
        env: process.env
      })
      child.on('error', reject)
      child.on('close', resolve)
    })

    if (status !== 0) {
      throw new Error(`forge script failed with exit code ${status}`)
    }
  } finally {
    rpcProxy?.close()
  }
}

export const deployProtocol = async (
  options: DeployProtocolOptions = parseDeployProtocolOptions()
): Promise<DeployProtocolResult> => {
  const signerArgs = resolveSignerArgs()
  const deploymentTargets = await getDeploymentPlan(options.networks)
  const rpcUrlsByChainId: Record<string, string> = {}

  for (const target of deploymentTargets) {
    await deployTarget(target, signerArgs, options.resume)
    rpcUrlsByChainId[target.chainId] = target.rpcUrl
  }

  return { deploymentTargets, rpcUrlsByChainId }
}

;(async () => {
  const { deploymentTargets, rpcUrlsByChainId } = await deployProtocol()
  await formatFoundryDeployments({ deploymentTargets, rpcUrlsByChainId })
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
