import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const AssetModule = buildModule('AssetModule', m => {
  const asset = m.contract('Asset', ['ExampleCoin', 'EXC', 1000000])

  return { asset }
})

export default AssetModule
