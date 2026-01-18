import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

const ProcedureLibraryModule = buildModule('ProcedureLibraryModule', m => {
  const procedureLibrary = m.contract('ProcedureLibrary', [])

  return { procedureLibrary }
})

export default ProcedureLibraryModule
