import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const MetaGasStation = buildModule('MetaGasStation', m => {
  const forwarderName = m.getParameter('forwarderName', 'MetaGasStation')
  const metaGasStation = m.contract('MetaGasStation', [forwarderName])
  const erc2771Recipient = m.contract('ERC2771Recipient', [])
  return { metaGasStation, erc2771Recipient }
})

export default MetaGasStation
