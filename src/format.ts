import fs from 'fs'
import path from 'path'
import { viem } from 'hardhat'

// Get the list of supported networks by reading the directories in the ignition deployments folder
const getSupportedNetworks = () => {
  const deploymentsPath = path.resolve(__dirname, '../ignition/deployments')
  return fs
    .readdirSync(deploymentsPath, { withFileTypes: true })
    .filter((dir: { isDirectory: () => any }) => dir.isDirectory())
    .map((dir: { name: any }) => dir.name.replace('chain-', ''))
}

export const formatIgnitionDeployments = async () => {
  // Read the deployments from the ignition deployments folder
  const supportedNetworks = getSupportedNetworks()
  const deploymentsJson: any = {}
  for (const networkId of supportedNetworks) {
    // Read the deployment file for the network
    const deploymentFilePath = path.resolve(
      __dirname,
      `../ignition/deployments/chain-${networkId}/deployed_addresses.json`
    )
    const deployments = JSON.parse(fs.readFileSync(deploymentFilePath, 'utf-8'))
    // Transform the addresses JSON to remove the prefix before the '#'
    const formatted = Object.fromEntries(
      Object.entries(deployments).map(([key, value]) => [
        key.split('#')[1],
        value
      ])
    ) as Record<string, string>
    const organigramClient = await viem.getContractAt(
      'OrganigramClient',
      formatted.OrganigramClient as `0x${string}`
    )
    const CloneableOrgan = await organigramClient.read.organ()
    deploymentsJson[networkId] = { ...formatted, CloneableOrgan }
  }
  // Write the formatted deployments to a new JSON file
  const outputFilePath = path.resolve(__dirname, '../deployments.json')
  fs.writeFileSync(
    outputFilePath,
    JSON.stringify(deploymentsJson, null, 2),
    'utf-8'
  )
  console.info(`Saved deployment file: ${outputFilePath}`)
}
