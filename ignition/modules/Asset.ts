import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const AssetModule = buildModule('AssetModule', m => {
  const asset = m.contract('Asset', [])

  return { asset }
})

export default AssetModule
