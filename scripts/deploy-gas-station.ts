import MetaGasStationModule from '../ignition/modules/MetaGasStation'
import { deployAndLoadContract } from '../src/dao'

async function main() {
  const { metaGasStation } = await deployAndLoadContract(MetaGasStationModule)
  await metaGasStation.write.setRelayHub([
    process.env.NEXT_PUBLIC_SEPOLIA_RELAY_HUB_ADDRESS
  ])
  console.info(
    'Relay Hub set to:',
    process.env.NEXT_PUBLIC_SEPOLIA_RELAY_HUB_ADDRESS
  )
  await metaGasStation.write.setTrustedForwarder([
    process.env.NEXT_PUBLIC_SEPOLIA_GAS_STATION_FORWARDER
  ])
  console.info(
    'Trusted Forwarder set to:',
    process.env.NEXT_PUBLIC_SEPOLIA_GAS_STATION_FORWARDER
  )
  console.info('Gas Station deployed successfully! ✅🚀')
}

main().catch(console.error)
