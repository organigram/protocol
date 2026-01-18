import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const CoreLibraryModule = buildModule('CoreLibraryModule', m => {
  const coreLibrary = m.contract('CoreLibrary', [])

  return { coreLibrary }
})

export default CoreLibraryModule
