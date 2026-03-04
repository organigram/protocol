import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const MetaGasStation = buildModule('MetaGasStation', m => {
  const metaGasStation = m.contract('MetaGasStation', ['MetaGasStation'])
  return { metaGasStation }
})

export default MetaGasStation
