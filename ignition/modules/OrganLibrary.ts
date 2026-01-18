import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const OrganLibraryModule = buildModule('OrganLibraryModule', m => {
  const organLibrary = m.contract('OrganLibrary', [])

  return { organLibrary }
})

export default OrganLibraryModule
