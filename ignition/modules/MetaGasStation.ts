import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const MetaGasStationModule = buildModule('MetaGasStationModule', m => {
  const metaGasStation = m.contract('MetaGasStation', [
    process.env.NEXT_PUBLIC_SEPOLIA_GAS_STATION_WHITELIST as string
  ])

  return { metaGasStation }
})

export default MetaGasStationModule
