import { formatFoundryDeployments } from './format'
import {
  getDeploymentTargets,
  type DeploymentTarget
} from './deploymentTargets'

import { spawnSync } from 'child_process'
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

  if (resume) {
    args.push('--resume')
  }

  return args
}

const readChainId = async (target: DeploymentTarget): Promise<string> => {
  try {
    const client = createPublicClient({ transport: http(target.rpcUrl) })
    return (await client.getChainId()).toString()
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
    const actualChainId = await readChainId(target)
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

const deployTarget = (
  target: DeploymentTarget,
  signerArgs: string[],
  resume: boolean
): void => {
  const args = getForgeArgs(target, signerArgs, resume)
  const label = `${target.name} (chain ${target.chainId})`
  const action = resume
    ? 'Resuming Organigram Protocol deployment'
    : 'Deploying Organigram Protocol'

  console.info(`${action} to ${label}.`)

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
}

export const deployProtocol = async (
  options: DeployProtocolOptions = parseDeployProtocolOptions()
): Promise<DeployProtocolResult> => {
  const signerArgs = resolveSignerArgs()
  const deploymentTargets = await getDeploymentPlan(options.networks)
  const rpcUrlsByChainId: Record<string, string> = {}

  for (const target of deploymentTargets) {
    deployTarget(target, signerArgs, options.resume)
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
