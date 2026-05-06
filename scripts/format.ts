import fs from 'fs'
import path from 'path'
import { createPublicClient, getContract, http, type PublicClient } from 'viem'
import {
  getDeploymentTargets,
  type DeploymentTarget
} from './deploymentTargets'

const PROTOCOL_DIR = path.resolve(__dirname, '..')
const BROADCAST_DIR = path.join(
  PROTOCOL_DIR,
  'broadcast',
  'DeployProtocol.s.sol'
)
const ARTIFACTS_DIR = path.join(PROTOCOL_DIR, 'abi')
const OUT_FILE = path.join(PROTOCOL_DIR, 'deployments.json')
const LOCAL_OUT_FILE = path.join(PROTOCOL_DIR, 'deployments.local.json')
const ANVIL_CHAIN_ID = '31337'
const RPC_PROPAGATION_TIMEOUT_MS = 120_000
const RPC_PROPAGATION_RETRY_DELAY_MS = 2_000

const readJson = <T>(filePath: string): T =>
  JSON.parse(fs.readFileSync(filePath, 'utf-8')) as T

type BroadcastTransaction = {
  transactionType: string
  contractName?: string
  contractAddress?: string
}

type BroadcastFile = {
  transactions: BroadcastTransaction[]
}

type DeploymentsJson = Record<string, Record<string, string>>

export type FormatFoundryDeploymentsOptions = {
  deploymentTargets?: DeploymentTarget[]
  rpcUrlsByChainId?: Record<string, string>
}

const getAbi = (contractName: string) => {
  const artifactPath = path.join(
    ARTIFACTS_DIR,
    `${contractName}.sol`,
    `${contractName}.json`
  )
  const artifact = readJson<{ abi: any[] }>(artifactPath)
  return artifact.abi
}

const getLatestRunFile = (chainId: string): string | null => {
  const chainDir = path.join(BROADCAST_DIR, chainId)
  if (!fs.existsSync(chainDir)) {
    return null
  }

  const latest = path.join(chainDir, 'run-latest.json')
  if (fs.existsSync(latest)) {
    return latest
  }

  const runs = fs
    .readdirSync(chainDir)
    .filter((file: string) => file.endsWith('.json') && file.startsWith('run-'))
    .sort()

  return runs.length > 0 ? path.join(chainDir, runs[runs.length - 1]) : null
}

const getDeployedContracts = (
  broadcast: BroadcastFile
): Record<string, `0x${string}`> => {
  const deployments: Record<string, `0x${string}`> = {}

  for (const tx of broadcast.transactions) {
    if (
      tx.transactionType !== 'CREATE' ||
      !tx.contractName ||
      !tx.contractAddress
    ) {
      continue
    }
    deployments[tx.contractName] = tx.contractAddress as `0x${string}`
  }

  return deployments
}

const getRpcUrlsByChainId = (
  targets: DeploymentTarget[]
): Record<string, string> =>
  targets.reduce<Record<string, string>>((acc, target) => {
    acc[target.chainId] = target.rpcUrl
    return acc
  }, {})

const resolveRpcUrlForChain = (
  chainId: string,
  rpcUrlsByChainId: Record<string, string>
): string => {
  const rpcUrl = rpcUrlsByChainId[chainId]

  if (rpcUrl == null || rpcUrl === '') {
    throw new Error(
      `Missing RPC URL for chain ${chainId}. Add it to the deployment networks argument.`
    )
  }

  return rpcUrl
}

const readExistingDeployments = (): DeploymentsJson =>
  fs.existsSync(OUT_FILE) ? readJson<DeploymentsJson>(OUT_FILE) : {}

const readExistingLocalDeployments = (): DeploymentsJson =>
  fs.existsSync(LOCAL_OUT_FILE)
    ? readJson<DeploymentsJson>(LOCAL_OUT_FILE)
    : {}

const omitChainId = (
  deployments: DeploymentsJson,
  chainIdToOmit: string
): DeploymentsJson =>
  Object.fromEntries(
    Object.entries(deployments).filter(([chainId]) => chainId !== chainIdToOmit)
  )

const sortDeploymentsByChainId = (
  deployments: DeploymentsJson
): DeploymentsJson =>
  Object.fromEntries(
    Object.entries(deployments).sort(
      ([chainIdA], [chainIdB]) => Number(chainIdA) - Number(chainIdB)
    )
  )

const sleep = async (delayMs: number): Promise<void> =>
  await new Promise(resolve => setTimeout(resolve, delayMs))

const waitForDeployedBytecode = async (
  client: PublicClient,
  address: `0x${string}`,
  label: string
): Promise<void> => {
  const startedAt = Date.now()
  let lastError: unknown

  while (Date.now() - startedAt <= RPC_PROPAGATION_TIMEOUT_MS) {
    try {
      const bytecode = await client.getBytecode({ address })
      if (bytecode != null && bytecode !== '0x') {
        return
      }
    } catch (error) {
      lastError = error
    }

    await sleep(RPC_PROPAGATION_RETRY_DELAY_MS)
  }

  throw new Error(
    `Timed out waiting for deployed bytecode at ${label} (${address}).`,
    {
      cause: lastError instanceof Error ? lastError : undefined
    }
  )
}

const readWithRpcPropagationRetry = async <T>(
  label: string,
  read: () => Promise<T>
): Promise<T> => {
  const startedAt = Date.now()
  let lastError: unknown

  while (Date.now() - startedAt <= RPC_PROPAGATION_TIMEOUT_MS) {
    try {
      return await read()
    } catch (error) {
      lastError = error
      await sleep(RPC_PROPAGATION_RETRY_DELAY_MS)
    }
  }

  throw new Error(`Timed out reading ${label} from the deployment RPC.`, {
    cause: lastError instanceof Error ? lastError : undefined
  })
}

export const formatFoundryDeployments = async (
  options: FormatFoundryDeploymentsOptions = {}
) => {
  if (!fs.existsSync(BROADCAST_DIR)) {
    throw new Error(`No foundry broadcasts found at ${BROADCAST_DIR}`)
  }

  const deploymentTargets =
    options.deploymentTargets ?? getDeploymentTargets(process.argv.slice(2))
  const expectedChainIds = new Set(
    deploymentTargets.map(target => target.chainId)
  )
  const chainIds = fs
    .readdirSync(BROADCAST_DIR, { withFileTypes: true })
    .filter((entry: fs.Dirent) => entry.isDirectory())
    .map((entry: fs.Dirent) => entry.name)
    .filter(chainId => expectedChainIds.has(chainId))
    .sort((a, b) => Number(a) - Number(b))

  const rpcUrlsByChainId = {
    ...getRpcUrlsByChainId(deploymentTargets),
    ...(options.rpcUrlsByChainId ?? {})
  }
  const currentDeployments: DeploymentsJson = {}

  for (const chainId of chainIds) {
    const latestRunFile = getLatestRunFile(chainId)
    if (!latestRunFile) {
      continue
    }

    const broadcast = readJson<BroadcastFile>(latestRunFile)
    const deployedContracts = getDeployedContracts(broadcast)

    if (!deployedContracts.OrganigramClient) {
      continue
    }

    const rpcUrl = resolveRpcUrlForChain(chainId, rpcUrlsByChainId)
    const client = createPublicClient({ transport: http(rpcUrl) })
    await waitForDeployedBytecode(
      client,
      deployedContracts.OrganigramClient,
      `OrganigramClient on chain ${chainId}`
    )
    const organigramClient = getContract({
      address: deployedContracts.OrganigramClient,
      abi: getAbi('OrganigramClient'),
      client
    })

    const cloneableOrgan = await readWithRpcPropagationRetry(
      `OrganigramClient.organ() on chain ${chainId}`,
      async () => (await organigramClient.read.organ()) as `0x${string}`
    )
    const cloneableAsset = await readWithRpcPropagationRetry(
      `OrganigramClient.asset() on chain ${chainId}`,
      async () => (await organigramClient.read.asset()) as `0x${string}`
    )

    currentDeployments[chainId] = {
      ...deployedContracts,
      CloneableOrgan: cloneableOrgan,
      CloneableAsset: cloneableAsset
    }
  }

  const missingChainIds = [...expectedChainIds].filter(
    chainId => currentDeployments[chainId] == null
  )
  if (missingChainIds.length > 0) {
    throw new Error(
      `Missing Foundry deployment broadcasts for chain(s): ${missingChainIds.join(', ')}.`
    )
  }

  const anvilDeployment = currentDeployments[ANVIL_CHAIN_ID]
  if (anvilDeployment != null) {
    const localDeploymentsJson = sortDeploymentsByChainId({
      ...readExistingLocalDeployments(),
      [ANVIL_CHAIN_ID]: anvilDeployment
    })
    fs.writeFileSync(
      LOCAL_OUT_FILE,
      JSON.stringify(localDeploymentsJson, null, 2),
      'utf-8'
    )
    console.info(`Saved local deployment file: ${LOCAL_OUT_FILE}`)
  }

  const publicDeployments = omitChainId(currentDeployments, ANVIL_CHAIN_ID)
  const deploymentsJson = sortDeploymentsByChainId({
    ...omitChainId(readExistingDeployments(), ANVIL_CHAIN_ID),
    ...publicDeployments
  })

  fs.writeFileSync(OUT_FILE, JSON.stringify(deploymentsJson, null, 2), 'utf-8')
  console.info(`Saved deployment file: ${OUT_FILE}`)
}

if (require.main === module) {
  formatFoundryDeployments().catch(error => {
    console.error(error)
    process.exitCode = 1
  })
}
