import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const MetaGasStation = buildModule('MetaGasStation', m => {
  const metaGasStation = m.contract('MetaGasStation', ['MetaGasStation'])
  const erc2771Recipient = m.contract('ERC2771Recipient', [])
  return { metaGasStation, erc2771Recipient }
})

export default MetaGasStation
