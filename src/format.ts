import fs from 'fs'
import path from 'path'

// Get the list of supported networks by reading the directories in the ignition deployments folder
const getSupportedNetworks = () => {
  const deploymentsPath = path.resolve(__dirname, '../ignition/deployments')
  return fs
    .readdirSync(deploymentsPath, { withFileTypes: true })
    .filter((dir: { isDirectory: () => any }) => dir.isDirectory())
    .map((dir: { name: any }) => dir.name.replace('chain-', ''))
}

export const formatIgnitionDeployments = () => {
  // Read the deployments from the ignition deployments folder
  const supportedNetworks = getSupportedNetworks()
  const deploymentsJson: any = {}
  supportedNetworks.forEach(networkId => {
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
    )
    deploymentsJson[networkId] = formatted
  })
  // Write the formatted deployments to a new JSON file
  const outputFilePath = path.resolve(
    __dirname,
    '../deployments.json'
  )
  fs.writeFileSync(
    outputFilePath,
    JSON.stringify(deploymentsJson, null, 2),
    'utf-8'
  )
  console.info(`Saved deployment file: ${outputFilePath}`)
}
