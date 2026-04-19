import fs from 'fs'
import path from 'path'
import { createPublicClient, getContract, http } from 'viem'

const PROTOCOL_DIR = path.resolve(__dirname, '..')
const BROADCAST_DIR = path.join(
  PROTOCOL_DIR,
  'broadcast',
  'DeployProtocol.s.sol'
)
const OUT_FILE = path.join(PROTOCOL_DIR, 'deployments.json')

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

const getAbi = (contractName: string) => {
  const artifactPath = path.join(
    PROTOCOL_DIR,
    'out',
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

export const formatFoundryDeployments = async () => {
  if (!fs.existsSync(BROADCAST_DIR)) {
    throw new Error(`No foundry broadcasts found at ${BROADCAST_DIR}`)
  }

  const chainIds = fs
    .readdirSync(BROADCAST_DIR, { withFileTypes: true })
    .filter((entry: fs.Dirent) => entry.isDirectory())
    .map((entry: fs.Dirent) => entry.name)

  const deploymentsJson: Record<string, Record<string, string>> = {}

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

    const rpcUrl = process.env.RPC_URL
    if (!rpcUrl) {
      throw new Error(
        'RPC_URL is required to enrich deployments with CloneableOrgan and CloneableAsset'
      )
    }

    const client = createPublicClient({ transport: http(rpcUrl) })
    const organigramClient = getContract({
      address: deployedContracts.OrganigramClient,
      abi: getAbi('OrganigramClient'),
      client
    })

    const cloneableOrgan =
      (await organigramClient.read.organ()) as `0x${string}`
    const cloneableAsset =
      (await organigramClient.read.asset()) as `0x${string}`

    deploymentsJson[chainId] = {
      ...deployedContracts,
      CloneableOrgan: cloneableOrgan,
      CloneableAsset: cloneableAsset
    }
  }

  fs.writeFileSync(OUT_FILE, JSON.stringify(deploymentsJson, null, 2), 'utf-8')
  console.info(`Saved deployment file: ${OUT_FILE}`)
}

formatFoundryDeployments().catch(error => {
  console.error(error)
  process.exitCode = 1
})
