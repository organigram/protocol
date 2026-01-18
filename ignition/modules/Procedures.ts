import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import ProcedureLibrary from './ProcedureLibrary'

const ProcedureModule = buildModule('ProcedureModule', m => {
  const { procedureLibrary } = m.useModule(ProcedureLibrary)
  const nominationProcedure = m.contract('NominationProcedure', [], {
    libraries: {
      ProcedureLibrary: procedureLibrary
    }
  })
  const voteProcedure = m.contract('VoteProcedure', [], {
    libraries: {
      ProcedureLibrary: procedureLibrary
    }
  })
  const erc20VoteProcedure = m.contract('ERC20VoteProcedure', [], {
    libraries: {
      ProcedureLibrary: procedureLibrary
    }
  })

  return { nominationProcedure, voteProcedure, erc20VoteProcedure }
})

export default ProcedureModule
