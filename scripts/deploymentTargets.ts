import * as chains from 'viem/chains'

type ChainLike = {
  id?: number
  name?: string
  network?: string
}

export type DeploymentTarget = {
  name: string
  chainId: string
  rpcUrl: string
}

const THIRDWEB_CLIENT_ID_ENV = 'NEXT_PUBLIC_THIRDWEB_CLIENT_ID'
const ANVIL_TARGET_NAME = 'anvil'
const ANVIL_CHAIN_ID = '31337'
const ANVIL_RPC_URL = 'http://127.0.0.1:8545'

const normalizeLookupKey = (value: string): string =>
  value
    .trim()
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase()

const getChainIdForTargetName = (targetName: string): string | undefined => {
  if (/^\d+$/.test(targetName)) return targetName

  const normalizedTargetName = normalizeLookupKey(targetName)
  const configuredChain = Object.entries(chains).find(([key, chain]) => {
    const candidate = chain as ChainLike
    return (
      normalizeLookupKey(key) === normalizedTargetName ||
      normalizeLookupKey(candidate.name ?? '') === normalizedTargetName ||
      normalizeLookupKey(candidate.network ?? '') === normalizedTargetName
    )
  })?.[1] as ChainLike | undefined

  return configuredChain?.id?.toString()
}

const getRequiredThirdwebClientId = (env: NodeJS.ProcessEnv): string => {
  const thirdwebClientId = env[THIRDWEB_CLIENT_ID_ENV]?.trim()
  if (thirdwebClientId != null && thirdwebClientId !== '') {
    return thirdwebClientId
  }

  throw new Error(
    `${THIRDWEB_CLIENT_ID_ENV} is required to build deployment RPC URLs.`
  )
}

const getThirdwebRpcUrl = (
  chainId: string,
  env: NodeJS.ProcessEnv = process.env
): string =>
  `https://${chainId}.rpc.thirdweb.com/${getRequiredThirdwebClientId(env)}`

const isAnvilTarget = (targetName: string): boolean =>
  normalizeLookupKey(targetName) === ANVIL_TARGET_NAME

export const getDeploymentTargets = (
  networks: string | string[],
  env: NodeJS.ProcessEnv = process.env
): DeploymentTarget[] => {
  const configuredNetworks = (Array.isArray(networks) ? networks : [networks])
    .filter(value => value !== '--')
    .flatMap(value => value.split(','))
    .map(value => value.trim())
    .filter(Boolean)

  if (configuredNetworks.length === 0) {
    throw new Error(
      'Pass at least one deployment network, e.g. pnpm deploy:protocol mainnet,base,11155111 or pnpm deploy:protocol anvil.'
    )
  }

  return configuredNetworks.map(name => {
    if (name.includes('=')) {
      throw new Error(
        'Deployment networks must contain only network names or numeric chain ids.'
      )
    }

    if (isAnvilTarget(name)) {
      return {
        name: ANVIL_TARGET_NAME,
        chainId: ANVIL_CHAIN_ID,
        rpcUrl: ANVIL_RPC_URL
      }
    }

    const chainId = getChainIdForTargetName(name)
    if (chainId == null) {
      throw new Error(
        `Could not resolve deployment network "${name}" to a known chain id. Use a numeric chain id instead.`
      )
    }

    return {
      name,
      chainId,
      rpcUrl: getThirdwebRpcUrl(chainId, env)
    }
  })
}
