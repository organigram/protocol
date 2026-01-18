import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import OrganLibrary from './OrganLibrary'

const OrganigramModule = buildModule('OrganigramModule', m => {
  const { organLibrary } = m.useModule(OrganLibrary)
  const organigram = m.contract(
    'Organigram',
    ['', '0x0000000000000000000000000000000000000000'],
    {
      libraries: {
        OrganLibrary: organLibrary
      }
    }
  )

  return { organigram }
})

export default OrganigramModule
