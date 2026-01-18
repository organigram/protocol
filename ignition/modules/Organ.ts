import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import OrganLibrary from './OrganLibrary'

const OrganModule = buildModule('OrganModule', m => {
  const { organLibrary } = m.useModule(OrganLibrary)
  const organ = m.contract('Organ', [], {
    libraries: {
      OrganLibrary: organLibrary
    }
  })

  return { organ }
})

export default OrganModule
